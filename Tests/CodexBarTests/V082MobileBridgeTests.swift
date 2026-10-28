import CodexBarCore
import CodexBarSync
import Foundation
import Testing
@testable import CodexBar

@MainActor
struct V082MobileBridgeTests {
    @Test func `Monthly quota metadata and custom window title cross the mobile bridge`() {
        let window = RateWindow(
            usedPercent: 25, windowMinutes: 43200, resetsAt: nil, resetDescription: nil,
            quotaLimit: 1000, quotaUnit: "credits", title: "Workspace allowance")
        let mapped = SyncCoordinator.syncRateWindow(id: "monthly", label: nil, window: window)
        #expect(mapped.label == "Workspace allowance")
        #expect(mapped.quotaLimit == 1000)
        #expect(mapped.quotaUnit == "credits")
        let withBalance = SyncCoordinator.withBalanceDescription(mapped, shows: false)
        #expect(withBalance.quotaLimit == 1000)
        #expect(withBalance.quotaUnit == "credits")
    }

    @Test func `Detail expected usage keeps its native numeric units through sync`() throws {
        let row = try ProviderDetailSection.Row(
            label: "Requests", value: "40 / 100",
            progress: .init(used: 40, total: 100, expectedUsed: 30))
        let section = try ProviderDetailSection(rows: [row])
        let mapped = SyncCoordinator.mapDetails([section])
        #expect(mapped.first?.rows.first?.progress?.expectedUsed == 30)
        #expect(mapped.first?.rows.first?.progress?.used == 40)
        #expect(mapped.first?.rows.first?.progress?.total == 100)
    }

    @Test func `New providers without verified account identity stay separated across Macs`() {
        for provider in [UsageProvider.soniox, .traecn, .abliteration, .chatbox] {
            let first = SyncCoordinator.syncAccountRecordKey(provider: provider, requested: nil, deviceID: "MAC-A")
            let second = SyncCoordinator.syncAccountRecordKey(provider: provider, requested: nil, deviceID: "MAC-B")
            #expect(first != nil)
            #expect(first != second)
            #expect(AccountIdentityComputer.compute(provider: provider, identity: nil) == nil)
        }
    }
}
