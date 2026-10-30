import CodexBarCore
import CodexBarSync
import Foundation
import Testing
@testable import CodexBar

/// Mac payload -> iOS reader integration. Builds a multi-account snapshot through the real
/// `SyncCoordinator.pushCurrentSnapshot()`, encodes what the Mac publisher hands to CloudKit with
/// `CloudSyncConstants.makeJSONEncoder()` (the encoder `CloudSyncManager` uses), then decodes it with
/// the shared reader models and `CloudSyncConstants.makeJSONDecoder()` (what `DualZoneReader` and
/// `SyncedUsageData` use on iOS). Guards the fork-owned wire fields: `accountLabel`,
/// `accountRecordKey`, cost summary, `quotaLimit`/`quotaUnit` and detail-row `expiresAt`.
@MainActor
@Suite(.serialized)
struct ForkSyncIntegrationTests {
    private static let rowExpiry = Date(timeIntervalSince1970: 1_800_000_000)

    private struct Published {
        let envelopes: [ProviderUsageEnvelope]
        let legacy: SyncedUsageSnapshot
        let aliceKey: String
        let bobKey: String
    }

    private func makeSettingsStore(suite: String) -> SettingsStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        UserDefaults.standard.removeObject(forKey: MockProviderInjector.userDefaultsKey)
        return SettingsStore(
            userDefaults: defaults,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
    }

