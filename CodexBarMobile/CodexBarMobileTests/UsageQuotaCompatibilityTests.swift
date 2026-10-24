import CodexBarSync
import Foundation
import Testing
@testable import CodexBarMobile

/// Fixture/cache substitutes, not executions of four physical devices or the old app binary.
/// The frozen DTO below covers only the fields exercised here, verified against build 250's
/// Shared/Models/UsageSnapshot.swift at d90e42daef7f54611c7fba7c043452b7125f7436.
@Suite("Usage quota old/current wire and independent reader compatibility")
@MainActor
struct UsageQuotaCompatibilityTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    struct Combination: Sendable, CustomTestStringConvertible {
        let mask: Int
        var macANew: Bool {
            self.mask & 8 != 0
        }

        var macBNew: Bool {
            self.mask & 4 != 0
        }

        var phoneANew: Bool {
            self.mask & 2 != 0
        }

        var phoneBNew: Bool {
            self.mask & 1 != 0
        }

        var testDescription: String {
            "case \(self.mask + 1): Mac \(self.macANew ? "new" : "old")/\(self.macBNew ? "new" : "old"), "
                + "iPhone \(self.phoneANew ? "new" : "old")/\(self.phoneBNew ? "new" : "old")"
        }
    }

    @Test(arguments: (0..<16).map { Combination(mask: $0) })
    func `two writers converge through independent full and cold delta readers without sharing preferences`(
        combination: Combination) throws
    {
        let wires = try [
            Self.writer(device: "fictional-mac-a", modern: combination.macANew, newer: false),
            Self.writer(device: "fictional-mac-b", modern: combination.macBNew, newer: true),
        ]
        let phoneA = try Reader(modern: combination.phoneANew)
        let phoneB = try Reader(modern: combination.phoneBNew)
        let readers = [phoneA, phoneB]
        let snapshotsA = try wires.map { try phoneA.decode($0) }
        let snapshotsB = try wires.map { try phoneB.decode($0) }
        let coldRows = try [
            Self.writer(device: "fictional-mac-a", modern: false, newer: false, cold: true),
            Self.writer(device: "fictional-mac-b", modern: false, newer: true, cold: true),
        ].map { try phoneB.decode($0) }

        phoneA.cache.replaceFromFullFetch(perProviderSnapshots: snapshotsA, legacySnapshots: coldRows)
        phoneB.cache.seedFromColdStart(coldRows)
        #expect(phoneB.cache.perProviderByDevice.isEmpty)
        #expect(phoneB.cache.legacyByDevice.count == 2)
        // Opposite receipt order exercises publication/identity merge rather than array position.
        phoneB.cache.applyDelta(upserted: snapshotsB.reversed().flatMap(Self.envelopes), deletedRecordNames: [])

        for reader in readers {
            let providers = try reader.mergedProviders()
            try Self.expectLatestQuotas(providers)
            let oppositeOrder = try #require(ProviderSnapshotMerger.mergeSnapshots(
                Array(reader.cache.buildDeviceSnapshots().reversed())))
            try Self.expectLatestQuotas(oppositeOrder.providers)
            reader.reconcile(providers)
            try reader.expectSingleOwnedObservationPerAccount()
            reader.cache.replaceFromFullFetch(perProviderSnapshots: nil, legacySnapshots: nil)
            try Self.expectLatestQuotas(reader.mergedProviders())
        }

        let untouchedPhoneB = phoneB.disk.values
        if let quota = phoneA.quota {
            var selection = try #require(quota.preferences.selections.first)
            selection.colorHex = "123ABC"
            #expect(quota.update(selection))
            quota.reorder(ids: quota.preferences.selections.reversed().map(\.id))
            let restarted = UsageQuotaOverviewStore(persistence: phoneA.persistence)
            #expect(restarted.preferences == quota.preferences)
            try restarted.reconcile(
                accounts: phoneA.mergedProviders(), sourceSnapshots: phoneA.cache.buildDeviceSnapshots(),
                quotaSources: phoneA.quotaSources, now: Self.now)
            #expect(restarted.preferences == quota.preferences)
            #expect(!restarted.isReadOnly)
        }
        #expect(phoneB.disk.values == untouchedPhoneB)

        for reader in readers {
            let beforeRefresh = reader.quota?.preferences
            // A duplicate full refresh must not import the provider-shared history or resample
            // the same capture. It also must not change a user's selection IDs or colours.
            let snapshots = try wires.map { try reader.decode($0) }
            reader.cache.replaceFromFullFetch(perProviderSnapshots: snapshots, legacySnapshots: [])
            try reader.reconcile(reader.mergedProviders())
            #expect(reader.quota?.preferences == beforeRefresh)
            try reader.expectSingleOwnedObservationPerAccount()

            // Removing the freshest writer reveals the other writer, not a copied history.
            let recordsB = try #require(snapshots.last).providers.map {
                "fictional-mac-b|" + SnapshotCache.compositeKey(for: $0)
            }
            reader.cache.applyDelta(upserted: [], deletedRecordNames: recordsB)
            let fallback = try reader.mergedProviders()
            #expect(fallback.count == 2)
            #expect(fallback.first { $0.accountEmail == "fictional-one@example.invalid" }?.primary?.usedPercent == 30)
            #expect(fallback.first { $0.accountEmail == "fictional-two@example.invalid" }?.primary?.usedPercent == 55)
            reader.reconcile(fallback)
            try reader.expectSingleOwnedObservationPerAccount()

            // Authoritative empty and restore keep local bindings while all remote rows are gone.
            reader.cache.replaceFromFullFetch(perProviderSnapshots: [], legacySnapshots: [])
            #expect(reader.cache.buildDeviceSnapshots().isEmpty)
            reader.reconcile([])
            #expect(reader.quota?.preferences.selections == beforeRefresh?.selections)
            if let quota = reader.quota {
                #expect(quota.overview(
                    accounts: [], sourceSnapshots: reader.cache.buildDeviceSnapshots(),
                    quotaSources: reader.quotaSources,
                    now: Self.now)
                    .lines.allSatisfy { $0.provider == nil })
            }
            reader.cache.applyDelta(upserted: snapshots.flatMap(Self.envelopes), deletedRecordNames: [])
            let restored = try reader.mergedProviders()
            try Self.expectLatestQuotas(restored)
            reader.reconcile(restored)
            #expect(reader.quota?.preferences.selections == beforeRefresh?.selections)
            try reader.expectSingleOwnedObservationPerAccount()
            try reader.expectLegacyPreferencesUntouched()
        }

        // The local graph archive never becomes part of either Mac's wire payload.
        for wire in wires {
            let object = try #require(JSONSerialization.jsonObject(with: wire) as? [String: Any])
            #expect(object[UsageQuotaDefaultsPersistence.key] == nil)
            #expect(object["histories"] == nil)
            #expect(object["selections"] == nil)
        }
    }

    @Test
    func `an inherited extra window keeps its own old capture while a newer legacy writer refreshes native quota`() throws {
        let reader = try Reader(modern: true)
        let oldCapture = Self.now.addingTimeInterval(-7 * 3600)
        let old = try reader.decode(Self.writer(
            device: "fictional-mac-a", modern: true, newer: false,
            observationAt: oldCapture, includesExtra: true))
        let recent = try reader.decode(Self.writer(device: "fictional-mac-b", modern: false, newer: true))
        reader.cache.replaceFromFullFetch(perProviderSnapshots: [old, recent], legacySnapshots: [])
        let providers = try reader.mergedProviders()
        let quota = try #require(reader.quota)
        reader.reconcile(providers)
        let extra = try #require(quota.catalog(accounts: providers).first {
            $0.windowID == "claude-weekly-scoped-fictional"
        })
        // Exercise an explicit user selection independently of the first-run seed policy.
        for selection in quota.preferences.selections where selection.binding == extra.id {
            quota.remove(id: selection.id)
        }
        #expect(quota.add(extra))
        #expect(quota.preferences.selections.filter { $0.binding == extra.id }.count == 1)

        func checkSources() throws {
            let overview = try quota.overview(
                accounts: reader.mergedProviders(), sourceSnapshots: reader.cache.buildDeviceSnapshots(),
                quotaSources: reader.quotaSources, now: Self.now)
            let native = try #require(overview.lines.first {
                $0.selection.accountAnchorID == extra.accountAnchorID && $0.selection.windowID == "primary"
            })
            let inherited = try #require(overview.lines.first { $0.selection.windowID == extra.windowID })
            #expect(native.currentRemainingPercent == 60)
            #expect(inherited.currentRemainingPercent == 30)
            #expect(inherited.observedAt == oldCapture)
            #expect(inherited.state == .stale)
            #expect(inherited.observedSamples.isEmpty)
            #expect(overview.end == Self.now.addingTimeInterval(3600))
            let archive = try JSONDecoder().decode(UsageQuotaArchive.self, from: #require(reader.persistence.load()))
            let observations = try #require(archive.histories.first { $0.binding == extra.id }).observations
            #expect(observations.count == 1)
            #expect(observations.first?.capturedAt == oldCapture)
            #expect(observations.first?.usedPercent == 70)
        }

        try checkSources()
        let refreshed = try reader.decode(Self.writer(
            device: "fictional-mac-b", modern: false, newer: true, observationAt: Self.now))
        reader.cache.applyDelta(upserted: Self.envelopes(refreshed), deletedRecordNames: [])
        try reader.reconcile(reader.mergedProviders())
        try checkSources()
    }

    private static func expectLatestQuotas(_ providers: [ProviderUsageSnapshot]) throws {
        #expect(providers.count == 2)
        let one = try #require(providers.first { $0.accountEmail == "fictional-one@example.invalid" })
        let two = try #require(providers.first { $0.accountEmail == "fictional-two@example.invalid" })
        #expect(one.primary?.usedPercent == 40)
        #expect(two.primary?.usedPercent == 60)
        #expect(SummaryCardResolver.quotaCapturedAt(one) == Self.now.addingTimeInterval(-60))
        #expect(SummaryCardResolver.quotaCapturedAt(two) == Self.now.addingTimeInterval(-60))
    }

    private static func envelopes(_ snapshot: SyncedUsageSnapshot) -> [ProviderUsageEnvelope] {
        snapshot.providers.map {
            ProviderUsageEnvelope(
                deviceID: snapshot.deviceID ?? "", deviceName: snapshot.deviceName,
                appVersion: snapshot.appVersion, mobileVersion: snapshot.mobileVersion,
                syncTimestamp: snapshot.syncTimestamp, notificationPushEnabled: snapshot.notificationPushEnabled,
                provider: $0)
        }
    }

    private static func writer(
        device: String, modern: Bool, newer: Bool, cold: Bool = false,
        observationAt: Date? = nil, includesExtra: Bool = false) throws -> Data
    {
        let captured = observationAt ?? Self.now.addingTimeInterval(cold ? -1800 : newer ? -60 : -300)
        let providers = (1...2).map { index in
            let used: Double = cold ? 5 : index == 1 ? (newer ? 40 : 30) : (newer ? 60 : 55)
            let reset = Self.now.addingTimeInterval(Double(index) * 3600)
            let window = SyncRateWindow(
                id: modern ? "primary" : nil, label: modern ? "Weekly" : nil,
                usedPercent: used, windowMinutes: 10080, period: modern ? .weekly : nil,
                resetsAt: reset, resetDescription: nil)
            let email = index == 1 ? "fictional-one@example.invalid" : "fictional-two@example.invalid"
            let extra = SyncRateWindow(
                id: "claude-weekly-scoped-fictional", label: "Fictional only", usedPercent: 70,
                windowMinutes: 10080, period: .weekly, resetsAt: Self.now.addingTimeInterval(3 * 86400),
                resetDescription: nil)
            return ProviderUsageSnapshot(
                providerID: "claude", providerName: "Claude", primary: window, secondary: nil,
                accountEmail: email, loginMethod: "Max 5x", statusMessage: nil, isError: false,
                lastUpdated: captured,
                rateWindows: modern ? [window] + (includesExtra && index == 1 ? [extra] : []) : [],
                // Intentionally the SAME provider-level series on both accounts. It must not
                // become either account's locally owned observation history.
                utilizationHistory: [.init(name: "Weekly", windowMinutes: 10080, entries: [
                    .init(capturedAt: captured.addingTimeInterval(-1200), usedPercent: 1, resetsAt: reset),
                    .init(capturedAt: captured.addingTimeInterval(-600), usedPercent: 99, resetsAt: reset),
                ])],
                accountIdentities: ["claude:account:fictional-\(index)"],
                accountRecordKey: "\(device)-slot-\(index)")
        }
        let snapshot = SyncedUsageSnapshot(
            providers: providers, syncTimestamp: captured.addingTimeInterval(10),
            deviceName: device, deviceID: device, appVersion: "0.79.0",
            mobileVersion: "3.2.0", notificationPushEnabled: true)
        let data = try CloudSyncConstants.makeJSONEncoder().encode(snapshot)
        if modern { return data }
        // An older-shape writer serializes only the frozen quota fields, with optional ID,
        // label, period and dynamic windows absent. This is a fixture, not an old Mac build.
        let frozen = try CloudSyncConstants.makeJSONDecoder().decode(Build250Snapshot.self, from: data)
        return try CloudSyncConstants.makeJSONEncoder().encode(frozen)
    }

    @MainActor
    private final class Reader {
        let modern: Bool
        var cache = SnapshotCache()
        let disk = DictionaryDisk()
        let persistence: DictionaryQuotaPersistence
        let quota: UsageQuotaOverviewStore?
        private let legacyBytes: [String: Data]

        init(modern: Bool) throws {
            self.modern = modern
            self.legacyBytes = try [
                UsageCardPreferencesStore.defaultsKey: JSONEncoder().encode(UsageCardPreferences()),
                SummaryDefaultsPersistence.key: JSONEncoder().encode(SummaryPreferences()),
            ]
            self.disk.values = self.legacyBytes
            self.persistence = DictionaryQuotaPersistence(disk: self.disk)
            self.quota = modern ? UsageQuotaOverviewStore(persistence: self.persistence) : nil
        }

        func decode(_ wire: Data) throws -> SyncedUsageSnapshot {
            if self.modern {
                return try CloudSyncConstants.makeJSONDecoder().decode(SyncedUsageSnapshot.self, from: wire)
            }
            // Narrow old-reader substitute: retain the build-250 field projection, then feed
            // the unchanged current pure cache/merge seam. Not the build-250 app runtime.
            let frozen = try CloudSyncConstants.makeJSONDecoder().decode(Build250Snapshot.self, from: wire)
            let projected = try CloudSyncConstants.makeJSONEncoder().encode(frozen)
            return try CloudSyncConstants.makeJSONDecoder().decode(SyncedUsageSnapshot.self, from: projected)
        }

        func mergedProviders() throws -> [ProviderUsageSnapshot] {
            try #require(ProviderSnapshotMerger.mergeSnapshots(self.cache.buildDeviceSnapshots())).providers
        }

        var quotaSources: [String: SyncProviderQuotaSource] {
            ProviderSnapshotMerger.mergeSnapshots(self.cache.buildDeviceSnapshots())?.providerQuotaSources ?? [:]
        }

        func reconcile(_ providers: [ProviderUsageSnapshot]) {
            self.quota?.reconcile(
                accounts: providers, sourceSnapshots: self.cache.buildDeviceSnapshots(),
                quotaSources: self.quotaSources,
                now: UsageQuotaCompatibilityTests.now)
        }

        func expectSingleOwnedObservationPerAccount() throws {
            guard let quota = self.quota else {
                #expect(self.disk.values[UsageQuotaDefaultsPersistence.key] == nil)
                return
            }
            let data = try #require(self.persistence.load())
            let archive = try JSONDecoder().decode(UsageQuotaArchive.self, from: data)
            #expect(archive.histories.count == 2)
            #expect(archive.histories.allSatisfy { $0.observations.count == 1 })
            #expect(Set(archive.histories.map(\.binding.accountAnchorID)).count == 2)
            #expect(Set(archive.histories.compactMap { $0.observations.last?.usedPercent }) == [40, 60])
            #expect(archive.histories.allSatisfy {
                $0.observations.last?.capturedAt == UsageQuotaCompatibilityTests.now.addingTimeInterval(-60)
            })
            #expect(quota.preferences.selections.count == 2)
        }

        func expectLegacyPreferencesUntouched() throws {
            #expect(UsageQuotaDefaultsPersistence.key != UsageCardPreferencesStore.defaultsKey)
            #expect(UsageQuotaDefaultsPersistence.key != SummaryDefaultsPersistence.key)
            for (key, bytes) in self.legacyBytes {
                #expect(self.disk.values[key] == bytes)
            }
            let usage = try #require(self.disk.values[UsageCardPreferencesStore.defaultsKey])
            let summary = try #require(self.disk.values[SummaryDefaultsPersistence.key])
            #expect(try JSONDecoder().decode(UsageCardPreferences.self, from: usage) == UsageCardPreferences())
            #expect(try JSONDecoder().decode(SummaryPreferences.self, from: summary) == SummaryPreferences())
            #expect(Set(self.disk.values.keys)
                .isSubset(of: Set(self.legacyBytes.keys).union([UsageQuotaDefaultsPersistence.key])))
        }
    }

    @MainActor
    private final class DictionaryDisk {
        var values: [String: Data] = [:]
    }

    @MainActor
    private struct DictionaryQuotaPersistence: UsageQuotaPersistence {
        let disk: DictionaryDisk
        func load() -> Data? { self.disk.values[UsageQuotaDefaultsPersistence.key] }
        func save(_ data: Data) { self.disk.values[UsageQuotaDefaultsPersistence.key] = data }
    }

    @Test
    func `build 252 local archive readers ignore new continuity metadata and current readers accept their roundtrip`() throws {
        let reader = try Reader(modern: true)
        let snapshot = try reader.decode(Self.writer(device: "fictional-mac", modern: true, newer: true))
        reader.cache.replaceFromFullFetch(perProviderSnapshots: [snapshot], legacySnapshots: [])
        try reader.reconcile(reader.mergedProviders())
        let currentData = try #require(reader.persistence.load())
        let current = try JSONDecoder().decode(UsageQuotaArchive.self, from: currentData)
        #expect(!current.histories.isEmpty)
        #expect(current.histories.flatMap(\.observations).contains { $0.startsSegment != nil })
        let old = try JSONDecoder().decode(Build252QuotaArchive.self, from: currentData)
        let oldData = try JSONEncoder().encode(old)
        let roundtrip = try JSONDecoder().decode(UsageQuotaArchive.self, from: oldData)
        #expect(roundtrip.preferences == current.preferences)
        #expect(roundtrip.histories.flatMap(\.observations).allSatisfy { $0.startsSegment == nil })
        #expect(try JSONDecoder().decode(
            Build252QuotaArchive.self,
            from: JSONEncoder().encode(roundtrip)) == old)
        reader.persistence.save(oldData)
        let reopened = UsageQuotaOverviewStore(persistence: reader.persistence)
        #expect(!reopened.isReadOnly)
        #expect(reopened.preferences == current.preferences)
    }

    /// Frozen local v1 observation fields from 252 (14a191367). Unchanged preferences
    /// and binding types are shared; this is a decoding substitute, not an old binary run.
    private struct Build252QuotaArchive: Codable, Equatable {
        let preferences: UsageQuotaPreferences
        let histories: [Build252QuotaHistory]
    }

    private struct Build252QuotaHistory: Codable, Equatable {
        let binding: UsageQuotaBinding
        let observations: [Build252QuotaObservation]
        let stableAccountTokens: [String]?
    }

    private struct Build252QuotaObservation: Codable, Equatable {
        let capturedAt: Date
        let usedPercent: Double
        let resetDate: Date
        let windowDuration: TimeInterval?
    }

    private struct Build250Snapshot: Codable {
        let providers: [Build250Provider]
        let syncTimestamp: Date
        let deviceName: String
        let deviceID: String?
        let appVersion: String?
        let mobileVersion: String?
        let notificationPushEnabled: Bool?
    }

    private struct Build250Provider: Codable {
        let providerID: String
        let providerName: String
        let primary: Build250Window?
        let secondary: Build250Window?
        let accountEmail: String?
        let loginMethod: String?
        let isError: Bool
        let lastUpdated: Date
        let rateWindows: [Build250Window]?
        let utilizationHistory: [Build250History]?
        let accountIdentities: [String]?
        let accountRecordKey: String?
    }

    private struct Build250Window: Codable {
        let id: String?
        let label: String?
        let usedPercent: Double
        let usageKnown: Bool?
        let windowMinutes: Int?
        let period: String?
        let resetsAt: Date?
    }

    private struct Build250History: Codable {
        let name: String
        let windowMinutes: Int
        let entries: [Build250Entry]
    }

    private struct Build250Entry: Codable {
        let capturedAt: Date
        let usedPercent: Double
        let resetsAt: Date?
    }
}
