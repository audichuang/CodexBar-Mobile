import CryptoKit
import Foundation

/// One calendar event CodexBar owns: every reset of one provider account that expires at the same moment.
struct ResetCreditCalendarEntry: Codable, Equatable, Sendable {
    let key: String
    let scopeKey: String
    let providerID: String
    var providerName: String
    var accountLabel: String?
    let expiresAt: Date
    var count: Int
    /// Whether the newest observation of this account still lists the reset.
    var isAvailable: Bool
    var eventIdentifier: String?
    /// Fingerprint of the event content last written, so unchanged events are not rewritten.
    var eventSignature: String?
}

struct ResetCreditCalendarState: Codable, Equatable, Sendable {
    var calendarIdentifier: String?
    var entries: [String: ResetCreditCalendarEntry] = [:]
    /// Newest observation applied per provider account. An observation that is not newer is ignored as a whole,
    /// so a stale writer can neither resurrect a reset that was used early nor remove one a newer read lists.
    var scopeObservedAt: [String: Date] = [:]

    init(calendarIdentifier: String? = nil) {
        self.calendarIdentifier = calendarIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.calendarIdentifier = try container.decodeIfPresent(String.self, forKey: .calendarIdentifier)
        self.entries = try container.decodeIfPresent([String: ResetCreditCalendarEntry].self, forKey: .entries) ?? [:]
        self.scopeObservedAt = try container.decodeIfPresent([String: Date].self, forKey: .scopeObservedAt) ?? [:]
    }
}

/// The content of one reset-credit event.
struct ResetCreditCalendarEventDraft: Equatable, Sendable {
    let title: String
    let startDate: Date
    let endDate: Date
    let notes: String
    /// Alarm offsets relative to `startDate`, in seconds (negative = before).
    let alarmOffsets: [TimeInterval]
    /// Opaque, device-independent marker for this provider account and expiry. It finds the event again after
    /// EventKit changes its identifier, and lets another device on the same iCloud calendar adopt it.
    let url: URL?

    var signature: String {
        [
            self.url?.absoluteString ?? "",
            self.title,
            String(self.startDate.timeIntervalSince1970),
            String(self.endDate.timeIntervalSince1970),
            self.notes,
            self.alarmOffsets.map { String($0) }.joined(separator: ","),
        ].joined(separator: "\u{1F}")
    }
}

/// Side effects on the user's calendar. `EventKitResetCreditCalendarStore` implements it; tests use a fake.
@MainActor
protocol ResetCreditCalendarEventStore: AnyObject {
    func calendarExists(identifier: String) -> Bool
    /// Returns the dedicated CodexBar calendar, reusing one that already exists (for example created by the
    /// user's other device on the same iCloud account), or creates it.
    func makeCalendar() throws -> String
    func eventExists(identifier: String) -> Bool
    /// Events in the calendar that carry `draft.url` around the draft's dates, in an order every device agrees on
    /// (oldest creation first), so concurrent de-duplication on two devices keeps the same event.
    func eventIdentifiers(matching draft: ResetCreditCalendarEventDraft, calendarIdentifier: String) -> [String]
    /// Creates (`existingIdentifier == nil`) or updates an event and returns its identifier.
    func saveEvent(
        _ draft: ResetCreditCalendarEventDraft,
        existingIdentifier: String?,
        calendarIdentifier: String) throws -> String
    func removeEvent(identifier: String) throws
}

struct ResetCreditCalendarSyncSummary: Equatable, Sendable {
    var created = 0
    var updated = 0
    var removed = 0
    var failures = 0
    /// Future events CodexBar currently keeps in the calendar.
    var scheduled = 0
}

/// Folds Mac reset-credit observations into calendar state and applies the result (Research 077).
///
/// Rules:
/// - Each provider account only accepts observations newer than the last one applied.
/// - A provider account without an observation (older Mac, unreadable source) leaves its events untouched; an
///   incomplete observation can add or update events but never removes one.
/// - A future reset that a newer complete observation no longer lists was used early: its event is removed.
/// - Events are found by their URL marker, so a changed EventKit identifier, an event another device created,
///   or a duplicate from two devices writing at once is adopted or cleaned up instead of multiplied.
/// - A missing event or calendar is recreated while the setting is on; turning it off removes future events.
/// - Past events stay in the calendar as history; their state is pruned 30 days after expiry.
enum ResetCreditCalendarPlanner {
    static let eventLeadTime: TimeInterval = 30 * 60
    static let alarmLeadTimes: [TimeInterval] = [24 * 60 * 60, 60 * 60]
    static let pruneAfterExpiry: TimeInterval = 30 * 24 * 60 * 60
    /// How long an account's newest applied observation time is kept after its last entry is gone.
    static let scopeWatermarkRetention: TimeInterval = 60 * 24 * 60 * 60
    /// An observation stamped further than this ahead of the iPhone clock comes from a Mac whose clock runs fast.
    /// Its time cannot be ordered against other Macs, so it is ignored until real time catches up.
    static let clockSkewAllowance: TimeInterval = 5 * 60

