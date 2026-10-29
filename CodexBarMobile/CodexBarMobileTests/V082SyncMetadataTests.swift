import CodexBarSync
import Foundation
import Testing
@testable import CodexBarMobile

struct V082SyncMetadataTests {
    @Test(arguments: [
        SyncCostProvenance.listPriceEstimate, .vendorMetered, .mixed, .unknown, .sourceRecorded,
    ])
    func `Two Mac cost merge preserves source recorded meaning in both orders`(other: SyncCostProvenance) throws {
        let now = Date(timeIntervalSince1970: 1_793_174_400)
        func source(_ device: String, provenance: SyncCostProvenance) -> SyncedUsageSnapshot {
            let cost = SyncCostSummary(
                sessionCostUSD: 0,
                sessionTokens: nil,
                last30DaysCostUSD: 0,
                last30DaysTokens: nil,
                daily: [],
                historyDays: 30,
                currencyCode: "USD",
                costProvenance: provenance)
            let provider = ProviderUsageSnapshot(
                providerID: "claude",
                providerName: "Claude",
                primary: nil,
                secondary: nil,
                accountEmail: "provenance@example.invalid",
                loginMethod: nil,
                statusMessage: nil,
                isError: false,
                lastUpdated: now,
                costSummary: cost)
            return SyncedUsageSnapshot(
                providers: [provider], syncTimestamp: now, deviceName: device, deviceID: device)
        }
        let a = source("Synthetic Mac A", provenance: .sourceRecorded)
        let b = source("Synthetic Mac B", provenance: other)
        for values in [[a, b], [b, a]] {
            let merged = try #require(CloudSyncReader.mergeSnapshots(values))
            #expect(merged.providers.count == 1)
            let cost = try #require(merged.providers.first?.costSummary)
            #expect(cost.reportingPeriodCostProvenance == (other == .unknown ? .unknown : .sourceRecorded))
            #expect(cost.last30DaysCostUSD == 0)
        }
    }

    @Test func `Missing or malformed optional expiry preserves a readable detail row`() throws {
        for suffix in ["", ",\"expiresAt\":\"bad date\"", ",\"expiresAt\":{}"] {
            let data = Data("{\"label\":\"Bonus\",\"value\":\"75% left\"\(suffix)}".utf8)
            let row = try CloudSyncConstants.makeJSONDecoder().decode(SyncProviderDetailSection.Row.self, from: data)
            #expect(row.value == "75% left")
            #expect(row.expiresAt == nil)
        }
    }

    @Test func `Old quota payload decodes without inventing an absolute allowance`() throws {
        let data = Data(#"{"usedPercent":20,"windowMinutes":43200}"#.utf8)
        let window = try JSONDecoder().decode(SyncRateWindow.self, from: data)
        #expect(window.quotaLimit == nil)
        #expect(window.quotaUnit == nil)
    }

    @Test func `Malformed optional allowance metadata leaves valid quota usage readable`() throws {
        let data = Data(#"{"usedPercent":20,"quotaLimit":"unknown","quotaUnit":42}"#.utf8)
        let window = try JSONDecoder().decode(SyncRateWindow.self, from: data)
        #expect(window.usedPercent == 20)
        #expect(window.quotaLimit == nil)
        #expect(window.quotaUnit == nil)
    }

    @Test func `Invalid optional pace never erases a valid detail progress ratio`() throws {
        for value in [#""unknown""#, "-1", "101"] {
            let json = "{\"used\":40,\"total\":100,\"expectedUsed\":\(value)}"
            let progress = try JSONDecoder().decode(
                SyncProviderDetailSection.Row.Progress.self, from: Data(json.utf8))
            #expect(progress.used == 40)
            #expect(progress.total == 100)
            #expect(progress.expectedUsed == nil)
        }
    }

    @Test func `Expected usage round trips as optional metadata`() throws {
        let original = try #require(SyncProviderDetailSection.Row.Progress(used: 40, total: 100, expectedUsed: 30))
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(SyncProviderDetailSection.Row.Progress.self, from: data) == original)
        let legacy = try JSONDecoder().decode(
            SyncProviderDetailSection.Row.Progress.self, from: Data(#"{"used":40,"total":100}"#.utf8))
        #expect(legacy.expectedUsed == nil)
    }
}
