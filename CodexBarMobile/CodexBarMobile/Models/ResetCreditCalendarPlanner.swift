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
    /// The newest inventory observation that decided `isAvailable`. Older observations cannot change it.
    var lastObservedAt: Date
    var eventIdentifier: String?
    /// Fingerprint of the event content last written, so unchanged events are not rewritten.
    var eventSignature: String?
    /// The user deleted this event in Calendar; CodexBar does not recreate it.
    var dismissedByUser: Bool
}

struct ResetCreditCalendarState: Codable, Equatable, Sendable {
    var calendarIdentifier: String?
    var entries: [String: ResetCreditCalendarEntry] = [:]
}

/// The content of one reset-credit event.
struct ResetCreditCalendarEventDraft: Equatable, Sendable {
    let title: String
    let startDate: Date
    let endDate: Date
    let notes: String
    /// Alarm offsets relative to `startDate`, in seconds (negative = before).
    let alarmOffsets: [TimeInterval]

    var signature: String {
        [
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
    /// Creates the dedicated CodexBar calendar and returns its identifier.
    func makeCalendar() throws -> String
    func eventExists(identifier: String) -> Bool
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
/// - Only observations newer than the one that last decided an event can add or remove it, so a stale
///   writer cannot resurrect a reset that was used early or drop one a newer read still lists.
/// - A provider account without an observation (older Mac, unreadable source) leaves its events untouched.
/// - Past events stay in the calendar as history; their state is pruned 30 days after expiry.
/// - An event the user deleted is not recreated. A deleted CodexBar calendar is recreated with every future event.
enum ResetCreditCalendarPlanner {
    static let eventLeadTime: TimeInterval = 30 * 60
    static let alarmLeadTimes: [TimeInterval] = [24 * 60 * 60, 60 * 60]
    static let pruneAfterExpiry: TimeInterval = 30 * 24 * 60 * 60

    static func key(scopeKey: String, expiresAt: Date) -> String {
        "\(scopeKey)#\(Int64(expiresAt.timeIntervalSince1970.rounded()))"
    }

    /// Merges observations into `state` without touching the calendar.
    static func applying(
        _ observations: [ResetCreditObservation],
        to state: ResetCreditCalendarState,
        now: Date) -> ResetCreditCalendarState
    {
        var state = state
        for observation in observations {
            var observedKeys: Set<String> = []
            for group in observation.groups(availableAt: max(now, observation.observedAt)) {
                guard let expiresAt = group.expiresAt else { continue }
                let key = Self.key(scopeKey: observation.scopeKey, expiresAt: expiresAt)
                observedKeys.insert(key)
                if var entry = state.entries[key] {
                    guard observation.observedAt > entry.lastObservedAt else { continue }
                    entry.isAvailable = true
                    entry.count = group.count
                    entry.providerName = observation.providerName
                    entry.accountLabel = observation.accountLabel
                    entry.lastObservedAt = observation.observedAt
                    state.entries[key] = entry
                } else {
                    state.entries[key] = ResetCreditCalendarEntry(
                        key: key,
                        scopeKey: observation.scopeKey,
                        providerID: observation.providerID,
                        providerName: observation.providerName,
                        accountLabel: observation.accountLabel,
                        expiresAt: expiresAt,
                        count: group.count,
                        isAvailable: true,
                        lastObservedAt: observation.observedAt,
                        eventIdentifier: nil,
                        eventSignature: nil,
                        dismissedByUser: false)
                }
            }

            for (key, entry) in state.entries
                where entry.scopeKey == observation.scopeKey
                && !observedKeys.contains(key)
                && entry.isAvailable
                && entry.expiresAt > now
                && observation.observedAt > entry.lastObservedAt
            {
                var updated = entry
                updated.isAvailable = false
                updated.lastObservedAt = observation.observedAt
                state.entries[key] = updated
            }
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

        let needsCalendar = state.entries.values.contains { entry in
            entry.expiresAt > now && entry.isAvailable && !entry.dismissedByUser
        }
        if let identifier = state.calendarIdentifier, !store.calendarExists(identifier: identifier) {
            // The user deleted the whole CodexBar calendar; start over with every future event.
            state.calendarIdentifier = nil
            for key in state.entries.keys {
                state.entries[key]?.eventIdentifier = nil
                state.entries[key]?.eventSignature = nil
                state.entries[key]?.dismissedByUser = false
            }
        }
        if state.calendarIdentifier == nil, needsCalendar {
            state.calendarIdentifier = try store.makeCalendar()
        }

        for key in state.entries.keys.sorted() {
            guard var entry = state.entries[key] else { continue }
            defer { state.entries[key] = entry }
            guard entry.expiresAt > now else { continue }

            if entry.isAvailable, !entry.dismissedByUser {
                guard let calendarIdentifier = state.calendarIdentifier else { continue }
                if let identifier = entry.eventIdentifier, !store.eventExists(identifier: identifier) {
                    entry.eventIdentifier = nil
                    entry.eventSignature = nil
                    entry.dismissedByUser = true
                    continue
                }
                let content = draft(entry)
                if entry.eventIdentifier != nil, entry.eventSignature == content.signature {
                    summary.scheduled += 1
                    continue
                }
                do {
                    let isUpdate = entry.eventIdentifier != nil
                    entry.eventIdentifier = try store.saveEvent(
                        content,
                        existingIdentifier: entry.eventIdentifier,
                        calendarIdentifier: calendarIdentifier)
                    entry.eventSignature = content.signature
                    if isUpdate { summary.updated += 1 } else { summary.created += 1 }
                    summary.scheduled += 1
                } catch {
                    summary.failures += 1
                }
            } else if !entry.isAvailable, let identifier = entry.eventIdentifier {
                do {
                    if store.eventExists(identifier: identifier) {
                        try store.removeEvent(identifier: identifier)
                        summary.removed += 1
                    }
                    entry.eventIdentifier = nil
                    entry.eventSignature = nil
                } catch {
                    summary.failures += 1
                }
            }
        }

        state.entries = state.entries.filter { _, entry in
            entry.expiresAt > now.addingTimeInterval(-Self.pruneAfterExpiry)
        }
        return (state, summary)
    }

    /// Removes every future event CodexBar created, keeping past events and the calendar itself.
    @MainActor
    static func removeFutureEvents(
        state: ResetCreditCalendarState,
        now: Date,
        store: ResetCreditCalendarEventStore) -> (state: ResetCreditCalendarState, failures: Int)
    {
        var failures = 0
        for entry in state.entries.values where entry.expiresAt > now {
            guard let identifier = entry.eventIdentifier, store.eventExists(identifier: identifier) else { continue }
            do {
                try store.removeEvent(identifier: identifier)
            } catch {
                failures += 1
            }
        }
        return (ResetCreditCalendarState(calendarIdentifier: state.calendarIdentifier), failures)
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
            alarmOffsets: Self.alarmLeadTimes.map { Self.eventLeadTime - $0 })
    }
}