    static func key(scopeKey: String, expiresAt: Date) -> String {
        "\(scopeKey)#\(self.wholeSeconds(expiresAt))"
    }

    /// Whole seconds since 1970, clamped so an implausible date cannot trap.
    static func wholeSeconds(_ date: Date) -> Int64 {
        let seconds = date.timeIntervalSince1970.rounded()
        guard seconds.isFinite else { return 0 }
        return Int64(min(max(seconds, -1e15), 1e15))
    }

    /// Merges observations into `state` without touching the calendar.
    static func applying(
        _ observations: [ResetCreditObservation],
        to state: ResetCreditCalendarState,
        now: Date) -> ResetCreditCalendarState
    {
        var state = state
        var appliedScopes: Set<String> = []
        for observation in observations {
            let scope = observation.scopeKey
            appliedScopes.insert(scope)
            guard observation.observedAt <= now.addingTimeInterval(Self.clockSkewAllowance) else { continue }
            if let applied = state.scopeObservedAt[scope], observation.observedAt <= applied {
                continue
            }
            state.scopeObservedAt[scope] = observation.observedAt

            var observedKeys: Set<String> = []
            for group in observation.groups(availableAt: max(now, observation.observedAt)) {
                guard let expiresAt = group.expiresAt else { continue }
                let key = Self.key(scopeKey: scope, expiresAt: expiresAt)
                observedKeys.insert(key)
                var entry = state.entries[key] ?? ResetCreditCalendarEntry(
                    key: key,
                    scopeKey: scope,
                    providerID: observation.providerID,
                    providerName: observation.providerName,
                    accountLabel: observation.accountLabel,
                    expiresAt: expiresAt,
                    count: group.count,
                    isAvailable: true,
                    eventIdentifier: nil,
                    eventSignature: nil)
                entry.isAvailable = true
                entry.count = group.count
                entry.providerName = observation.providerName
                entry.accountLabel = observation.accountLabel
                state.entries[key] = entry
            }

            guard observation.isComplete else { continue }
            for (key, entry) in state.entries
                where entry.scopeKey == scope
                && !observedKeys.contains(key)
                && entry.isAvailable
                && entry.expiresAt > now
            {
                state.entries[key]?.isAvailable = false
            }
        }
        // A watermark outlives its entries and temporarily missing observations, so an older Mac snapshot cannot
        // bring back a reset that a newer (possibly empty) read already ruled out. Resets expire well within the
        // retention window.
        let liveScopes = appliedScopes.union(state.entries.values.map(\.scopeKey))
        let retention = now.addingTimeInterval(-Self.scopeWatermarkRetention)
        state.scopeObservedAt = state.scopeObservedAt.filter { scope, observedAt in
            liveScopes.contains(scope) || observedAt > retention
        }
        return state
    }

    /// Applies observations and reconciles the calendar. Returns the new state and what changed.
    @MainActor
    static func reconcile(
        state: ResetCreditCalendarState,
        observations: [ResetCreditObservation],
        now: Date,
        store: ResetCreditCalendarEventStore,
        draft: (ResetCreditCalendarEntry) -> ResetCreditCalendarEventDraft) throws
        -> (state: ResetCreditCalendarState, summary: ResetCreditCalendarSyncSummary)
    {
        var state = Self.applying(observations, to: state, now: now)
        var summary = ResetCreditCalendarSyncSummary()

        if let identifier = state.calendarIdentifier, !store.calendarExists(identifier: identifier) {
            // The CodexBar calendar was deleted; start over with every future event.
            state.calendarIdentifier = nil
            for key in state.entries.keys {
                state.entries[key]?.eventIdentifier = nil
                state.entries[key]?.eventSignature = nil
            }
        }
        let needsCalendar = state.entries.values.contains { $0.expiresAt > now && $0.isAvailable }
        if state.calendarIdentifier == nil, needsCalendar {
            state.calendarIdentifier = try store.makeCalendar()
        }

        for key in state.entries.keys.sorted() {
            guard var entry = state.entries[key] else { continue }
            defer { state.entries[key] = entry }
            guard entry.expiresAt > now, let calendarIdentifier = state.calendarIdentifier else { continue }

            let content = draft(entry)
            let matches = Self.trackedEventIdentifiers(
                for: entry,
                content: content,
                calendarIdentifier: calendarIdentifier,
                store: store)
            if entry.isAvailable {
                // Every device keeps the first match in the store's shared order, never its own copy.
                let current = matches.first
                for duplicate in matches.dropFirst() {
                    do {
                        try store.removeEvent(identifier: duplicate)
                        summary.removed += 1
                    } catch {
                        summary.failures += 1
                    }
                }
                if let current, current == entry.eventIdentifier, entry.eventSignature == content.signature {
                    summary.scheduled += 1
                    continue
                }
                do {
                    entry.eventIdentifier = try store.saveEvent(
                        content,
                        existingIdentifier: current,
                        calendarIdentifier: calendarIdentifier)
                    entry.eventSignature = content.signature
                    if current == nil { summary.created += 1 } else { summary.updated += 1 }
                    summary.scheduled += 1
                } catch {
                    summary.failures += 1
                }
            } else {
                var failed = false
                for identifier in matches {
                    do {
                        try store.removeEvent(identifier: identifier)
                        summary.removed += 1
                    } catch {
                        failed = true
                    }
                }
                if failed {
                    summary.failures += 1
                } else {
                    entry.eventIdentifier = nil
                    entry.eventSignature = nil
                }
            }
        }

        state.entries = state.entries.filter { _, entry in
            entry.expiresAt > now.addingTimeInterval(-Self.pruneAfterExpiry)
        }
        return (state, summary)
    }

