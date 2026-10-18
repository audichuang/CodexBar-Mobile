import CodexBarSync
import EventKit
import Foundation
import Testing
@testable import CodexBarMobile

/// Research 077 — reset-credit detail and calendar reminders.
@MainActor
@Suite("v0.76.0.2 reset-credit calendar")
struct V077ResetCreditCalendarTests {
    private let now = Date(timeIntervalSince1970: 1_792_000_000)
    private let day: TimeInterval = 86400

    // MARK: - Fixtures

    private func provider(
        _ providerID: String,
        email: String? = "user@example.com",
        accountRecordKey: String? = nil,
        inventory: SyncResetCreditInventory? = nil,
        codex: SyncCodexResetCredits? = nil) -> ProviderUsageSnapshot
    {
        ProviderUsageSnapshot(
            providerID: providerID,
            providerName: providerID.capitalized,
            primary: nil,
            secondary: nil,
            accountEmail: email,
            loginMethod: nil,
            statusMessage: nil,
            isError: false,
            lastUpdated: self.now,
            codexResetCredits: codex,
            accountRecordKey: accountRecordKey,
            resetCreditInventory: inventory)
    }

    private func claude(_ expirations: [Date?], observedAt: Date, email: String = "user@example.com")
        -> ProviderUsageSnapshot
    {
        self.provider(
            "claude",
            email: email,
            inventory: SyncResetCreditInventory(expirations: expirations, updatedAt: observedAt))
    }

    private func codexCredit(_ id: String, status: String, expiresAt: Date?) -> SyncCodexResetCredit {
        SyncCodexResetCredit(
            id: id,
            resetType: "manual",
            status: status,
            grantedAt: self.now.addingTimeInterval(-self.day),
            expiresAt: expiresAt,
            redeemStartedAt: nil,
            redeemedAt: nil)
    }

    private func reconcile(
        _ state: ResetCreditCalendarState,
        _ providers: [ProviderUsageSnapshot],
        at date: Date? = nil,
        store: FakeCalendarStore) throws -> (state: ResetCreditCalendarState, summary: ResetCreditCalendarSyncSummary)
    {
        try ResetCreditCalendarPlanner.reconcile(
            state: state,
            observations: ResetCreditObservation.observations(from: providers),
            now: date ?? self.now,
            store: store,
            draft: { entry in
                ResetCreditCalendarPlanner.eventDraft(for: entry, includeAccount: true, expiryText: "expiry")
            })
    }

    // MARK: - Observations

