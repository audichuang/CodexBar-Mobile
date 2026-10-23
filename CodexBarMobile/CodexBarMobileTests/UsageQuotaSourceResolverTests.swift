import CodexBarSync
import Foundation
import Testing
@testable import CodexBarMobile

@Suite("Quota overview original source proof")
@MainActor
struct UsageQuotaSourceResolverTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private static func account(
        used: Double = 20, identity: String = "one", providerID: String = "claude",
        window: SyncRateWindow? = nil, windows: [SyncRateWindow] = [],
        capturedAt: Date = Self.now, isError: Bool = false) -> ProviderUsageSnapshot
    {
        ProviderUsageSnapshot(
            providerID: providerID, providerName: providerID.capitalized, primary: window ?? SyncRateWindow(
                id: "primary", label: "Session", usedPercent: used, windowMinutes: 300,
                resetsAt: self.now.addingTimeInterval(3600), resetDescription: nil),
            secondary: nil, accountEmail: "\(identity)@example.invalid", loginMethod: nil,
            statusMessage: nil, isError: isError, lastUpdated: capturedAt,
            rateWindows: windows, accountIdentities: ["\(providerID):account:\(identity)"],
            accountRecordKey: "reusable-slot")
    }

    private static func snapshot(
        _ account: ProviderUsageSnapshot, device: String = "fictional-mac", capture: Date? = nil) -> SyncedUsageSnapshot
    {
        SyncedUsageSnapshot(
            providers: [account], syncTimestamp: self.now, deviceName: device, deviceID: device,
            providerQuotaSources: capture.map { date in
                [SyncedUsageSnapshot.providerPublicationKey(for: account): SyncProviderQuotaSource(
                    appVersion: "fictional", publicationTimestamp: self.now,
                    deviceID: device, capturedAt: date, isError: false)]
            } ?? [:])
    }

    @Test
    func `original quota capture is independent of source metadata refresh`() throws {
        let account = Self.account()
        let old = Self.now.addingTimeInterval(-7 * 3600)
        let source = Self.snapshot(account, capture: old)
        let store = UsageQuotaOverviewStore.inMemory()
        store.reconcile(accounts: [account], sourceSnapshots: [source], now: Self.now)
        let line = try #require(store.overview(accounts: [account], now: Self.now).lines.first)
        #expect(line.observedAt == old)
        #expect(line.state == .stale)
        #expect(line.currentRemainingPercent == 80)
        #expect(line.observedSamples.isEmpty)
        #expect(line.localObservationCount == 1)
        #expect(store.overview(accounts: [account], now: Self.now).end == Self.now)
    }

    @Test
    func `missing proof refuses sampling and charting instead of trusting a merged account clock`() throws {
        var account = Self.account()
        account.sourceReport = SyncProviderSourceReport(
            sourceDeviceID: "fictional-mac", sourceDeviceName: "Fictional Mac", sourceCapturedAt: Self.now,
            failures: [], deviceCount: 2)
        let store = UsageQuotaOverviewStore.inMemory()
        store.reconcile(accounts: [account], now: Self.now)
        let line = try #require(store.overview(accounts: [account], now: Self.now).lines.first)
        #expect(line.state == .unknown)
        #expect(line.observedAt == nil)
        #expect(line.currentRemainingPercent == nil)
        #expect(line.localObservationCount == 0)
        #expect(line.observedSamples.isEmpty)
        #expect(UsageQuotaSourceResolver.evidence(
            account: Self.account(), windowID: "primary", sourceSnapshots: []) == nil)
        // Physical-device alias collapse is another derived merge, not raw source proof.
        #expect(UsageQuotaSourceResolver.evidence(
            account: account, windowID: "primary", sourceSnapshots: [Self.snapshot(account)]) == nil)
    }

    @Test
    func `conflicting same-time sources and reused record slots never prove a quota`() {
        let account = Self.account()
        let conflict = Self.account(used: 70)
        #expect(UsageQuotaSourceResolver.evidence(
            account: account, windowID: "primary",
            sourceSnapshots: [Self.snapshot(account), Self.snapshot(conflict, device: "fictional-other-mac")]) == nil)
        #expect(UsageQuotaSourceResolver.evidence(
            account: account, windowID: "primary",
            sourceSnapshots: [Self.snapshot(Self.account(identity: "another-account"))]) == nil)
        let identical = UsageQuotaSourceResolver.evidence(
            account: account, windowID: "primary",
            sourceSnapshots: [Self.snapshot(account), Self.snapshot(account, device: "fictional-other-mac")])
        #expect(identical?.window.usedPercent == 20)
        #expect(identical?.capturedAt == Self.now)
    }

    @Test
    func `newer legacy Kimi sources cannot clear the canonical capable writer block`() throws {
        let reset = Self.now.addingTimeInterval(86400)
        let blocked = SyncRateWindow(
            id: "primary", label: "Weekly", usedPercent: 100, windowMinutes: 10080,
            resetsAt: reset, resetDescription: nil,
            blockingQuota: SyncBlockingQuota(
                windowID: "monthly", rawUsedPercent: 25, rawResetsAt: reset,
                rawResetDescription: nil, rawNextRegenPercent: nil))
        let available = SyncRateWindow(
            id: "primary", label: "Weekly", usedPercent: 10, windowMinutes: 10080,
            resetsAt: reset, resetDescription: nil)
        let capable = Self.account(providerID: "kimi", window: blocked, windows: [blocked])
        let legacy = Self.account(
            providerID: "kimi", window: available, windows: [available], capturedAt: Self.now.addingTimeInterval(60))
        let sources = [
            SyncedUsageSnapshot(
                providers: [capable], syncTimestamp: Self.now, deviceName: "Capable", deviceID: "capable",
                appVersion: "0.70.0.1"),
            SyncedUsageSnapshot(
                providers: [legacy], syncTimestamp: legacy.lastUpdated, deviceName: "Legacy", deviceID: "legacy",
                appVersion: "0.68.0.1"),
        ]
        let merged = try #require(ProviderSnapshotMerger.mergeSnapshots(sources))
        let store = UsageQuotaOverviewStore.inMemory()
        let now = Self.now.addingTimeInterval(60)
        store.reconcile(accounts: merged.providers, sourceSnapshots: sources, now: now)
        #expect(try store.add(#require(store.catalog(accounts: merged.providers).first)))
        let overview = store.overview(accounts: merged.providers, now: now)
        let line = try #require(overview.lines.first)
        #expect(line.state == .blocked)
        #expect(line.currentRemainingPercent == nil)
        #expect(line.observedSamples.isEmpty)
        #expect(line.localObservationCount == 0)
        #expect(overview.end == now)
    }

    @Test
    func `raw sources cannot resurrect a removed metric or override canonical unavailability`() throws {
        let extra = SyncRateWindow(
            id: "retired-extra", label: "Fictional extra", usedPercent: 30, windowMinutes: 300,
            resetsAt: Self.now.addingTimeInterval(3600), resetDescription: nil)
        let old = Self.account(providerID: "codex", windows: [extra])
        let current = Self.account(providerID: "codex")
        let store = UsageQuotaOverviewStore.inMemory()
        store.reconcile(accounts: [old], sourceSnapshots: [Self.snapshot(old)], now: Self.now)
        store.reconcile(
            accounts: [current],
            sourceSnapshots: [Self.snapshot(old), Self.snapshot(current)],
            now: Self.now)
        let missing = try #require(store.overview(accounts: [current], now: Self.now).lines.first)
        #expect(missing.state == .missingMetric)
        #expect(missing.observedSamples.isEmpty)
        #expect(missing.currentRemainingPercent == nil)
        let unavailable = Self.account(providerID: "codex", isError: true)
        #expect(UsageQuotaSourceResolver.evidence(
            account: unavailable, windowID: "primary", sourceSnapshots: [Self.snapshot(current)]) == nil)
    }

    @Test
    func `Kimi alias canonical IDs preserve the original capable writer and reject same-clock legacy substitutes`() throws {
        let capture = Self.now.addingTimeInterval(-60)
        let weekly = SyncRateWindow(
            id: "primary", label: "Weekly", usedPercent: 20, windowMinutes: 10080,
            resetsAt: Self.now.addingTimeInterval(86400), resetDescription: nil)
        let monthly = SyncRateWindow(
            id: "kimi-monthly", label: "Monthly", usedPercent: 50, windowMinutes: 43200,
            resetsAt: Self.now.addingTimeInterval(3 * 86400), resetDescription: nil)
        let capable = Self.account(
            providerID: "kimi", window: weekly, windows: [weekly, monthly], capturedAt: capture)
        // Its legacy sibling happens to report exactly the same window values and capture.
        // Newer account metadata must not grant that old writer the capable writer's authority.
        let legacy = Self.account(
            providerID: "kimi", window: weekly, windows: [weekly, monthly], capturedAt: Self.now)
        func source(_ account: ProviderUsageSnapshot, id: String, version: String) -> SyncedUsageSnapshot {
            SyncedUsageSnapshot(
                providers: [account], syncTimestamp: account.lastUpdated, deviceName: id, deviceID: id,
                appVersion: version,
                providerQuotaSources: [SyncedUsageSnapshot
                    .providerPublicationKey(for: account): SyncProviderQuotaSource(
                        appVersion: version,
                        publicationTimestamp: account.lastUpdated,
                        deviceID: id,
                        capturedAt: capture,
                        isError: false)])
        }
        let oldAlias = source(capable, id: "fictional-original-alias", version: "0.70.0.1")
        let newAlias = source(legacy, id: "fictional-current-alias", version: "0.68.0.1")
        let raw = [oldAlias, newAlias]
        let lifecycle = DeviceLifecycleEvent(
            kind: .alias, primaryDeviceID: "fictional-original-alias", relatedDeviceIDs: ["fictional-current-alias"],
            confirmedFromDeviceID: "fictional-phone")
        let resolution = DeviceSnapshotResolver.resolveDeviceSnapshots(raw, lifecycleEvents: [lifecycle])
        #expect(resolution.activeSnapshots.count == 1)
        let merged = try #require(ProviderSnapshotMerger.mergeSnapshots(resolution.activeSnapshots))
        let account = try #require(merged.providers.first)
        let key = SyncedUsageSnapshot.providerPublicationKey(for: account)
        #expect(account.sourceReport?.sourceDeviceID == "fictional-current-alias")
        #expect(merged.providerQuotaSources[key]?.deviceID == "fictional-original-alias")
        #expect(account.sourceReport?.sourceCapturedAt == capture)

        let store = UsageQuotaOverviewStore.inMemory()
        store.reconcile(
            accounts: merged.providers, sourceSnapshots: raw, quotaSources: merged.providerQuotaSources, now: Self.now)
        let line = try #require(store.overview(accounts: merged.providers, now: Self.now).lines.first {
            $0.selection.windowID == "primary"
        })
        #expect(line.state == .available)
        #expect(line.currentRemainingPercent == 80)
        #expect(line.observedAt == capture)
        #expect(line.observedSamples.count == 1)
        #expect(line.observedSamples.first?.remainingPercent == 80)
        #expect(line.localObservationCount == 1)
        // Clock/window equality alone is insufficient: the original selected writer is absent.
        #expect(UsageQuotaSourceResolver.evidence(
            account: account, windowID: "primary", sourceSnapshots: [newAlias],
            quotaSources: merged.providerQuotaSources) == nil)
        #expect(UsageQuotaSourceResolver.evidence(
            account: account, windowID: "primary", sourceSnapshots: raw, quotaSources: [:]) == nil)
        let missingSource = try #require(store.overview(
            accounts: merged.providers, sourceSnapshots: [newAlias], quotaSources: merged.providerQuotaSources,
            now: Self.now).lines.first { $0.selection.windowID == "primary" })
        #expect(missingSource.state == .unknown)
        #expect(missingSource.observedSamples.isEmpty)
    }
}
