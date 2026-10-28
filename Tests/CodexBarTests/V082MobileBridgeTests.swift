import CodexBarSync
import Foundation
import Testing
@testable import CodexBar
@testable import CodexBarCore

@MainActor
struct V082MobileBridgeTests {
    @Test func `Copilot calendar month without duration keeps monthly semantics on mobile`() {
        let reset = Date(timeIntervalSince1970: 1_793_500_000)
        let window = RateWindow(usedPercent: 25, windowMinutes: nil, resetsAt: reset, resetDescription: nil)
        let copilot = SyncCoordinator.syncRateWindow(
            id: "primary",
            label: "Monthly",
            window: window,
            provider: .copilot)
        #expect(copilot.period == .monthly)
        #expect(copilot.windowMinutes == nil)
        #expect(copilot.resetsAt == reset)
        let unknown = SyncCoordinator.syncRateWindow(id: "primary", label: "Monthly", window: window)
        #expect(unknown.period == nil) // A display label alone cannot establish a reset cycle.
    }

    @Test func `Kimi gift expiry crosses the production bridge without changing Mac display text`() async throws {
        let usage = try await KimiGiftBalanceTests.fetch(api: false, stats: KimiGiftBalanceTests.stats)
        let rows = SyncCoordinator.mapSyncedDetails(usage.details, provider: .kimi).flatMap(\.rows)
        let gift = try #require(rows.first { $0.label == "Invite to Earn Credit" })
        #expect(gift.expiresAt == ISO8601DateParser.parse("2026-12-31T15:59:59Z"))
        #expect(gift.secondaryValue?.hasPrefix("Expires ") == true)
        #expect(gift.progress?.used == 0.2524)
    }

    @Test func `Soniox prepaid and invoice billing preserve independent monthly spend and observed balances`() {
        for budget in [0.0, 100.0] {
            for used in [0.0, 12.5] {
                for balance in [Double?.none, -2.0, 0.0, 42.0] {
                    let cost = ProviderCostSnapshot(
                        used: used,
                        limit: budget,
                        currencyCode: "USD",
                        period: "This month",
                        balance: balance,
                        updatedAt: Date(timeIntervalSince1970: 1_793_174_400))
                    let amount = SyncCoordinator.mapProviderAmount(provider: .soniox, snapshot: nil, providerCost: cost)
                    if let balance {
                        #expect(amount?.kind == "balance")
                        #expect(amount?.amount == balance)
                        #expect(amount?.period == "Prepaid balance")
                    } else if budget == 0 {
                        #expect(amount?.kind == "spend")
                        #expect(amount?.amount == used)
                        #expect(amount?.period == "This month")
                    } else {
                        #expect(amount == nil) // The existing budget card carries invoice spend.
                    }
                    if amount != nil { #expect(amount?.observedAt == cost.updatedAt) }
                    let details = SyncCoordinator.mapSyncedDetails([], provider: .soniox, providerCost: cost)
                    if budget == 0, balance != nil {
                        #expect(details.first?.rows.first?.label == "Spent this month")
                        #expect(details.first?.rows.first?.value == (used == 0 ? "$0.00" : "$12.50"))
                    } else {
                        #expect(details.isEmpty)
                    }
                }
            }
        }
    }

    @Test func `Plugin window titles survive fallback labels and named extras stay authoritative`() throws {
        let instanceID = try #require(ProviderInstanceID(rawValue: "synthetic-workspace"))
        let primary = RateWindow(
            usedPercent: 25,
            windowMinutes: 43200,
            resetsAt: nil,
            resetDescription: nil,
            title: "Workspace allowance")
        let secondary = RateWindow(
            usedPercent: 10,
            windowMinutes: 10080,
            resetsAt: nil,
            resetDescription: nil,
            title: "Team requests")
        let tertiary = RateWindow(
            usedPercent: 5,
            windowMinutes: 1440,
            resetsAt: nil,
            resetDescription: nil,
            title: "Daily tasks")
        let snapshot = UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            extraRateWindows: [NamedRateWindow(id: "extra", title: "Image quota", window: primary)],
            updatedAt: Date(timeIntervalSince1970: 1_793_174_400))
        let mapped = SyncCoordinator.mapPluginProviderUsageSnapshot(
            instanceID: instanceID, snapshot: snapshot, error: nil, deviceID: "MAC-A")
        #expect(mapped.rateWindows.map(\.label) == [
            "Workspace allowance", "Team requests", "Daily tasks", "Image quota",
        ])
    }

    @Test func `Monthly quota metadata and custom window title cross the mobile bridge`() {
        let window = RateWindow(
            usedPercent: 25,
            windowMinutes: 43200,
            resetsAt: nil,
            resetDescription: nil,
            quotaLimit: 1000,
            quotaUnit: "credits",
            title: "Workspace allowance")
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
            label: "Requests",
            value: "40 / 100",
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
