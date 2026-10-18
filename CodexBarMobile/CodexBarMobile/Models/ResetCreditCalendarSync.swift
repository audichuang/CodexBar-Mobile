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

    func eventExists(identifier: String) -> Bool {
        self.eventStore.event(withIdentifier: identifier) != nil
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

    static let shared = ResetCreditCalendarSync()
    static let enabledKey = "resetCreditCalendarEnabled"
    static let stateKey = "resetCreditCalendarState"

    private(set) var isEnabled: Bool
    private(set) var accessState: AccessState = .notDetermined
    private(set) var lastSyncAt: Date?
    private(set) var lastSummary: ResetCreditCalendarSyncSummary?
    private(set) var lastSyncFailed = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let eventStore = EKEventStore()
    @ObservationIgnored private lazy var store = EventKitResetCreditCalendarStore(eventStore: self.eventStore)
    @ObservationIgnored private var latestProviders: [ProviderUsageSnapshot] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        self.refreshAccessState()
    }

    /// Identity of the reset-credit data in a snapshot; drives the view task that calls `sync`.
    static func refreshKey(for snapshot: SyncedUsageSnapshot?) -> String {
        ResetCreditObservation.observations(from: snapshot?.providers ?? [])
            .map { observation in
                let expirations = observation.expirations
                    .map { $0.map { String(Int64($0.timeIntervalSince1970)) } ?? "-" }
                    .joined(separator: ",")
                return "\(observation.scopeKey)@\(observation.observedAt.timeIntervalSince1970)[\(expirations)]"
            }
            .joined(separator: ";")
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
    func setEnabled(_ enabled: Bool, providers: [ProviderUsageSnapshot]) async {
        self.latestProviders = providers
        guard enabled else {
            self.refreshAccessState()
            // Without access the events cannot be removed; keep their state so turning the switch back on
            // after restoring access continues with the same events instead of duplicating them.
            if self.accessState == .granted {
                let result = ResetCreditCalendarPlanner.removeFutureEvents(
                    state: self.loadState(),
                    now: Date(),
                    store: self.store)
                self.saveState(result.state)
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
        self.sync(providers: self.latestProviders)
    }

    func sync(providers: [ProviderUsageSnapshot], now: Date = Date()) {
        self.latestProviders = providers
        guard self.isEnabled else { return }
        self.refreshAccessState()
        guard self.accessState == .granted else { return }

        let includeAccount = !self.defaults.bool(forKey: MobileSettingsKeys.hidePersonalInfo)
        do {
            let result = try ResetCreditCalendarPlanner.reconcile(
                state: self.loadState(),
                observations: ResetCreditObservation.observations(from: providers),
                now: now,
                store: self.store,
                draft: { entry in
                    ResetCreditCalendarPlanner.eventDraft(
                        for: entry,
                        includeAccount: includeAccount,
                        expiryText: entry.expiresAt.formatted(date: .complete, time: .shortened))
                })
            self.saveState(result.state)
            self.lastSummary = result.summary
            self.lastSyncFailed = result.summary.failures > 0
        } catch {
            self.lastSyncFailed = true
        }
        self.lastSyncAt = now
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