    /// Events carrying the entry's URL marker around its expiry, plus the saved identifier when the user moved the
    /// event elsewhere (the date-bounded marker search cannot see it then).
    @MainActor
    static func trackedEventIdentifiers(
        for entry: ResetCreditCalendarEntry,
        content: ResetCreditCalendarEventDraft,
        calendarIdentifier: String,
        store: ResetCreditCalendarEventStore) -> [String]
    {
        var identifiers = store.eventIdentifiers(matching: content, calendarIdentifier: calendarIdentifier)
        if let saved = entry.eventIdentifier, !identifiers.contains(saved), store.eventExists(identifier: saved) {
            identifiers.append(saved)
        }
        return identifiers
    }

    /// Turning reminders off without calendar access: every future event becomes a queued removal, and the applied
    /// observation times are forgotten so turning reminders back on re-adds what the Macs still list.
    static func queueingFutureRemovals(in state: ResetCreditCalendarState, now: Date) -> ResetCreditCalendarState {
        var state = state
        for key in state.entries.keys where state.entries[key].map({ $0.expiresAt > now }) == true {
            state.entries[key]?.isAvailable = false
        }
        state.scopeObservedAt = [:]
        return state
    }

    /// Removes every future event this device tracks, keeping past events and the calendar itself.
    @MainActor
    static func removeFutureEvents(
        state: ResetCreditCalendarState,
        now: Date,
        store: ResetCreditCalendarEventStore,
        draft: (ResetCreditCalendarEntry) -> ResetCreditCalendarEventDraft) -> (
        state: ResetCreditCalendarState,
        failures: Int)
    {
        var failures = 0
        var remaining = ResetCreditCalendarState(calendarIdentifier: state.calendarIdentifier)
        if let calendarIdentifier = state.calendarIdentifier, store.calendarExists(identifier: calendarIdentifier) {
            for entry in state.entries.values where entry.expiresAt > now {
                var failed = false
                for identifier in Self.trackedEventIdentifiers(
                    for: entry,
                    content: draft(entry),
                    calendarIdentifier: calendarIdentifier,
                    store: store)
                {
                    do {
                        try store.removeEvent(identifier: identifier)
                    } catch {
                        failed = true
                    }
                }
                if failed {
                    // Keep it so the next sync with reminders on removes it.
                    failures += 1
                    var kept = entry
                    kept.isAvailable = false
                    remaining.entries[entry.key] = kept
                }
            }
        }
        return (remaining, failures)
    }

    static func eventDraft(
        for entry: ResetCreditCalendarEntry,
        includeAccount: Bool,
        expiryText: String) -> ResetCreditCalendarEventDraft
    {
        let title = entry.count == 1
            ? String(format: String(localized: "%@ reset credit expires"), entry.providerName)
            : String(format: String(localized: "%d %@ reset credits expire"), entry.count, entry.providerName)
        var lines: [String] = []
        if includeAccount, let account = entry.accountLabel, !account.isEmpty {
            lines.append(String(format: String(localized: "Account: %@"), account))
        }
        lines.append(String(format: String(localized: "Expires: %@"), expiryText))
        lines
            .append(
                String(
                    localized: "Added by CodexBar from the reset credits your Mac reported. Turn this off in CodexBar Settings → Calendar Reminders."))
        return ResetCreditCalendarEventDraft(
            title: title,
            startDate: entry.expiresAt.addingTimeInterval(-Self.eventLeadTime),
            endDate: entry.expiresAt,
            notes: lines.joined(separator: "\n"),
            alarmOffsets: Self.alarmLeadTimes.map { Self.eventLeadTime - $0 },
            url: Self.eventURL(key: entry.key))
    }

    /// The key holds the account identity, so only a digest of it is written into the event.
    static func eventURL(key: String) -> URL? {
        let digest = SHA256.hash(data: Data(key.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
        return URL(string: "codexbar://reset-credit/\(digest)")
    }
}
