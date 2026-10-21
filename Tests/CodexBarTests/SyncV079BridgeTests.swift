import CodexBarSync
import Foundation
import Testing
@testable import CodexBar
@testable import CodexBarCore

@MainActor
struct SyncV079BridgeTests {
    @Test
    func `plugin warning metadata survives the bridge and unknown severity preserves the row`() throws {
        let row = try ProviderDetailSection.Row(label: "Queue", value: "Nearly full", severity: .warning)
        let mapped = try SyncCoordinator.mapDetails([.init(rows: [row])])
        #expect(mapped.first?.rows.first?.severity == .warning)
        let raw = Data(#"{"label":"Queue","value":"Future status","severity":"future-value"}"#.utf8)
        let decoded = try JSONDecoder().decode(SyncProviderDetailSection.Row.self, from: raw)
        #expect(decoded.value == "Future status")
        #expect(decoded.severity == nil)
        let legacy = try JSONDecoder().decode(
            SyncProviderDetailSection.Row.self, from: Data(#"{"label":"Queue","value":"Ready"}"#.utf8))
        #expect(legacy.severity == nil)
    }

    @Test(arguments: ["claude-swap", "tcr"])
    func `adapter accounts publish independent quotas and retire removed slots`(source: String) async throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }
        let settings = testSettingsStore(
            suiteName: "SyncV079BridgeTests-\(source)",
            userDefaults: InMemoryUserDefaults(),
            config: testConfigWithAllProvidersDisabled(),
            keychainAccessPolicy: .init(setDisabled: { _ in }, isExplicitlyDisabled: { false }))
        enableTestProviders([.claude], settings: settings)
        settings.iCloudSyncEnabled = true
        settings.costUsageEnabled = true
        settings.claudeSwapEnabled = true
        settings.claudeSwapShowSingleAccount = true
        let store = UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings,
            startupBehavior: .testing,
            environmentBase: ["HOME": env.root.path],
            widgetSnapshotURL: env.root.appendingPathComponent("widget.json"),
            widgetTimelineReloader: {})
        let now = Date()
        store.claudeSwapAccountSnapshots = (1...2).map { slot in
            ProviderAccountUsageSnapshot(
                id: .init(source: source, opaqueID: "\(slot)"),
                provider: .claude,
                displayLabel: "Fixture \(slot)",
                isActive: source == "claude-swap" && slot == 1,
                snapshot: UsageSnapshot(
                    primary: RateWindow(
                        usedPercent: Double(slot * 20),
                        windowMinutes: 300,
                        resetsAt: nil,
                        resetDescription: nil),
                    secondary: nil,
                    updatedAt: now,
                    identity: .init(
                        providerID: .claude,
                        accountEmail: nil,
                        accountOrganization: nil,
                        loginMethod: source,
                        accountID: "\(source):\(slot)")),
                error: nil,
                sourceLabel: source)
        }
        let first = try #require(store.claudeSwapAccountSnapshots.first)
        #expect(SyncCoordinator.adapterAccountRecordKey(first, deviceID: "mac-a") !=
            SyncCoordinator.adapterAccountRecordKey(first, deviceID: "mac-b"))
        store._setTokenSnapshotForTesting(
            CostUsageTokenSnapshot(
                sessionTokens: 100,
                sessionCostUSD: 1,
                last30DaysTokens: 100,
                last30DaysCostUSD: 1,
                daily: [],
                updatedAt: now),
            provider: .claude)
        let pusher = MockSyncPusher()
        let sync = SyncCoordinator(store: store, settings: settings, syncManager: pusher)
        await sync.pushCurrentSnapshot()
        let providers = try #require(pusher.lastSnapshot?.providers.filter { $0.providerID == "claude" })
        #expect(providers.count == 3)
        #expect(Set(providers.compactMap { $0.primary?.usedPercent }) == [20, 40])
        #expect(Set(providers.compactMap(\.accountRecordKey)).count == 3)
        #expect(providers.filter { $0.costSummary != nil }.count == 1)
        #expect(providers.filter(\.isProviderLevelCostEnvelope).count == 1)
        #expect(providers.filter { $0.primary != nil }.allSatisfy { $0.costSummary == nil })
        store.claudeSwapAccountSnapshots.removeLast()
        await sync.pushCurrentSnapshot()
        #expect(pusher.lastSnapshot?.providers.filter { $0.providerID == "claude" }.count == 2)
        // The production cleanup intentionally confirms a missing record across two successful cycles.
        await sync.pushCurrentSnapshot()
        #expect(pusher.deletedRecordNamesAcrossCalls.flatMap(\.self).count == 1)
        store.claudeSwapAccountSnapshots = [ProviderAccountUsageSnapshot(
            id: .init(source: source, opaqueID: "1"),
            provider: .claude,
            displayLabel: "Expired fixture",
            accountEmail: "expired@example.test",
            isActive: false,
            snapshot: nil,
            error: "Expired fixture",
            sourceLabel: source)]
        await sync.pushCurrentSnapshot()
        let expired = try #require(pusher.lastSnapshot?.providers.first { $0.accountEmail == "expired@example.test" })
        #expect(expired.primary == nil && expired.isError)
        #expect(expired.lastUpdated == .distantPast)
        #expect(expired.accountRecordKey != providers.first { $0.primary != nil }?.accountRecordKey)
        settings.claudeSwapShowSingleAccount = false
        await sync.pushCurrentSnapshot()
        #expect(pusher.lastSnapshot?.providers.contains { $0.accountRecordKey?.hasPrefix("adapter:") == true } == false)
    }
}
