import CodexBarSync
import Foundation
import Testing

struct V082SyncMetadataTests {
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