    private func makeUsageSnapshot(accountEmail: String, usedPercent: Double) throws -> UsageSnapshot {
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: usedPercent,
                windowMinutes: 43200,
                resetsAt: Date(timeIntervalSince1970: 1_800_000_000),
                resetDescription: "in 30 days",
                quotaLimit: 1000,
                quotaUnit: "credits"),
            secondary: nil,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            identity: ProviderIdentitySnapshot(
                providerID: UsageProvider.claude.instanceID,
                accountEmail: accountEmail,
                accountOrganization: nil,
                loginMethod: "oauth"))
        let row = try ProviderDetailSection.Row(label: "Balance", value: "$5.00", expiresAt: Self.rowExpiry)
        return try snapshot.with(details: [ProviderDetailSection(rows: [row])])
    }

    /// Runs the real Mac publisher path and returns what it would write to CloudKit.
    private func publishTwoAccounts() async throws -> Published {
        let settings = self.makeSettingsStore(suite: "ForkSyncIntegration-TwoAccounts")
        settings.iCloudSyncEnabled = true
        try settings.setProviderEnabled(
            provider: .claude,
            metadata: #require(ProviderDefaults.metadata[.claude]),
            enabled: true)
        settings.addTokenAccount(provider: .claude, label: " Audi ", token: "tok-alice")
        settings.addTokenAccount(provider: .claude, label: "Work", token: "tok-bob")
        settings.setActiveTokenAccountIndex(0, for: .claude)
        let accounts = settings.tokenAccounts(for: .claude)
        let aliceAccount = try #require(accounts.first)
        let bobAccount = try #require(accounts.last)

        let store = UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings)
        let alice = try TokenAccountUsageSnapshot(
            account: aliceAccount,
            snapshot: self.makeUsageSnapshot(accountEmail: "alice@example.com", usedPercent: 10),
            error: nil,
            sourceLabel: nil,
            cacheKey: "fork-int-alice")
        let bob = try TokenAccountUsageSnapshot(
            account: bobAccount,
            snapshot: self.makeUsageSnapshot(accountEmail: "bob@example.com", usedPercent: 60),
            error: nil,
            sourceLabel: nil,
            cacheKey: "fork-int-bob")
        store._setSnapshotForTesting(alice.snapshot, provider: .claude)
        store._setTokenSnapshotForTesting(
            CostUsageTokenSnapshot(
                sessionTokens: 1500,
                sessionCostUSD: 2.40,
                last30DaysTokens: 45000,
                last30DaysCostUSD: 31.25,
                daily: [
                    CostUsageDailyReport.Entry(
                        date: "2026-03-16",
                        inputTokens: 1000,
                        outputTokens: 500,
                        totalTokens: 1500,
                        costUSD: 2.40,
                        modelsUsed: ["claude-sonnet"],
                        modelBreakdowns: []),
                ],
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)),
            provider: .claude)
        store.accountSnapshots[.claude] = [alice, bob]

        let mock = MockSyncPusher()
        let coordinator = SyncCoordinator(store: store, settings: settings, syncManager: mock)
        await coordinator.pushCurrentSnapshot()

        return try Published(
            envelopes: mock.lastPerProviderEnvelopes.filter { $0.provider.providerID == "claude" },
            legacy: #require(mock.lastSnapshot),
            aliceKey: SyncCoordinator.tokenAccountRecordKey(aliceAccount),
            bobKey: SyncCoordinator.tokenAccountRecordKey(bobAccount))
    }

    private func roundTripAsReader<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try CloudSyncConstants.makeJSONEncoder().encode(value)
        return try CloudSyncConstants.makeJSONDecoder().decode(T.self, from: data)
    }

    @Test
    func `Mac multi-account payload decodes on the reader with identical ids, labels and cost`() async throws {
        let published = try await self.publishTwoAccounts()
        #expect(published.envelopes.count == 2)

        for envelope in published.envelopes {
            let decoded = try self.roundTripAsReader(envelope)
            // Envelope syncTimestamp is `Date()` with sub-second precision that ISO8601 truncates,
            // so compare the provider payload (fixed timestamps) rather than the whole envelope.
            #expect(decoded.provider == envelope.provider)
            #expect(decoded.provider.providerID == envelope.provider.providerID)
            #expect(decoded.provider.accountRecordKey == envelope.provider.accountRecordKey)
            #expect(decoded.provider.accountLabel == envelope.provider.accountLabel)
            #expect(decoded.provider.costSummary == envelope.provider.costSummary)
        }

        let decodedLegacy = try self.roundTripAsReader(published.legacy)
        let claudes = decodedLegacy.providers.filter { $0.providerID == "claude" }
        #expect(claudes.count == 2)
        let byKey = Dictionary(uniqueKeysWithValues: claudes.compactMap { provider in
            provider.accountRecordKey.map { ($0, provider) }
        })
        #expect(Set(byKey.keys) == [published.aliceKey, published.bobKey])

        // Labels are trimmed on the Mac and survive the wire unchanged.
        #expect(byKey[published.aliceKey]?.accountLabel == "Audi")
        #expect(byKey[published.bobKey]?.accountLabel == "Work")
        #expect(byKey[published.aliceKey]?.accountEmail == "alice@example.com")
        #expect(byKey[published.bobKey]?.accountEmail == "bob@example.com")

        // v0.82 quota metadata and row expiry cross the wire per account.
        for provider in claudes {
            #expect(provider.primary?.quotaLimit == 1000)
            #expect(provider.primary?.quotaUnit == "credits")
            let row = provider.details.first?.rows.first
            #expect(row?.label == "Balance")
            #expect(row?.expiresAt == Self.rowExpiry)
        }
        #expect(byKey[published.aliceKey]?.primary?.usedPercent == 10)
        #expect(byKey[published.bobKey]?.primary?.usedPercent == 60)

        // Provider-level cost is published once, by the active account, not duplicated.
        let costs = claudes.compactMap(\.costSummary)
        #expect(costs.count == 1)
        #expect(costs.first?.last30DaysCostUSD == 31.25)
        #expect(costs.first?.sessionCostUSD == 2.40)
        #expect(byKey[published.aliceKey]?.costSummary?.daily.first?.dayKey == "2026-03-16")
    }

    @Test
    func `Reader ignores unknown extra fields added at every level of a Mac payload`() async throws {
        let published = try await self.publishTwoAccounts()
        let envelope = try #require(published.envelopes.first)
        let data = try CloudSyncConstants.makeJSONEncoder().encode(envelope)
        var root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        root["futureEnvelopeField"] = ["x": 1]
        var provider = try #require(root["provider"] as? [String: Any])
        provider["futureProviderField"] = "experimental"
        provider["futureProviderArray"] = ["a", "b"]
        var primary = try #require(provider["primary"] as? [String: Any])
        primary["futureWindowField"] = 42
        provider["primary"] = primary
        root["provider"] = provider

        let extended = try JSONSerialization.data(withJSONObject: root)
        let decoded = try CloudSyncConstants.makeJSONDecoder().decode(ProviderUsageEnvelope.self, from: extended)
        #expect(decoded.provider == envelope.provider)
        #expect(decoded.provider.accountLabel == envelope.provider.accountLabel)
        #expect(decoded.provider.accountRecordKey == envelope.provider.accountRecordKey)
    }

    @Test
    func `Reader decodes the oldest supported payload shape without v0_82 fields`() throws {
        // Mac on the 1.1.0 era: only primary window, no label/key/cost/quota metadata.
        let legacyJSON = """
        {
            "providers": [{
                "providerID": "claude",
                "providerName": "Claude",
                "isError": false,
                "lastUpdated": "2024-01-01T00:00:00Z",
                "accountEmail": "old@example.com",
                "primary": {
                    "usedPercent": 25.0,
                    "windowMinutes": 300,
                    "resetsAt": "2024-01-01T01:00:00Z",
                    "resetDescription": "in 1 hour"
                }
            }],
            "syncTimestamp": "2024-01-01T00:00:00Z",
            "deviceName": "Old Mac"
        }
        """
        let decoded = try CloudSyncConstants.makeJSONDecoder()
            .decode(SyncedUsageSnapshot.self, from: Data(legacyJSON.utf8))
        let provider = try #require(decoded.providers.first)
        #expect(provider.providerID == "claude")
        #expect(provider.accountEmail == "old@example.com")
        #expect(provider.primary?.usedPercent == 25.0)
        #expect(provider.accountLabel == nil)
        #expect(provider.accountRecordKey == nil)
        #expect(provider.costSummary == nil)
        #expect(provider.primary?.quotaLimit == nil)
        #expect(provider.primary?.quotaUnit == nil)
        #expect(provider.details.isEmpty)
        #expect(decoded.deviceID == nil)
        // The legacy shape must still re-encode and decode to the same value.
        #expect(try self.roundTripAsReader(decoded) == decoded)
    }
}