    @Test func `Codex observation lists only available unexpired credits`() throws {
        let codex = SyncCodexResetCredits(
            availableCount: 2,
            nextExpiresAt: self.now.addingTimeInterval(self.day),
            credits: [
                self.codexCredit("a", status: "available", expiresAt: self.now.addingTimeInterval(2 * self.day)),
                self.codexCredit("b", status: "available", expiresAt: self.now.addingTimeInterval(self.day)),
                self.codexCredit("c", status: "redeemed", expiresAt: self.now.addingTimeInterval(3 * self.day)),
                self.codexCredit("d", status: "available", expiresAt: self.now.addingTimeInterval(-60)),
            ],
            updatedAt: self.now)
        let observation = try #require(ResetCreditObservation.make(from: self.provider("codex", codex: codex)))
        #expect(observation.expirations == [
            self.now.addingTimeInterval(self.day),
            self.now.addingTimeInterval(2 * self.day),
        ])
        #expect(observation.observedAt == self.now)
    }

    @Test func `Codex count without a credit list stays unknown`() {
        let codex = SyncCodexResetCredits(
            availableCount: 1,
            nextExpiresAt: self.now.addingTimeInterval(self.day),
            credits: [],
            updatedAt: self.now)
        #expect(ResetCreditObservation.make(from: self.provider("codex", codex: codex)) == nil)
        let presentation = ResetCreditsCardPresentation.make(
            provider: self.provider("codex", codex: codex),
            now: self.now)
        #expect(presentation?.availableCount == 1)
        #expect(presentation?.groups.first?.expiresAt == self.now.addingTimeInterval(self.day))
    }

    @Test func `Claude without an inventory from an older Mac has no observation`() {
        #expect(ResetCreditObservation.make(from: self.provider("claude")) == nil)
        #expect(ResetCreditsCardPresentation.make(provider: self.provider("claude"), now: self.now) == nil)
    }

    @Test func `Mock providers never reach the calendar but still render`() {
        let mock = self.claude([self.now.addingTimeInterval(self.day)], observedAt: self.now, email: "x@codexbar.test")
        #expect(ResetCreditObservation.observations(from: [mock]).isEmpty)
        #expect(ResetCreditsCardPresentation.make(provider: mock, now: self.now)?.availableCount == 1)
    }

    @Test func `Card groups identical expiries and hides an empty inventory`() throws {
        let expiry = self.now.addingTimeInterval(self.day)
        let presentation = try #require(ResetCreditsCardPresentation.make(
            provider: self.claude([expiry, nil, expiry], observedAt: self.now),
            now: self.now))
        #expect(presentation.availableCount == 3)
        #expect(presentation.groups == [.init(expiresAt: expiry, count: 2), .init(expiresAt: nil, count: 1)])
        #expect(ResetCreditsCardPresentation
            .make(provider: self.claude([], observedAt: self.now), now: self.now) == nil)
    }

    // MARK: - Calendar reconcile

    @Test func `First sync creates one event per expiry with the reset count`() throws {
        let store = FakeCalendarStore()
        let expiry = self.now.addingTimeInterval(4 * self.day)
        let result = try self.reconcile(
            ResetCreditCalendarState(),
            [self.claude([expiry, expiry, self.now.addingTimeInterval(9 * self.day)], observedAt: self.now)],
            store: store)
        #expect(result.summary.created == 2)
        #expect(store.calendars.count == 1)
        #expect(store.events.count == 2)
        let first = try #require(store.events.values.first { $0.endDate == expiry })
        #expect(first.startDate == expiry.addingTimeInterval(-30 * 60))
        #expect(first.alarmOffsets == [-(self.day - 30 * 60), -(3600 - 30 * 60)])
        #expect(first.title.contains("2"))
        #expect(first.notes.contains("user@example.com"))
    }

    @Test func `Using the only reset early removes its future event`() throws {
        let store = FakeCalendarStore()
        let expiry = self.now.addingTimeInterval(2 * self.day)
        var state = try self.reconcile(
            ResetCreditCalendarState(), [self.claude([expiry], observedAt: self.now)], store: store).state
        #expect(store.events.count == 1)

        // The Mac confirms that no reset is left.
        let later = self.now.addingTimeInterval(3600)
        let result = try self.reconcile(state, [self.claude([], observedAt: later)], at: later, store: store)
        state = result.state
        #expect(result.summary.removed == 1)
        #expect(store.events.isEmpty)
        #expect(state.entries.values.allSatisfy { !$0.isAvailable && $0.eventIdentifier == nil })
    }

    @Test func `Unknown inventory leaves existing events untouched`() throws {
        let store = FakeCalendarStore()
        let expiry = self.now.addingTimeInterval(2 * self.day)
        let state = try self.reconcile(
            ResetCreditCalendarState(), [self.claude([expiry], observedAt: self.now)], store: store).state
        // An older Mac (or a CLI source) reports Claude without an inventory.
        let result = try self.reconcile(state, [self.provider("claude")], store: store)
        #expect(result.summary.removed == 0)
        #expect(store.events.count == 1)
    }

    @Test func `An older observation can neither delete nor resurrect an event`() throws {
        let store = FakeCalendarStore()
        let expiry = self.now.addingTimeInterval(2 * self.day)
        var state = try self.reconcile(
            ResetCreditCalendarState(), [self.claude([expiry], observedAt: self.now)], store: store).state

        // A stale writer that read the account before the reset existed.
        state = try self.reconcile(
            state, [self.claude([], observedAt: self.now.addingTimeInterval(-3600))], store: store).state
        #expect(store.events.count == 1)

        // The reset is used; then a stale writer still lists it.
        state = try self.reconcile(
            state, [self.claude([], observedAt: self.now.addingTimeInterval(60))], store: store).state
        #expect(store.events.isEmpty)
        state = try self.reconcile(
            state, [self.claude([expiry], observedAt: self.now.addingTimeInterval(30))], store: store).state
        #expect(store.events.isEmpty)
    }

    @Test func `Unchanged events are not rewritten`() throws {
        let store = FakeCalendarStore()
        let providers = [self.claude([self.now.addingTimeInterval(self.day)], observedAt: self.now)]
        let state = try self.reconcile(ResetCreditCalendarState(), providers, store: store).state
        let result = try self.reconcile(state, providers, store: store)
        #expect(result.summary.created == 0)
        #expect(result.summary.updated == 0)
        #expect(result.summary.scheduled == 1)
        #expect(store.saveCount == 1)
    }

    @Test func `A count change updates the existing event`() throws {
        let store = FakeCalendarStore()
        let expiry = self.now.addingTimeInterval(self.day)
        let state = try self.reconcile(
            ResetCreditCalendarState(), [self.claude([expiry, expiry], observedAt: self.now)], store: store).state
        let result = try self.reconcile(
            state, [self.claude([expiry], observedAt: self.now.addingTimeInterval(60))], store: store)
        #expect(result.summary.updated == 1)
        #expect(store.events.count == 1)
        #expect(store.events.values.first?.title.contains("2") == false)
    }

    @Test func `An event the user deleted is not recreated`() throws {
        let store = FakeCalendarStore()
        let expiry = self.now.addingTimeInterval(self.day)
        var state = try self.reconcile(
            ResetCreditCalendarState(), [self.claude([expiry], observedAt: self.now)], store: store).state
        store.events.removeAll()
        state = try self.reconcile(
            state, [self.claude([expiry], observedAt: self.now.addingTimeInterval(60))], store: store).state
        #expect(store.events.isEmpty)
        #expect(state.entries.values.first?.dismissedByUser == true)
    }

    @Test func `A deleted CodexBar calendar is recreated with every future event`() throws {
        let store = FakeCalendarStore()
        let providers = [self.claude([self.now.addingTimeInterval(self.day)], observedAt: self.now)]
        var state = try self.reconcile(ResetCreditCalendarState(), providers, store: store).state
        store.calendars.removeAll()
        store.events.removeAll()
        state = try self.reconcile(state, providers, store: store).state
        #expect(store.calendars.count == 1)
        #expect(store.events.count == 1)
        #expect(state.calendarIdentifier == store.calendars.first)
    }

    @Test func `Past events stay in the calendar and their state is pruned later`() throws {
        let store = FakeCalendarStore()
        let expiry = self.now.addingTimeInterval(self.day)
        var state = try self.reconcile(
            ResetCreditCalendarState(), [self.claude([expiry], observedAt: self.now)], store: store).state

        let afterExpiry = expiry.addingTimeInterval(3600)
        state = try self.reconcile(state, [self.claude([], observedAt: afterExpiry)], at: afterExpiry, store: store)
            .state
        #expect(store.events.count == 1)
        #expect(state.entries.count == 1)

        let monthLater = expiry.addingTimeInterval(31 * self.day)
        state = try self.reconcile(state, [], at: monthLater, store: store).state
        #expect(state.entries.isEmpty)
        #expect(store.events.count == 1)
    }

    @Test func `Accounts are reconciled independently`() throws {
        let store = FakeCalendarStore()
        let expiry = self.now.addingTimeInterval(self.day)
        let state = try self.reconcile(
            ResetCreditCalendarState(),
            [
                self.claude([expiry], observedAt: self.now, email: "a@example.com"),
                self.claude([expiry], observedAt: self.now, email: "b@example.com"),
            ],
            store: store).state
        #expect(store.events.count == 2)

        // Only account A reports; account B is unknown and keeps its event.
        _ = try self.reconcile(
            state,
            [self.claude([], observedAt: self.now.addingTimeInterval(60), email: "a@example.com")],
            store: store)
        #expect(store.events.count == 1)
        #expect(store.events.values.first?.notes.contains("b@example.com") == true)
    }

    @Test func `A second device adopts the event already in the shared calendar`() throws {
        let store = FakeCalendarStore()
        let providers = [self.claude([self.now.addingTimeInterval(self.day)], observedAt: self.now)]
        let first = try self.reconcile(ResetCreditCalendarState(), providers, store: store).state
        // Another device on the same iCloud calendar starts with empty local state.
        let second = try self.reconcile(
            ResetCreditCalendarState(calendarIdentifier: first.calendarIdentifier),
            providers,
            store: store).state
        #expect(store.events.count == 1)
        #expect(second.entries.values.first?.eventIdentifier == first.entries.values.first?.eventIdentifier)
        #expect(store.events.values.first?.url?.absoluteString.contains("example.com") == false)
    }

    @Test func `No calendar is created when nothing is scheduled`() throws {
        let store = FakeCalendarStore()
        let result = try self.reconcile(
            ResetCreditCalendarState(),
            [self.claude([], observedAt: self.now)],
            store: store)
        #expect(store.calendars.isEmpty)
        #expect(result.state.calendarIdentifier == nil)
    }

    @Test func `Turning off removes future events and keeps past ones`() throws {
        let store = FakeCalendarStore()
        let soon = self.now.addingTimeInterval(self.day)
        let later = self.now.addingTimeInterval(5 * self.day)
        let state = try self.reconcile(
            ResetCreditCalendarState(), [self.claude([soon, later], observedAt: self.now)], store: store).state

        let result = ResetCreditCalendarPlanner.removeFutureEvents(
            state: state,
            now: soon.addingTimeInterval(60),
            store: store)
        #expect(store.events.count == 1)
        #expect(store.events.values.first?.endDate == soon)
        #expect(result.state.entries.isEmpty)
        #expect(result.state.calendarIdentifier == state.calendarIdentifier)
    }

    @Test func `Hidden personal info keeps the account out of event notes`() {
        let entry = ResetCreditCalendarEntry(
            key: "k",
            scopeKey: "claude|",
            providerID: "claude",
            providerName: "Claude",
            accountLabel: "user@example.com",
            expiresAt: self.now,
            count: 1,
            isAvailable: true,
            lastObservedAt: self.now,
            eventIdentifier: nil,
            eventSignature: nil,
            dismissedByUser: false)
        let hidden = ResetCreditCalendarPlanner.eventDraft(for: entry, includeAccount: false, expiryText: "x")
        #expect(!hidden.notes.contains("user@example.com"))
        let shown = ResetCreditCalendarPlanner.eventDraft(for: entry, includeAccount: true, expiryText: "x")
        #expect(shown.notes.contains("user@example.com"))
    }

    // MARK: - Wire compatibility

    @Test func `Payload without the inventory key decodes as unknown`() throws {
        let encoded = try JSONEncoder().encode(self.provider("claude"))
        let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(json["resetCreditInventory"] == nil)
        let decoded = try JSONDecoder().decode(ProviderUsageSnapshot.self, from: encoded)
        #expect(decoded.resetCreditInventory == nil)
    }

    @Test func `Inventory round-trips including an empty confirmation and no-expiry resets`() throws {
        for expirations in [[], [nil, self.now.addingTimeInterval(self.day)]] as [[Date?]] {
            let snapshot = self.claude(expirations, observedAt: self.now)
            let decoded = try JSONDecoder().decode(
                ProviderUsageSnapshot.self,
                from: JSONEncoder().encode(snapshot))
            #expect(decoded.resetCreditInventory == snapshot.resetCreditInventory)
        }
    }

    @Test func `A malformed inventory is unknown without dropping the provider`() throws {
        let encoded = try JSONEncoder().encode(self.provider("claude"))
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json["resetCreditInventory"] = ["expirations": "soon", "updatedAt": 0]
        let decoded = try JSONDecoder().decode(
            ProviderUsageSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.providerID == "claude")
        #expect(decoded.resetCreditInventory == nil)

        let tooMany = Array(repeating: 0.0, count: SyncResetCreditInventory.maximumExpirations + 1)
        json["resetCreditInventory"] = ["expirations": tooMany, "updatedAt": 0]
        let capped = try JSONDecoder().decode(
            ProviderUsageSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json))
        #expect(capped.resetCreditInventory == nil)
    }

    @Test func `Merger keeps the newest inventory even when it is empty`() throws {
        let older = SyncedUsageSnapshot(
            providers: [self.claude([self.now.addingTimeInterval(self.day)], observedAt: self.now)],
            syncTimestamp: self.now,
            deviceName: "Mac A",
            deviceID: "mac-a")
        let newer = SyncedUsageSnapshot(
            providers: [self.claude([], observedAt: self.now.addingTimeInterval(600))],
            syncTimestamp: self.now,
            deviceName: "Mac B",
            deviceID: "mac-b")
        let merged = try #require(CloudSyncReader.mergeSnapshots([older, newer]))
        let claude = try #require(merged.providers.first { $0.providerID == "claude" })
        #expect(claude.resetCreditInventory?.expirations == [])
        #expect(claude.resetCreditInventory?.updatedAt == self.now.addingTimeInterval(600))
    }
}

