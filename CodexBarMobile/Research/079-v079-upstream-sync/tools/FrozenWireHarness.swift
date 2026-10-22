import Foundation

/// Compile the published old models and current models separately. Each writer has a distinct
/// device ID; each reader process independently decodes, round-trips and merges both writer orders.
/// This validates serialization and merge logic, not live CloudKit/APNs/cache convergence.
@main
struct Harness {
    static let now = Date(timeIntervalSince1970: 1_792_612_346)
    static let ids = ["claude", "gemini", "gemini-cli-shared", "gemini-cli-distinct", "futureagi", "munito", "munito-organization", "munito-other", "plugin:fixture", "claude-cost"]

    static func provider(_ id: String, new: Bool, device: String) -> ProviderUsageSnapshot? {
        if ["futureagi", "munito", "munito-organization", "munito-other", "claude-cost"].contains(id), !new { return nil }
        if id == "munito-other", device != "mac-a" { return nil }
        let organization = id.hasPrefix("munito-")
        let gemini = id == "gemini" || id.hasPrefix("gemini-cli-")
        let geminiWeb = id == "gemini" && new
        let providerID = organization ? "munito" : (gemini ? "gemini" : id)
        let email = id == "gemini-cli-shared" ? "shared@example.invalid"
            : (id == "gemini-cli-distinct" ? device + "@example.invalid" : nil)
        let organizationKey = id == "munito-other" ? "organization-fixture-distinct" : "organization-fixture-shared"
        if id == "claude-cost" {
            return ProviderUsageSnapshot(
                providerID: "claude", providerName: "Claude", primary: nil, secondary: nil,
                accountEmail: nil, loginMethod: nil, statusMessage: nil, isError: false,
                lastUpdated: now, costSummaryCleared: true, rateWindows: [],
                accountRecordKey: "claude-local-cost:" + device)
        }
        let window = SyncRateWindow(id: "primary", label: gemini ? (geminiWeb ? "5-hour" : "Pro")
            : (id == "futureagi" ? "AI credits" : "Session"),
            usedPercent: geminiWeb ? (device == "mac-a" ? 24 : 90) : 30,
            windowMinutes: gemini && !geminiWeb ? 1440 : 300, resetsAt: now.addingTimeInterval(3600), resetDescription: nil)
        let windows = gemini ? [window, SyncRateWindow(id: "secondary", label: geminiWeb ? "Weekly" : "Flash",
            usedPercent: geminiWeb && device == "mac-b" ? 10 : 4,
            windowMinutes: geminiWeb ? 10080 : 1440, resetsAt: now.addingTimeInterval(3600), resetDescription: nil)] : [window]
        var rows: [SyncProviderDetailSection.Row] = []
        if id == "plugin:fixture" {
            #if NEW_WIRE
            rows = [.init(label: "Queue", value: "Busy", severity: .warning)]
            #else
            rows = [.init(label: "Queue", value: "Busy")]
            #endif
        }
        return ProviderUsageSnapshot(
            providerID: providerID, providerName: id, primary: window, secondary: windows.dropFirst().first,
            accountEmail: email, loginMethod: nil, statusMessage: nil, isError: false,
            lastUpdated: now,
            costSummary: organization ? SyncCostSummary(
                sessionCostUSD: nil, sessionTokens: nil, last30DaysCostUSD: id == "munito-other" ? 7 : 5,
                last30DaysTokens: nil, daily: [], sourceUpdatedAt: now) : nil,
            rateWindows: windows,
            accountIdentities: id == "claude" ? ["claude:email:fixture@example.test"] : nil,
            accountRecordKey: geminiWeb ? "web-device-" + device
                : (organization ? organizationKey : (["futureagi", "munito"].contains(id) ? "device-" + device : nil)),
            accountOrganization: organization ? "Same editable organization name" : nil,
            details: rows.isEmpty ? [] : [.init(title: "Status", rows: rows)])
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
            let isCostOwner = value.provider.accountRecordKey?.hasPrefix("claude-local-cost:") == true
            if isCostOwner {
                precondition(value.provider.costSummaryCleared == true && value.provider.hasUsableSignal)
                #if NEW_WIRE
                precondition(value.provider.isProviderLevelCostEnvelope)
                #else
                precondition(!value.provider.isProviderLevelCostEnvelope)
                #endif
            } else {
                if value.provider.providerID == "gemini" {
                    let appQuota = value.provider.rateWindows.first?.windowMinutes == 300
                    precondition(value.provider.rateWindows.compactMap(\.label) == (appQuota ? ["5-hour", "Weekly"] : ["Pro", "Flash"]))
                    precondition(value.provider.primary?.usedPercent == (appQuota ? (value.deviceID == "mac-a" ? 24 : 90) : 30))
                    if appQuota { precondition(value.provider.accountRecordKey == "web-device-" + value.deviceID) }
                } else {
                    precondition(value.provider.rateWindows.first?.usedPercent == 30)
                }
            }
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
                let value = ProviderUsageEnvelope(deviceID: args[3], deviceName: args[3], appVersion: "fixture",
                    mobileVersion: nil, syncTimestamp: now, notificationPushEnabled: false, provider: provider)
                let path = URL(fileURLWithPath: args[2]).appendingPathComponent(id + ".json")
                try CloudSyncConstants.makeJSONEncoder().encode(value).write(to: path)
            }
            return
        }
        let catalog = QuotaProviderList.providers.map(\.id)
        precondition(catalog.contains("futureagi") == new && catalog.contains("munito") == new)
        precondition(catalog.last == (new ? "munito" : "claudeplatform"))
        precondition(QuotaProviderList.quotaZoneName(providerID: "claude", state: "depleted") == "Quota-claude-depletedZone")
        let a = try envelopes(args[2])
        if args[1] == "read" {
            precondition(a.allSatisfy { $0.deviceID == args[3] })
            #if NEW_WIRE
            let plugin = a.first { $0.provider.providerID == "plugin:fixture" }
            let raw = try Data(contentsOf: URL(fileURLWithPath: args[2]).appendingPathComponent("plugin:fixture.json"))
            if String(decoding: raw, as: UTF8.self).contains("severity") {
                precondition(plugin?.provider.details.first?.rows.first?.severity == .warning)
            } else {
                precondition(plugin?.provider.details.first?.rows.first?.severity == nil)
            }
            #endif
            print("PASS independent reader: \(a.count) envelopes, quotas, identity, optional metadata, roundtrip")
            return
        }
        let b = try envelopes(args[3])
        for id in ["claude", "gemini", "futureagi", "munito", "plugin:fixture"] {
            let sources = (a + b).filter { $0.provider.providerID == id }.map {
                SyncedUsageSnapshot(providers: [$0.provider], syncTimestamp: $0.syncTimestamp,
                    deviceName: $0.deviceName, deviceID: $0.deviceID)
            }
            guard !sources.isEmpty else { continue }
            for ordering in [sources, Array(sources.reversed())] {
                guard let merged = ProviderSnapshotMerger.mergeSnapshots(ordering) else { fatalError("merge failed") }
                let costOwners = sources.flatMap(\.providers).filter {
                    $0.accountRecordKey?.hasPrefix("claude-local-cost:") == true
                }.count
                let expected: Int
                if id == "gemini" {
                    expected = Set(sources.flatMap(\.providers).map { provider in
                        provider.accountRecordKey.map { "record:" + $0 }
                            ?? provider.accountEmail.map { "email:" + $0 } ?? "legacy"
                    }).count
                } else {
                    expected = ["futureagi", "munito"].contains(id)
                        ? Set(sources.flatMap(\.providers).compactMap(\.accountRecordKey)).count : 1 + costOwners
                }
                precondition(merged.providers.count == expected, "\(id) expected \(expected) accounts")
                if id == "gemini" {
                    for source in sources.flatMap(\.providers) {
                        let account = merged.providers.first {
                            $0.accountRecordKey == source.accountRecordKey && $0.accountEmail == source.accountEmail
                        }
                        precondition(account?.rateWindows == source.rateWindows, "Gemini source quotas must remain separate")
                    }
                }
                if id == "munito" {
                    let organizations = merged.providers.filter { $0.accountRecordKey?.hasPrefix("organization-") == true }
                    let shared = sources.flatMap(\.providers).contains { $0.accountRecordKey == "organization-fixture-shared" }
                    let distinct = sources.flatMap(\.providers).contains { $0.accountRecordKey == "organization-fixture-distinct" }
                    precondition(organizations.count == (shared ? 1 : 0) + (distinct ? 1 : 0))
                    precondition(organizations.compactMap { $0.costSummary?.last30DaysCostUSD }.reduce(0, +)
                        == (shared ? 5 : 0) + (distinct ? 7 : 0), "organization spend must not double across Macs")
                }
                if id != "gemini" {
                    precondition(merged.providers.allSatisfy {
                        $0.primary?.usedPercent == 30 || $0.costSummaryCleared == true
                    })
                }
            }
        }
        print("PASS two-writer merge in both orders: stable Claude identity and legacy provider fallback")
    }
}
