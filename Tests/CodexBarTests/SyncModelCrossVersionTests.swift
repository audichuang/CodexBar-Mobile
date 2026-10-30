import CodexBarSync
import Foundation
import Testing

/// Cross-version encode/decode compatibility tests for `ProviderUsageSnapshot`
/// and `SyncedUsageSnapshot`.
///
/// Guards the fork-owned wire field `accountLabel: String?` across version boundaries:
/// 1. Forward compatibility: payloads written by old writers without `accountLabel`
///    decode cleanly with `accountLabel == nil`.
/// 2. Backward compatibility: payloads written by newer writers with `accountLabel`
///    remain decodable by legacy readers that lack the field (extra keys ignored).
/// 3. Envelope compatibility: the same dual-direction guarantees hold for
///    `SyncedUsageSnapshot` containing provider arrays.
/// 4. Sparse emission: encoding a snapshot with `accountLabel == nil` omits the key.
struct SyncModelCrossVersionTests {
    private struct LegacyRateWindow: Decodable {
        let usedPercent: Double
    }

    /// Minimal model of a provider snapshot lacking the fork-only `accountLabel` field,
    /// matching the fields decoded by legacy clients.
    private struct LegacyProvider: Decodable {
        let providerID: String
        let providerName: String
        let primary: LegacyRateWindow?
        let accountEmail: String?
        let isError: Bool
        let lastUpdated: Date
    }

    /// Minimal model of the sync envelope lacking any fork-only extensions.
    private struct LegacySnapshot: Decodable {
        let providers: [LegacyProvider]
        let syncTimestamp: Date
        let deviceName: String
        let deviceID: String?
    }

    private static let encoder = CloudSyncConstants.makeJSONEncoder()
    private static let decoder = CloudSyncConstants.makeJSONDecoder()

    // MARK: - 1. Provider payload without accountLabel decodes as nil

    @Test
    func `Payload without accountLabel decodes with nil accountLabel`() throws {
        let json = """
        {
            "providerID": "claude",
            "providerName": "Claude",
            "isError": false,
            "lastUpdated": "2026-10-30T12:00:00Z"
        }
        """
        let decoded = try Self.decoder.decode(ProviderUsageSnapshot.self, from: Data(json.utf8))
        #expect(decoded.providerID == "claude")
        #expect(decoded.providerName == "Claude")
        #expect(decoded.isError == false)
        #expect(decoded.accountLabel == nil)
    }

    // MARK: - 2. Provider payload with accountLabel decodes on legacy and round-trips on current

    @Test
    func `Provider payload with accountLabel round-trips on current model and decodes on legacy model`() throws {
        let snapshot = ProviderUsageSnapshot(
            providerID: "claude",
            providerName: "Claude",
            primary: nil,
            secondary: nil,
            accountEmail: "audi@example.com",
            loginMethod: nil,
            statusMessage: nil,
            isError: false,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000),
            accountLabel: "Audi")

        let data = try Self.encoder.encode(snapshot)

        let current = try Self.decoder.decode(ProviderUsageSnapshot.self, from: data)
        #expect(current.providerID == "claude")
        #expect(current.providerName == "Claude")
        #expect(current.accountEmail == "audi@example.com")
        #expect(current.accountLabel == "Audi")

        let legacy = try Self.decoder.decode(LegacyProvider.self, from: data)
        #expect(legacy.providerID == "claude")
        #expect(legacy.providerName == "Claude")
        #expect(legacy.accountEmail == "audi@example.com")
        #expect(legacy.isError == false)
        #expect(legacy.primary == nil)
    }

    // MARK: - 3. Envelope level cross-version compatibility

    @Test
    func `Synced envelope payload without accountLabel decodes with nil accountLabel`() throws {
        let json = """
        {
            "providers": [
                {
                    "providerID": "claude",
                    "providerName": "Claude",
                    "isError": false,
                    "lastUpdated": "2026-10-30T12:00:00Z"
                }
            ],
            "syncTimestamp": "2026-10-30T12:00:00Z",
            "deviceName": "MacBook Pro"
        }
        """
        let decoded = try Self.decoder.decode(SyncedUsageSnapshot.self, from: Data(json.utf8))
        #expect(decoded.deviceName == "MacBook Pro")
        #expect(decoded.providers.count == 1)
        #expect(decoded.providers.first?.providerID == "claude")
        #expect(decoded.providers.first?.accountLabel == nil)
    }

    @Test
    func `Synced envelope with accountLabel round-trips on current model and decodes on legacy model`() throws {
        let provider = ProviderUsageSnapshot(
            providerID: "claude",
            providerName: "Claude",
            primary: nil,
            secondary: nil,
            accountEmail: "audi@example.com",
            loginMethod: nil,
            statusMessage: nil,
            isError: false,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000),
            accountLabel: "Audi")
        let snapshot = SyncedUsageSnapshot(
            providers: [provider],
            syncTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName: "MacBook Pro",
            deviceID: "device-audi-1")

        let data = try Self.encoder.encode(snapshot)

        let current = try Self.decoder.decode(SyncedUsageSnapshot.self, from: data)
        #expect(current.deviceName == "MacBook Pro")
        #expect(current.deviceID == "device-audi-1")
        #expect(current.providers.count == 1)
        #expect(current.providers.first?.accountLabel == "Audi")

        let legacy = try Self.decoder.decode(LegacySnapshot.self, from: data)
        #expect(legacy.deviceName == "MacBook Pro")
        #expect(legacy.deviceID == "device-audi-1")
        #expect(legacy.providers.count == 1)
        #expect(legacy.providers.first?.providerID == "claude")
        #expect(legacy.providers.first?.providerName == "Claude")
        #expect(legacy.providers.first?.accountEmail == "audi@example.com")
        #expect(legacy.providers.first?.isError == false)
    }

    // MARK: - 4. Nil key omission

    @Test
    func `Encoding a snapshot with nil accountLabel omits accountLabel key`() throws {
        let snapshot = ProviderUsageSnapshot(
            providerID: "claude",
            providerName: "Claude",
            primary: nil,
            secondary: nil,
            accountEmail: "audi@example.com",
            loginMethod: nil,
            statusMessage: nil,
            isError: false,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000),
            accountLabel: nil)

        let data = try Self.encoder.encode(snapshot)
        let jsonObject = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(jsonObject["accountLabel"] == nil)
    }
}