@MainActor
private final class FakeCalendarStore: ResetCreditCalendarEventStore {
    var calendars: [String] = []
    var events: [String: ResetCreditCalendarEventDraft] = [:]
    var saveCount = 0
    private var nextID = 0

    func calendarExists(identifier: String) -> Bool {
        self.calendars.contains(identifier)
    }

    func makeCalendar() throws -> String {
        self.nextID += 1
        let identifier = "calendar-\(self.nextID)"
        self.calendars.append(identifier)
        return identifier
    }

    func eventExists(identifier: String) -> Bool {
        self.events[identifier] != nil
    }

    func existingEventIdentifier(
        for draft: ResetCreditCalendarEventDraft,
        calendarIdentifier: String) -> String?
    {
        self.events.first { $0.value.url != nil && $0.value.url == draft.url }?.key
    }

    func saveEvent(
        _ draft: ResetCreditCalendarEventDraft,
        existingIdentifier: String?,
        calendarIdentifier: String) throws -> String
    {
        self.saveCount += 1
        let identifier = existingIdentifier ?? {
            self.nextID += 1
            return "event-\(self.nextID)"
        }()
        self.events[identifier] = draft
        return identifier
    }

    func removeEvent(identifier: String) throws {
        self.events.removeValue(forKey: identifier)
    }
}

