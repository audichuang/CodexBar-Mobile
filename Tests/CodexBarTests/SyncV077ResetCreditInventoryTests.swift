import CodexBarSync
import Foundation
import Testing
@testable import CodexBar
@testable import CodexBarCore

/// Research 077 — Claude and Grok reset inventories reach iPhone as expiry times only.
@MainActor
@Suite(.serialized)
struct SyncV077ResetCreditInventoryTests {
    private let observed = Date(timeIntervalSince1970: 1_792_000_000)
    private let day: TimeInterval = 86400

    @Test
    func `Claude inventory publishes available expiries and keeps no-expiry resets`() throws {
        let snapshot = UsageSnapshot(
            primary: nil,
            secondary: nil,
            claudeResetCredits: ClaudeRateLimitResetCreditsSnapshot(
                expirations: [
                    nil,
                    self.observed.addingTimeInterval(2 * self.day),
                    self.observed.addingTimeInterval(-60),
                    self.observed.addingTimeInterval(self.day),
                ],
                updatedAt: self.observed),
            updatedAt: self.observed)
        let inventory = try #require(SyncCoordinator.mapResetCreditInventory(provider: .claude, snapshot: snapshot))
        #expect(inventory.expirations == [
            self.observed.addingTimeInterval(self.day),
            self.observed.addingTimeInterval(2 * self.day),
            nil,
        ])
        #expect(inventory.updatedAt == self.observed)
    }

    @Test
    func `Confirmed empty inventories publish while unknown ones stay absent`() {
        let claudeEmpty = UsageSnapshot(
            primary: nil,
            secondary: nil,
            claudeResetCredits: ClaudeRateLimitResetCreditsSnapshot(expirations: [], updatedAt: self.observed),
            updatedAt: self.observed)
        #expect(SyncCoordinator.mapResetCreditInventory(provider: .claude, snapshot: claudeEmpty)?.expirations == [])

        let grokEmpty = UsageSnapshot(
            primary: nil,
            secondary: nil,
            grokResetCredits: GrokRateLimitResetCreditsSnapshot(expirations: [], updatedAt: self.observed),
            updatedAt: self.observed)
        #expect(SyncCoordinator.mapResetCreditInventory(provider: .grok, snapshot: grokEmpty)?.expirations == [])

        let unknown = UsageSnapshot(primary: nil, secondary: nil, updatedAt: self.observed)
        for provider in [UsageProvider.claude, .grok, .codex] {
            #expect(SyncCoordinator.mapResetCreditInventory(provider: provider, snapshot: unknown) == nil)
            #expect(SyncCoordinator.mapResetCreditInventory(provider: provider, snapshot: nil) == nil)
        }
        // Codex keeps its existing `codexResetCredits` lane; another provider never borrows a live inventory.
        #expect(SyncCoordinator.mapResetCreditInventory(provider: .codex, snapshot: claudeEmpty) == nil)
    }

    @Test
    func `A partial Claude inventory is published as incomplete`() throws {
        let snapshot = UsageSnapshot(
            primary: nil,
            secondary: nil,
            claudeResetCredits: ClaudeRateLimitResetCreditsSnapshot(
                expirations: [self.observed.addingTimeInterval(self.day)],
                updatedAt: self.observed,
                isComplete: false),
            updatedAt: self.observed)
        let inventory = try #require(SyncCoordinator.mapResetCreditInventory(provider: .claude, snapshot: snapshot))
        #expect(!inventory.isComplete)
    }

    @Test
    func `Grok inventory publishes its token expiries`() throws {
        let snapshot = UsageSnapshot(
            primary: nil,
            secondary: nil,
            grokResetCredits: GrokRateLimitResetCreditsSnapshot(
                expirations: [
                    self.observed.addingTimeInterval(3 * self.day),
                    self.observed.addingTimeInterval(self.day),
                ],
                updatedAt: self.observed),
            updatedAt: self.observed)
        let inventory = try #require(SyncCoordinator.mapResetCreditInventory(provider: .grok, snapshot: snapshot))
        #expect(inventory.expirations == [
            self.observed.addingTimeInterval(self.day),
            self.observed.addingTimeInterval(3 * self.day),
        ])
    }

    @Test
    func `Claude push carries the inventory while the legacy detail row stays filtered`() async throws {
        let suite = "SyncV077ResetCreditInventoryTests-claude"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let settings = SettingsStore(
            userDefaults: defaults,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
        settings.iCloudSyncEnabled = true
        try settings.setProviderEnabled(
            provider: .claude,
            metadata: #require(ProviderDefaults.metadata[.claude]),
            enabled: true)
        let store = UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings)
        let mock = MockSyncPusher()
        let coordinator = SyncCoordinator(store: store, settings: settings, syncManager: mock)

        let resets = ClaudeRateLimitResetCreditsSnapshot(
            expirations: [self.observed.addingTimeInterval(4 * self.day)],
            updatedAt: self.observed)
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 12,
                windowMinutes: 300,
                resetsAt: self.observed.addingTimeInterval(3600),
                resetDescription: nil),
            secondary: nil,
            details: resets.detailSections(now: self.observed),
            claudeResetCredits: resets,
            updatedAt: self.observed)
        store._setSnapshotForTesting(snapshot, provider: .claude)

        await coordinator.pushCurrentSnapshot()

        let provider = try #require(mock.lastSnapshot?.providers.first { $0.providerID == "claude" })
        #expect(provider.resetCreditInventory?.expirations == [self.observed.addingTimeInterval(4 * self.day)])
        #expect(provider.resetCreditInventory?.updatedAt == self.observed)
        #expect(!provider.details.flatMap(\.rows).contains { $0.label == "Limit Reset Credits" })

        // The wire payload holds expiry times only.
        let json = try #require(String(data: JSONEncoder().encode(provider), encoding: .utf8))
        #expect(json.contains("resetCreditInventory"))
        #expect(!json.contains("grant"))
    }
}
