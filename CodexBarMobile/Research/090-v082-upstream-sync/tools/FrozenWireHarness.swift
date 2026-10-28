import Foundation

/// Frozen production model/consumer sources execute in separate writer and reader processes.
/// This is offline wire/merge evidence, not CloudKit, SwiftData, APNs or physical-device proof.
@main
struct Harness {
    static let now = Date(timeIntervalSince1970: 1_793_174_400)
    static let additions = ["soniox", "traecn", "abliteration", "chatbox"]
    static let ids = ["claude", "plugin:fixture"] + additions

    static func provider(_ id: String, new: Bool, device: String) -> ProviderUsageSnapshot? {
        if additions.contains(id), !new { return nil }
        let window: SyncRateWindow
        let progress: SyncProviderDetailSection.Row.Progress?
        #if NEW_WIRE
        window = SyncRateWindow(
            id: "monthly", label: "Monthly", usedPercent: 30,
            windowMinutes: 43200, period: .monthly,
            resetsAt: now.addingTimeInterval(86400 * 4), resetDescription: nil,
            quotaLimit: 1000, quotaUnit: "credits")
        progress = .init(used: 30, total: 100, expectedUsed: 25)
        #else
        window = SyncRateWindow(
            id: "monthly", label: "Monthly", usedPercent: 30,
            windowMinutes: 43200, period: .monthly,
            resetsAt: now.addingTimeInterval(86400 * 4), resetDescription: nil)
        progress = .init(used: 30, total: 100)
        #endif
        let row: SyncProviderDetailSection.Row
        #if NEW_WIRE
        row = .init(
            label: "Usage", value: "30 / 100", progress: progress, severity: .warning,
            expiresAt: now.addingTimeInterval(60))
        #else
        row = .init(label: "Usage", value: "30 / 100", progress: progress, severity: .warning)
        #endif
        return ProviderUsageSnapshot(
            providerID: id, providerName: id, primary: window, secondary: nil,
            accountEmail: nil, loginMethod: nil, statusMessage: nil, isError: false,
            lastUpdated: now.addingTimeInterval(device == "mac-b" ? 1 : 0),
            rateWindows: [window],
            accountIdentities: id == "claude" ? ["claude:email:fixture@example.invalid"] : nil,
            accountRecordKey: additions.contains(id) ? "device-" + device : nil,
            details: [.init(title: "Quota", rows: [
                row,
            ])])
    }

    static func envelopes(_ directory: String) throws -> [ProviderUsageEnvelope] {
        try ids.compactMap { id in
            let path = URL(fileURLWithPath: directory).appendingPathComponent(id + ".json")
            guard FileManager.default.fileExists(atPath: path.path) else { return nil }
            let data = try Data(contentsOf: path)
            let value = try CloudSyncConstants.makeJSONDecoder().decode(ProviderUsageEnvelope.self, from: data)
            let roundtrip = try CloudSyncConstants.makeJSONEncoder().encode(value)
            let restored = try CloudSyncConstants.makeJSONDecoder().decode(ProviderUsageEnvelope.self, from: roundtrip)
            precondition(restored == value)
            precondition(value.provider.primary?.usedPercent == 30)
            precondition(value.provider.details.first?.rows.first?.progress?.used == 30)
            precondition(value.provider.details.first?.rows.first?.severity == .warning)
            if additions.contains(id) {
                precondition(value.provider.accountRecordKey == "device-" + value.deviceID)
            }
            #if NEW_WIRE
            let hasMetadata = String(decoding: data, as: UTF8.self).contains("quotaLimit")
            precondition(value.provider.primary?.quotaLimit == (hasMetadata ? 1000 : nil))
            precondition(value.provider.primary?.quotaUnit == (hasMetadata ? "credits" : nil))
            precondition(value.provider.details.first?.rows.first?.progress?.expectedUsed == (hasMetadata ? 25 : nil))
            precondition(value.provider.details.first?.rows.first?.expiresAt == (hasMetadata ? now.addingTimeInterval(60) : nil))
            #endif
            return value
        }
    }

    static func main() throws {
        let args = CommandLine.arguments
        #if NEW_WIRE
        let new = true
        #else
        let new = false
        #endif
        if args[1] == "write" {
            for id in ids {
                guard let provider = provider(id, new: new, device: args[3]) else { continue }
                let value = ProviderUsageEnvelope(
                    deviceID: args[3], deviceName: args[3], appVersion: "fixture", mobileVersion: nil,
                    syncTimestamp: provider.lastUpdated ?? now, notificationPushEnabled: false, provider: provider)
                let path = URL(fileURLWithPath: args[2]).appendingPathComponent(id + ".json")
                try CloudSyncConstants.makeJSONEncoder().encode(value).write(to: path)
            }
            return
        }
        let catalog = QuotaProviderList.providers.map(\.id)
        precondition(catalog.count == (new ? 94 : 90))
        precondition(Array(catalog.prefix(90).suffix(2)) == ["futureagi", "munito"])
        precondition(catalog.last == (new ? "chatbox" : "munito"))
        precondition(QuotaProviderList.quotaZoneName(providerID: "claude", state: "depleted") == "Quota-claude-depletedZone")
        let a = try envelopes(args[2])
        if args[1] == "read" {
            precondition(a.allSatisfy { $0.deviceID == args[3] })
            print("PASS independent reader: quota, units, optional pace, identity and roundtrip")
            return
        }
        let b = try envelopes(args[3])
        for id in ids {
            let values = (a + b).filter { $0.provider.providerID == id }
            guard !values.isEmpty else { continue }
            let sources = values.map {
                SyncedUsageSnapshot(
                    providers: [$0.provider], syncTimestamp: $0.syncTimestamp,
                    deviceName: $0.deviceName, deviceID: $0.deviceID)
            }
            for ordering in [sources, Array(sources.reversed())] {
                guard let merged = ProviderSnapshotMerger.mergeSnapshots(ordering) else { fatalError("merge failed") }
                let expected = additions.contains(id) ? Set(values.map(\.deviceID)).count : 1
                precondition(merged.providers.count == expected, "\(id): account isolation failed")
                precondition(merged.providers.allSatisfy { $0.primary?.usedPercent == 30 })
                if id == "claude" {
                    precondition(merged.providers.first?.lastUpdated == values.compactMap { $0.provider.lastUpdated }.max())
                }
            }
        }
        print("PASS two-writer merge in both orders: stable existing account and isolated new provider accounts")
    }
}