/// Real EventKit round trip. Runs only where the test host already has calendar Full Access (grant it on a
/// dedicated simulator); it creates and deletes its own calendar and never touches existing events.
@MainActor
@Suite(
    "v0.76.0.2 reset-credit calendar EventKit",
    .serialized,
    .enabled(if: EKEventStore.authorizationStatus(for: .event) == .fullAccess))
struct V077ResetCreditEventKitTests {
    @Test func `EventKit store creates updates and removes events in its own calendar`() throws {
        let eventStore = EKEventStore()
        let store = EventKitResetCreditCalendarStore(eventStore: eventStore)
        let calendarID = try store.makeCalendar()
        defer {
            if let calendar = eventStore.calendar(withIdentifier: calendarID) {
                try? eventStore.removeCalendar(calendar, commit: true)
            }
        }
        #expect(store.calendarExists(identifier: calendarID))
        #expect(eventStore.calendar(withIdentifier: calendarID)?.title == "CodexBar")

        let expiry = Date().addingTimeInterval(3 * 86400).rounded()
        let draft = ResetCreditCalendarEventDraft(
            title: "Claude reset credit expires",
            startDate: expiry.addingTimeInterval(-1800),
            endDate: expiry,
            notes: "Expires: test",
            alarmOffsets: [-84600, -1800],
            url: ResetCreditCalendarPlanner.eventURL(key: "claude|test#1"))
        let eventID = try store.saveEvent(draft, existingIdentifier: nil, calendarIdentifier: calendarID)
        let saved = try #require(eventStore.event(withIdentifier: eventID))
        #expect(saved.calendar.calendarIdentifier == calendarID)
        #expect(saved.url == draft.url)
        #expect(store.existingEventIdentifier(for: draft, calendarIdentifier: calendarID) == eventID)
        #expect(try store.makeCalendar() == calendarID)
        #expect(saved.endDate == expiry)
        #expect(saved.alarms?.map(\.relativeOffset).sorted() == [-84600, -1800])

        let renamed = ResetCreditCalendarEventDraft(
            title: "2 Claude reset credits expire",
            startDate: draft.startDate,
            endDate: draft.endDate,
            notes: draft.notes,
            alarmOffsets: draft.alarmOffsets,
            url: draft.url)
        let updatedID = try store.saveEvent(renamed, existingIdentifier: eventID, calendarIdentifier: calendarID)
        #expect(updatedID == eventID)
        #expect(eventStore.event(withIdentifier: eventID)?.title == "2 Claude reset credits expire")

        try store.removeEvent(identifier: eventID)
        #expect(!store.eventExists(identifier: eventID))
    }
}

extension Date {
    fileprivate func rounded() -> Date {
        Date(timeIntervalSince1970: self.timeIntervalSince1970.rounded())
    }
}
