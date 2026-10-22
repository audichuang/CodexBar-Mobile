import CodexBarSync
import Foundation
import Testing
@testable import CodexBar
@testable import CodexBarCore

@MainActor
struct SyncV079BridgeTests {
    @Test(arguments: BundledPluginTestSupport.engines)
    func `Gemini app plugin labels survive sync while CLI model labels stay unchanged`(
        engine: ProviderPluginEngineKind) async throws
    {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }
        let settings = testSettingsStore(
            suiteName: "SyncV079BridgeTests-gemini-\(engine)",
            userDefaults: InMemoryUserDefaults(),
            config: testConfigWithAllProvidersDisabled(),
            keychainAccessPolicy: .init(setDisabled: { _ in }, isExplicitlyDisabled: { false }))
        enableTestProviders([.gemini], settings: settings)
        settings.iCloudSyncEnabled = true
        let store = UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings,
            startupBehavior: .testing,
            environmentBase: ["HOME": env.root.path],
            widgetSnapshotURL: env.root.appendingPathComponent("widget.json"),
            widgetTimelineReloader: {})
        let pusher = MockSyncPusher()
        let sync = SyncCoordinator(store: store, settings: settings, syncManager: pusher, deviceID: "MAC-A")
        store._setSnapshotForTesting(UsageSnapshot(
            primary: RateWindow(usedPercent: 10, windowMinutes: 1440, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            updatedAt: Date()), provider: .gemini)
        await sync.pushCurrentSnapshot()
        #expect(pusher.lastSnapshot?.providers.first { $0.providerID == "gemini" }?.accountRecordKey == nil)
        #expect(pusher.deletedRecordNamesAcrossCalls.isEmpty)
        settings.updateProviderConfig(provider: .gemini) { $0.source = .web }
        let hourly = #"{"poolType":"GXU_FIVE_HOURLY","percentageUsed":0.24}"#
        let weekly = #"{"poolType":"GXU_WEEKLY","percentageUsed":0.04}"#
        for (pools, expected, usedPercent) in [
            ([hourly, weekly], ["5-hour", "Weekly"], 24.0),
            ([hourly], ["5-hour"], 24.0),
            ([weekly], ["Weekly"], 4.0),
        ] {
            let body = "[{\"data\":{\"viewer\":{\"rpcs\":{\"getUsageInfo\":{\"pools\":["
                + pools.joined(separator: ",") + "]}}}}}]"
            let runtime = try BundledPluginTestSupport.runtime(
                "gemini-web", engine: engine, transport: ProviderHTTPTransportHandler { request in
                    #expect(request.url?.host == "gemini.google.com")
                    return try CookiePluginFixtures.response(request, body: body)
                })
            let snapshot = try await runtime.fetchUsage(
                cookieSource: .manual, cookieResolver: { _, _ in "SID=fixture" })
            #expect([snapshot.primary?.label, snapshot.secondary?.label].compactMap(\.self) == expected)
            store._setSnapshotForTesting(snapshot, provider: .gemini)
            await sync.pushCurrentSnapshot()
            let published = try #require(pusher.lastSnapshot?.providers.first { $0.providerID == "gemini" })
            #expect(published.rateWindows.compactMap(\.label) == expected)
            #expect(published.rateWindows.first?.usedPercent == usedPercent)
            #expect(published.accountRecordKey == "web-device-mac-a")
            #expect(pusher.deletedRecordNamesAcrossCalls.flatMap(\.self).contains { $0.hasSuffix("|gemini|_") })
            #expect(published.accountIdentities == ["gemini:record:web-device-mac-a"])
            let data = try CloudSyncConstants.makeJSONEncoder().encode(published)
            let decoded = try CloudSyncConstants.makeJSONDecoder().decode(ProviderUsageSnapshot.self, from: data)
            #expect(decoded.rateWindows.compactMap(\.label) == expected)
            let otherRuntime = try BundledPluginTestSupport.runtime(
                "gemini-web", engine: engine, transport: ProviderHTTPTransportHandler { request in
                    try CookiePluginFixtures.response(
                        request, body: body.replacingOccurrences(of: "0.24", with: "0.90")
                            .replacingOccurrences(of: "0.04", with: "0.10"))
                })
            let otherSnapshot = try await otherRuntime.fetchUsage(
                cookieSource: .manual, cookieResolver: { _, _ in "SID=other-fixture" })
            store._setSnapshotForTesting(otherSnapshot, provider: .gemini)
            let otherSync = SyncCoordinator(store: store, settings: settings, syncManager: pusher, deviceID: "MAC-B")
            await otherSync.pushCurrentSnapshot()
            let other = try #require(pusher.lastSnapshot?.providers.first { $0.providerID == "gemini" })
            #expect(other.accountRecordKey == "web-device-mac-b")
            #expect(other.accountIdentities == ["gemini:record:web-device-mac-b"])
            #expect(other.accountEmail == nil)
            #expect(other.rateWindows.first?.usedPercent == (usedPercent == 24 ? 90 : 10))
            #expect(other.accountRecordKey != decoded.accountRecordKey)
        }
        settings.updateProviderConfig(provider: .gemini) { $0.source = .api }
        let cliWindow = RateWindow(usedPercent: 10, windowMinutes: 1440, resetsAt: nil, resetDescription: nil)
        store._setSnapshotForTesting(UsageSnapshot(
            primary: cliWindow, secondary: cliWindow, tertiary: cliWindow, updatedAt: Date()), provider: .gemini)
        await sync.pushCurrentSnapshot()
        let cli = try #require(pusher.lastSnapshot?.providers.first { $0.providerID == "gemini" })
        #expect(cli.rateWindows.compactMap(\.label) == ["Pro", "Flash", "Flash Lite"])
        #expect(cli.accountRecordKey == nil)
        #expect(cli.accountIdentities == nil)
        #expect(pusher.deletedRecordNamesAcrossCalls.flatMap(\.self).contains {
            $0.hasSuffix("|gemini|web-device-mac-a")
        })
    }

    @Test
    func `only explicit Gemini web isolates unidentified accounts by device`() {
        let first = SyncCoordinator.syncAccountRecordKey(
            provider: .gemini, requested: nil, deviceID: "MAC-A", sourceMode: .web)
        let second = SyncCoordinator.syncAccountRecordKey(
            provider: .gemini, requested: nil, deviceID: "MAC-B", sourceMode: .web)
        #expect(first == "web-device-mac-a")
        #expect(second == "web-device-mac-b")
        for source in [ProviderSourceMode.auto, .api, .cli] {
            #expect(SyncCoordinator.syncAccountRecordKey(
                provider: .gemini, requested: nil, deviceID: "MAC-A", sourceMode: source) == nil)
        }
        #expect(SyncCoordinator.syncAccountRecordKey(
            provider: .gemini, requested: "configured", deviceID: "MAC-A", sourceMode: .web) == "configured")
    }

    @Test(arguments: [UsageProvider.futureagi, .munito])
    func `new providers retain configured keys and isolate unverified accounts by device`(provider: UsageProvider) {
        let first = SyncCoordinator.syncAccountRecordKey(provider: provider, requested: nil, deviceID: "MAC-A")
        let second = SyncCoordinator.syncAccountRecordKey(provider: provider, requested: nil, deviceID: "MAC-B")
        #expect(first == "device-mac-a")
        #expect(first != second)
        #expect(first == SyncCoordinator.syncAccountRecordKey(provider: provider, requested: nil, deviceID: "MAC-A"))
        #expect(SyncCoordinator.syncAccountRecordKey(
            provider: provider,
            requested: "configured-account",
            deviceID: "MAC-A")
            == "configured-account")
        #expect(SyncCoordinator.syncAccountIdentities(provider: provider, identity: nil, accountRecordKey: first)
            == ["\(provider.rawValue):record:device-mac-a"])
    }

    @Test
    func `Munito groups verified organizations across Macs without grouping different organizations`() throws {
        let org = ProviderIdentitySnapshot(
            providerID: .munito,
            accountEmail: nil,
            accountOrganization: "Editable name",
            loginMethod: nil,
            accountID: "org-A")
        let renamed = ProviderIdentitySnapshot(
            providerID: .munito,
            accountEmail: nil,
            accountOrganization: "Renamed",
            loginMethod: nil,
            accountID: "org-A")
        let other = ProviderIdentitySnapshot(
            providerID: .munito,
            accountEmail: nil,
            accountOrganization: "Editable name",
            loginMethod: nil,
            accountID: "org-B")
        let key = try #require(SyncCoordinator.syncAccountRecordKey(
            provider: .munito, requested: nil, deviceID: "MAC-A", identity: org))
        #expect(key == SyncCoordinator.syncAccountRecordKey(
            provider: .munito, requested: nil, deviceID: "MAC-B", identity: renamed))
        #expect(key != SyncCoordinator.syncAccountRecordKey(
            provider: .munito, requested: nil, deviceID: "MAC-A", identity: other))
        #expect(!key.contains("org-A"))
        #expect(SyncCoordinator.syncAccountIdentities(provider: .munito, identity: org, accountRecordKey: key)
            == ["munito:record:\(key)"])
        #expect(SyncCoordinator.syncAccountRecordKey(
            provider: .munito, requested: "explicit", deviceID: "MAC-A", identity: org) == "explicit")
        let noID = ProviderIdentitySnapshot(
            providerID: .munito,
            accountEmail: nil,
            accountOrganization: "Editable name",
            loginMethod: nil,
            accountID: " ")
        #expect(SyncCoordinator.syncAccountRecordKey(
            provider: .munito, requested: nil, deviceID: "MAC-A", identity: noID) == "device-mac-a")
    }

    @Test
    func `organization identity preserves opaque ID distinctions and canonical Unicode`() {
        func key(_ raw: String) -> String? {
            SyncCoordinator.syncAccountRecordKey(
                provider: .munito,
                requested: nil,
                deviceID: "MAC-A",
                identity: .init(
                    providerID: .munito,
                    accountEmail: nil,
                    accountOrganization: nil,
                    loginMethod: nil,
                    accountID: raw))
        }
        #expect(key("  org-A\n") == key("org-A"))
        #expect(key("org-e\u{301}") == key("org-é"))
        #expect(key("org-A") != key("org-a"))
        let longPrefix = String(repeating: "synthetic-organization-", count: 30)
        #expect(key(longPrefix + "A") != key(longPrefix + "B"))
    }

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
        enableTestProviders([.claude, .munito, .futureagi], settings: settings)
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
        let organization = ProviderIdentitySnapshot(
            providerID: .munito,
            accountEmail: nil,
            accountOrganization: "Fixture organization",
            loginMethod: "Admin API key",
            accountID: "fixture-org")
        let newProviderFixtures: [(UsageProvider, ProviderIdentitySnapshot?)] = [
            (.munito, organization), (.futureagi, nil),
        ]
        for (provider, identity) in newProviderFixtures {
            store._setSnapshotForTesting(
                UsageSnapshot(
                    primary: RateWindow(
                        usedPercent: 15,
                        windowMinutes: 1440,
                        resetsAt: nil,
                        resetDescription: nil),
                    secondary: nil,
                    updatedAt: now,
                    identity: identity),
                provider: provider)
        }
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
        let munito = try #require(pusher.lastSnapshot?.providers.first { $0.providerID == "munito" })
        let expectedOrgKey = SyncCoordinator.syncAccountRecordKey(
            provider: .munito, requested: nil, deviceID: "unused-for-verified-identity", identity: organization)
        #expect(munito.accountRecordKey == expectedOrgKey)
        #expect(munito.accountIdentities == expectedOrgKey.map { ["munito:record:\($0)"] })
        let futureAGI = try #require(pusher.lastSnapshot?.providers.first { $0.providerID == "futureagi" })
        #expect(try futureAGI.accountRecordKey == "device-\(#require(pusher.lastSnapshot?.deviceID).lowercased())")
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
