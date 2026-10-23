import Foundation
import Testing
@testable import CodexBarMobile

@Suite("Cost whole-group ordering")
struct CostDashboardPreferencesTests {
    @Test
    func `default order matches the existing Cost report`() {
        let preferences = CostDashboardPreferences()
        #expect(preferences.orderedGroups == [
            .overview, .providerShare, .modelMix, .budgets, .dailySpend, .dailyTokens, .subscriptionUtilization,
        ])
        let panes = preferences.panes(availableGroups: Set(CostDashboardGroup.allCases))
        #expect(panes.primary == [.overview, .providerShare, .modelMix, .budgets])
        #expect(panes.secondary == [.dailySpend, .dailyTokens, .subscriptionUtilization])
    }

    @Test
    func `moving the last group first crosses the wide pane boundary`() {
        var preferences = CostDashboardPreferences()
        preferences.reorder([
            .subscriptionUtilization,
            .dailyTokens,
            .overview,
            .providerShare,
            .modelMix,
            .budgets,
            .dailySpend,
        ])
        let panes = preferences.panes(availableGroups: Set(CostDashboardGroup.allCases))
        #expect(panes.primary.first == .subscriptionUtilization)
        #expect(panes.secondary.last == .dailySpend)
        #expect(panes.primary + panes.secondary == preferences.orderedGroups)
    }

    @Test
    func `data disappearing hides a group without changing its saved position`() {
        var preferences = CostDashboardPreferences()
        preferences.reorder([.dailyTokens, .modelMix, .subscriptionUtilization, .dailySpend])
        let savedOrder = preferences.groupOrder
        let available: Set<CostDashboardGroup> = [.overview, .dailySpend, .dailyTokens]
        let hidden = preferences.panes(availableGroups: available)
        #expect(hidden.primary + hidden.secondary == [.dailyTokens, .dailySpend, .overview])
        #expect(preferences.groupOrder == savedOrder)
        let restored = preferences.panes(availableGroups: Set(CostDashboardGroup.allCases))
        #expect(restored.primary + restored.secondary == preferences.orderedGroups)
        #expect(restored.primary[1] == .modelMix)
    }

    @Test
    func `every group remains movable into both panes`() {
        let groups = CostDashboardGroup.allCases
        for group in groups {
            var preferences = CostDashboardPreferences()
            preferences.reorder([group] + groups.filter { $0 != group })
            let first = preferences.panes(availableGroups: Set(groups))
            #expect(first.primary.first == group)
            preferences.reorder(groups.filter { $0 != group } + [group])
            let last = preferences.panes(availableGroups: Set(groups))
            #expect(last.secondary.last == group)
            #expect(Set(last.primary + last.secondary) == Set(groups))
        }
    }

    @Test
    func `duplicate and unknown identities do not drop existing groups`() {
        var preferences = CostDashboardPreferences()
        preferences.groupOrder = ["futureGroup", "dailyTokens", "dailyTokens", "overview"]
        #expect(preferences.orderedGroups.first == .dailyTokens)
        #expect(preferences.orderedGroups.count == CostDashboardGroup.allCases.count)
        preferences.reorder([.dailySpend, .dailySpend])
        #expect(preferences.orderedGroups.first == .dailySpend)
        #expect(preferences.groupOrder.contains("futureGroup"))
        #expect(preferences.orderedGroups.count == CostDashboardGroup.allCases.count)
    }

    @MainActor @Test
    func `saved order survives a new store without reading real defaults`() throws {
        let persistence = CostOrderMemoryPersistence()
        let store = CostDashboardPreferencesStore(persistence: persistence)
        store.reorder([.dailyTokens, .subscriptionUtilization, .dailySpend])
        #expect(persistence.saveCount == 1)
        let recreated = CostDashboardPreferencesStore(persistence: persistence)
        #expect(recreated.preferences == store.preferences)
        #expect(!recreated.isReadOnly)
        let saved = try #require(persistence.data)
        #expect(try JSONDecoder().decode(CostDashboardPreferences.self, from: saved) == store.preferences)
    }

    @MainActor @Test
    func `demo order never changes the persistent layout`() {
        let persistence = CostOrderMemoryPersistence()
        let live = CostDashboardPreferencesStore(persistence: persistence)
        live.reorder([.dailySpend])
        let saved = persistence.data
        let demo = CostDashboardPreferencesStore.inMemory()
        demo.reorder([.subscriptionUtilization])
        #expect(demo.preferences.orderedGroups.first == .subscriptionUtilization)
        #expect(live.preferences.orderedGroups.first == .dailySpend)
        #expect(persistence.data == saved)
        #expect(persistence.saveCount == 1)
    }

    @MainActor @Test
    func `unreadable and newer schema bytes stay untouched`() throws {
        var future = CostDashboardPreferences()
        future.schemaVersion = 999
        for data in try [Data("invalid json".utf8), JSONEncoder().encode(future)] {
            let persistence = CostOrderMemoryPersistence(data: data)
            let store = CostDashboardPreferencesStore(persistence: persistence)
            #expect(store.isReadOnly)
            store.reorder([.dailyTokens])
            #expect(store.preferences == CostDashboardPreferences())
            #expect(persistence.data == data)
            #expect(persistence.saveCount == 0)
        }
    }
}

@MainActor
private final class CostOrderMemoryPersistence: CostDashboardPreferencesPersistence {
    var data: Data?
    var saveCount = 0
    init(data: Data? = nil) { self.data = data }
    func load() -> Data? { self.data }
    func save(_ data: Data) {
        self.data = data
        self.saveCount += 1
    }
}
