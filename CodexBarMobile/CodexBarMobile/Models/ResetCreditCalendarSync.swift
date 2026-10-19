import CodexBarSync
import EventKit
import Foundation
import Observation
import UIKit

enum ResetCreditCalendarError: Error {
    case noWritableSource
    case calendarMissing
}

/// EventKit-backed store for the dedicated CodexBar calendar.
@MainActor
final class EventKitResetCreditCalendarStore: ResetCreditCalendarEventStore {
    static let calendarTitle = "CodexBar"

    private let eventStore: EKEventStore

    init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }

    func calendarExists(identifier: String) -> Bool {
        self.eventStore.calendar(withIdentifier: identifier) != nil
    }

    func makeCalendar() throws -> String {
        let existing = self.eventStore.calendars(for: .event).filter { calendar in
            calendar.title == Self.calendarTitle && calendar.allowsContentModifications
        }
        let preferredSourceIDs = self.candidateSources().map(\.sourceIdentifier)
        if let reusable = existing.min(by: { lhs, rhs in
            (preferredSourceIDs.firstIndex(of: lhs.source.sourceIdentifier) ?? .max)
                < (preferredSourceIDs.firstIndex(of: rhs.source.sourceIdentifier) ?? .max)
        }) {
            return reusable.calendarIdentifier
        }

        var lastError: Error = ResetCreditCalendarError.noWritableSource
        for source in self.candidateSources() {
            let calendar = EKCalendar(for: .event, eventStore: self.eventStore)
            calendar.title = Self.calendarTitle
            calendar.cgColor = UIColor.systemOrange.cgColor
            calendar.source = source
            do {
                try self.eventStore.saveCalendar(calendar, commit: true)
                return calendar.calendarIdentifier
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    func eventIdentifiers(matching draft: ResetCreditCalendarEventDraft, calendarIdentifier: String) -> [String] {
        guard let url = draft.url, let calendar = self.eventStore.calendar(withIdentifier: calendarIdentifier)
        else { return [] }
        let predicate = self.eventStore.predicateForEvents(
            withStart: draft.startDate.addingTimeInterval(-60),
            end: draft.endDate.addingTimeInterval(60),
            calendars: [calendar])
        return self.eventStore.events(matching: predicate)
            .filter { $0.url == url }
            .sorted { lhs, rhs in
                let left = lhs.creationDate ?? .distantFuture
                let right = rhs.creationDate ?? .distantFuture
                if left != right { return left < right }
                return (lhs.calendarItemExternalIdentifier ?? "") < (rhs.calendarItemExternalIdentifier ?? "")
            }
            .compactMap(\.eventIdentifier)
    }

    func saveEvent(
        _ draft: ResetCreditCalendarEventDraft,
        existingIdentifier: String?,
        calendarIdentifier: String) throws -> String
    {
        let event: EKEvent
        if let existingIdentifier, let existing = self.eventStore.event(withIdentifier: existingIdentifier) {
            event = existing
        } else {
            guard let calendar = self.eventStore.calendar(withIdentifier: calendarIdentifier) else {
                throw ResetCreditCalendarError.calendarMissing
            }
            event = EKEvent(eventStore: self.eventStore)
            event.calendar = calendar
        }
        event.title = draft.title
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.notes = draft.notes
        event.url = draft.url
        event.alarms = draft.alarmOffsets.map { EKAlarm(relativeOffset: $0) }
        try self.eventStore.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }

    func removeEvent(identifier: String) throws {
        guard let event = self.eventStore.event(withIdentifier: identifier) else { return }
        try self.eventStore.remove(event, span: .thisEvent, commit: true)
    }

    /// iCloud first so the calendar follows the user to their other devices, then the default calendar's
    /// account, then an on-device calendar.
    private func candidateSources() -> [EKSource] {
        let sources = self.eventStore.sources
        var candidates: [EKSource] = []
        func append(_ source: EKSource?) {
            guard let source, !candidates.contains(where: { $0.sourceIdentifier == source.sourceIdentifier })
            else { return }
            candidates.append(source)
        }
        append(sources.first { $0.sourceType == .calDAV && $0.title == "iCloud" })
        append(self.eventStore.defaultCalendarForNewEvents?.source)
        append(sources.first { $0.sourceType == .local })
        return candidates
    }
}

/// Keeps reset-credit expirations in the user's calendar (Research 077). Off by default.
@MainActor
@Observable
final class ResetCreditCalendarSync {
    enum AccessState: Equatable {
        case notDetermined
        case granted
        case writeOnly
        case denied
        case restricted
    }

    /// Each Mac's own snapshots (before any merge) and the physical Mac behind each raw device key.
    struct Input {
        var snapshots: [SyncedUsageSnapshot] = []
        var canonicalDeviceIDs: [String: String] = [:]

        var observations: [ResetCreditObservation] {
            ResetCreditObservation.observations(
                fromDeviceSnapshots: self.snapshots,
                canonicalDeviceIDs: self.canonicalDeviceIDs)
        }

        @MainActor
        static func make(from usageData: SyncedUsageData) -> Input {
            let calendar = ResetCreditObservation.calendarSnapshots(
                raw: usageData.rawDeviceSnapshots,
                items: usageData.deviceManagementItems)
            return Input(snapshots: calendar.snapshots, canonicalDeviceIDs: calendar.canonicalDeviceIDs)
        }
    }

    static let shared = ResetCreditCalendarSync()
    static let enabledKey = "resetCreditCalendarEnabled"
    static let stateKey = "resetCreditCalendarState"

    /// Unit-test hosts and UI tests run on synthetic preview data that must never reach a real calendar.
    static var isSuppressedForTestLaunch: Bool {
        let process = ProcessInfo.processInfo
        return process.environment["XCTestConfigurationFilePath"] != nil
            || process.arguments.contains { $0.hasPrefix("UI_TEST_") }
    }

    private(set) var isEnabled: Bool
    private(set) var accessState: AccessState = .notDetermined
    private(set) var lastSyncAt: Date?
    private(set) var lastSummary: ResetCreditCalendarSyncSummary?
    private(set) var lastSyncFailed = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let eventStore = EKEventStore()
    @ObservationIgnored private lazy var store = EventKitResetCreditCalendarStore(eventStore: self.eventStore)
    @ObservationIgnored private var latestInput = Input()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        self.refreshAccessState()
    }

    /// Identity of the reset-credit data in a snapshot; drives the view task that calls `sync`.
    static func refreshKey(for input: Input, isDemoMode: Bool) -> String {
        let observations = input.observations
            .map { observation in
                let expirations = observation.expirations
                    .map { $0.map { String(ResetCreditCalendarPlanner.wholeSeconds($0)) } ?? "-" }
                    .joined(separator: ",")
                return "\(observation.scopeKey)@\(observation.observedAt.timeIntervalSince1970)[\(expirations)]"
            }
            .joined(separator: ";")
        // Event notes depend on these too; a change rewrites the notes without waiting for new Mac data.
        let presentation = [
            UserDefaults.standard.bool(forKey: MobileSettingsKeys.hidePersonalInfo) ? "hidden" : "shown",
            TimeZone.current.identifier,
            Locale.current.identifier,
        ].joined(separator: ",")
        return "\(isDemoMode ? "demo" : "live")|\(presentation)|\(observations)"
    }

    func refreshAccessState() {
        self.accessState = switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .writeOnly: .writeOnly
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        // `.authorized` is pre-iOS 17 only; this app targets iOS 17.
        default: .denied
        }
    }

    /// Turning on asks for calendar access first; the switch stays off without full access.
    func setEnabled(_ enabled: Bool, input: Input) async {
        self.latestInput = input
        guard enabled else {
            self.refreshAccessState()
            if self.accessState == .granted {
                let result = ResetCreditCalendarPlanner.removeFutureEvents(
                    state: self.loadState(),
                    now: Date(),
                    store: self.store,
                    draft: self.makeDraft)
                self.saveState(result.state)
            } else {
                // Without access the events cannot be removed yet: queue them, and remove them once access
                // returns (`retryPendingRemovals`).
                self.saveState(ResetCreditCalendarPlanner.queueingFutureRemovals(in: self.loadState(), now: Date()))
            }
            self.updateEnabled(false)
            self.lastSummary = nil
            self.lastSyncAt = nil
            self.lastSyncFailed = false
            return
        }

        if self.accessState == .notDetermined {
            _ = try? await self.eventStore.requestFullAccessToEvents()
        }
        self.refreshAccessState()
        guard self.accessState == .granted else {
            self.updateEnabled(false)
            return
        }
        self.updateEnabled(true)
        self.sync(input: self.latestInput)
    }

    func sync(input: Input, now: Date = Date()) {
        self.latestInput = input
        guard !Self.isSuppressedForTestLaunch else { return }
        guard self.isEnabled else {
            self.retryPendingRemovals(now: now)
            return
        }
        self.refreshAccessState()
        guard self.accessState == .granted else { return }

        do {
            let result = try ResetCreditCalendarPlanner.reconcile(
                state: self.loadState(),
                observations: input.observations,
                now: now,
                store: self.store,
                draft: self.makeDraft)
            self.saveState(result.state)
            self.lastSummary = result.summary
            self.lastSyncFailed = result.summary.failures > 0
        } catch {
            self.lastSyncFailed = true
        }
        self.lastSyncAt = now
    }

    /// Turning reminders off left future events it could not remove yet (no calendar access, or a failed delete).
    /// Derived from the saved state so the notice survives a relaunch.
    func hasPendingRemovals(now: Date = Date()) -> Bool {
        !self.isEnabled && self.loadState().entries.values.contains { !$0.isAvailable && $0.expiresAt > now }
    }

    /// With reminders off, removes queued events once calendar access allows it. Runs on data updates and when
    /// the settings page appears or the app becomes active.
    func retryPendingRemovals(now: Date = Date()) {
        guard !self.isEnabled, !Self.isSuppressedForTestLaunch, self.hasPendingRemovals(now: now) else { return }
        self.refreshAccessState()
        guard self.accessState == .granted else { return }
        let result = ResetCreditCalendarPlanner.removeFutureEvents(
            state: self.loadState(),
            now: now,
            store: self.store,
            draft: self.makeDraft)
        self.saveState(result.state)
    }

    /// Whether the detail card can say its resets are in the calendar.
    var isActive: Bool {
        self.isEnabled && self.accessState == .granted && !Self.isSuppressedForTestLaunch
    }

    private func makeDraft(_ entry: ResetCreditCalendarEntry) -> ResetCreditCalendarEventDraft {
        ResetCreditCalendarPlanner.eventDraft(
            for: entry,
            includeAccount: !self.defaults.bool(forKey: MobileSettingsKeys.hidePersonalInfo),
            expiryText: entry.expiresAt.formatted(date: .complete, time: .shortened))
    }

    private func updateEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
        self.defaults.set(enabled, forKey: Self.enabledKey)
    }

    private func loadState() -> ResetCreditCalendarState {
        guard let data = self.defaults.data(forKey: Self.stateKey),
              let state = try? JSONDecoder().decode(ResetCreditCalendarState.self, from: data)
        else { return ResetCreditCalendarState() }
        return state
    }

    private func saveState(_ state: ResetCreditCalendarState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        self.defaults.set(data, forKey: Self.stateKey)
    }
}
