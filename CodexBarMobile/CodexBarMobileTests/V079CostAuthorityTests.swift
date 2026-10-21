import CodexBarSync
import Foundation
import SwiftData
import Testing
@testable import CodexBarMobile

@Suite("v0.79 cost authority across device and owner migrations")
struct V079CostAuthorityTests {
    private let now = Date(timeIntervalSince1970: 1_792_612_346)
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = .gmt
        return value
    }

    private var day: String {
        TokenActivity.dayKey(self.now, calendar: self.calendar)
    }

    private func provider(
        _ key: String,
        cost: Double? = nil,
        clear: Bool? = nil,
        owner: Bool = false,
        at: Date? = nil,
        costAt: Date? = nil) -> ProviderUsageSnapshot
    {
        let date = at ?? self.now
        let window = SyncRateWindow(
            id: "primary",
            label: "Session",
            usedPercent: 25,
            windowMinutes: 300,
            resetsAt: nil,
            resetDescription: nil)
        var value = ProviderUsageSnapshot(
            providerID: "claude", providerName: "Claude", primary: owner ? nil : window, secondary: nil,
            accountEmail: owner ? nil : key.contains("two") ? "two@example.invalid" : "one@example.invalid",
            loginMethod: nil, statusMessage: nil, isError: false, lastUpdated: date,
            costSummary: cost.map { amount in
                SyncCostSummary(
                    sessionCostUSD: nil,
                    sessionTokens: nil,
                    last30DaysCostUSD: amount,
                    last30DaysTokens: Int(amount * 100),
                    daily: [.init(dayKey: self.day, costUSD: amount, totalTokens: Int(amount * 100))],
                    sourceUpdatedAt: costAt ?? date,
                    sourceDayKey: self.day,
                    bucketTimeZoneIdentifier: "GMT")
            }, costSummaryCleared: clear,
            budget: owner ? nil : .init(
                usedAmount: 1,
                limitAmount: 10,
                currencyCode: "USD",
                period: "Monthly",
                resetsAt: nil),
            rateWindows: owner ? [] : [window],
            accountIdentities: owner ? ["claude:record:" + key] :
                ["claude:email:" + (key.contains("two") ? "two" : "one")],
            accountRecordKey: key,
            details: [.init(
                title: "Local cost history",
                rows: [.init(label: "Account-specific history", value: "fixture")])])
        value.sourceReport = .init(
            sourceDeviceID: "fixture",
            sourceDeviceName: "Fixture Mac",
            sourceCapturedAt: date,
            failures: [],
            deviceCount: 1)
        return value
    }

    private func snapshot(
        _ device: String,
        cost: Double?,
        clear: Bool? = nil,
        legacy: Double? = nil,
        legacyNewer: Bool = false,
        inertOwner: Bool = false) -> SyncedUsageSnapshot
    {
        let old = self.now.addingTimeInterval(-60)
        let one = self.provider(
            "slot-one-" + device,
            cost: legacy,
            clear: legacy == nil ? true : nil,
            at: old,
            costAt: legacyNewer ? self.now.addingTimeInterval(60) : old)
        let two = self.provider("slot-two-" + device, clear: true)
        let owner = self.provider(
            "claude-local-cost:" + device,
            cost: cost,
            clear: inertOwner ? nil : clear,
            owner: true)
        return SyncedUsageSnapshot(
            providers: [one, two, owner],
            syncTimestamp: self.now,
            deviceName: device,
            deviceID: device,
            appVersion: "0.79.0.1",
            providerPublicationTimestamps: [
                SyncedUsageSnapshot.providerPublicationKey(for: one): legacyNewer ? self.now
                    .addingTimeInterval(60) : old,
                SyncedUsageSnapshot.providerPublicationKey(for: owner): self.now,
            ])
    }

    private func context() throws -> ModelContext {
        let schema = Schema(CodexBarSwiftDataSchema.models)
        return try ModelContext(ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)))
    }

    private func check(_ snapshots: [SyncedUsageSnapshot], context: ModelContext, cost: Double, tokens: Int) throws {
        try SwiftDataBridge.upsert(deviceSnapshots: snapshots, into: context)
        let merged = try #require(ProviderSnapshotMerger.mergeSnapshots(snapshots))
        #expect(merged.providers.filter { !$0.isProviderLevelCostEnvelope }.count == 2)
        let aggregate = try CostLedgerService.aggregate(
            windowDays: 30,
            in: context,
            asOf: self.now,
            activeDeviceIDs: Set(snapshots.compactMap(\.deviceID)),
            sourceSnapshots: snapshots,
            readerTimeZone: .gmt)
        let insights = CostDashboardInsights.fromLedger(
            aggregation: aggregate,
            snapshot: merged,
            now: self.now,
            calendar: self.calendar)
        #expect(insights.providerRows.reduce(0) { $0 + $1.todayCost } == cost)
        #expect(!insights.budgetRows.isEmpty, "withdrawn costs must not hide valid budgets")
        let series = TokenActivity.series(
            providers: merged.providers,
            rollups: aggregate.sortedProviderRollups,
            referenceDate: self.now)
        #expect(TokenActivity.total(series, dayKey: self.day).value == tokens)
        let projection = WidgetActivityProjectionBuilder.make(
            series: series,
            latestSyncAt: self.now,
            now: self.now,
            calendar: self.calendar)
        #expect(projection.source(id: "all")?.days.first { $0.key == self.day }?.tokens == tokens)
        let widget = CodexBarWidgetSnapshotBuilder.makeSnapshot(from: snapshots, now: self.now)
        #expect(widget.providerCount == 2)
        #expect(widget.todayCostUSD == (cost == 0 ? nil : cost))
        #expect(widget.todayTokens == (tokens == 0 ? nil : tokens))
    }

    @Test func `two Macs deduplicate quota accounts and cost owners through clear restore and reverse migration`() throws {
        let context = try self.context()
        let legacy = self.provider("slot-one-mac-a", cost: 1, at: self.now.addingTimeInterval(-120))
        try SwiftDataBridge.upsert(deviceSnapshots: [SyncedUsageSnapshot(
            providers: [legacy],
            syncTimestamp: self.now,
            deviceName: "mac-a",
            deviceID: "mac-a")], into: context)
        let historicalDay = try TokenActivity.dayKey(
            #require(self.calendar.date(byAdding: .day, value: -40, to: self.now)),
            calendar: self.calendar)
        try CostLedgerService.upsertDayPoint(
            deviceID: "mac-a",
            providerID: "claude",
            accountEmail: legacy.accountEmail,
            accountRecordKey: legacy.accountRecordKey,
            accountIdentityKeys: CostLedgerService.accountIdentityKeys(for: legacy),
            dayKey: historicalDay,
            costUSD: 5,
            totalTokens: 500,
            costIsKnown: true,
            isEstimated: nil,
            modelBreakdowns: [],
            serviceBreakdowns: [],
            lastUpdated: self.now.addingTimeInterval(-120),
            in: context)
        let a = self.snapshot("mac-a", cost: 1, legacy: 1)
        let b = self.snapshot("mac-b", cost: 2, legacy: 2)
        try self.check([a, b], context: context, cost: 3, tokens: 300)
        let migrated = try context.fetch(FetchDescriptor<DailyCostPoint>())
        #expect(migrated.first { $0.dayKey == historicalDay }?.accountRecordKey == "claude-local-cost:mac-a")
        #expect(!migrated.contains { $0.accountRecordKey == legacy.accountRecordKey })
        let longHistory = try CostLedgerService.aggregate(
            windowDays: 365,
            in: context,
            asOf: self.now,
            sourceSnapshots: [a, b],
            readerTimeZone: .gmt)
        #expect(longHistory.sortedProviderRollups.flatMap(\.dailyPoints)
            .contains { $0.dayKey == historicalDay && $0.costUSD == 5 })
        let aClear = self.snapshot("mac-a", cost: nil, clear: true, legacy: 1)
        try self.check([aClear, b], context: context, cost: 2, tokens: 200)
        let raw = try context.fetch(FetchDescriptor<DailyCostPoint>())
        #expect(raw.reduce(0) { $0 + $1.costUSD } == 8, "clear hides rather than deletes raw history")
        try self.check(
            [a, self.snapshot("mac-b", cost: nil, clear: true, legacy: 2)],
            context: context,
            cost: 1,
            tokens: 100)
        try self.check([a, b], context: context, cost: 3, tokens: 300)
        // An older observation published later is authoritative when switching the adapter off.
        try self.check(
            [self.snapshot("mac-a", cost: 1, legacy: 4, legacyNewer: true), b],
            context: context,
            cost: 6,
            tokens: 600)
    }

    @Test func `a newer legacy clear withdraws stale independent and legacy costs only on its own Mac`() throws {
        let context = try self.context()
        let b = self.snapshot("mac-b", cost: 2)
        try self.check([self.snapshot("mac-a", cost: 1), b], context: context, cost: 3, tokens: 300)
        let clear = self.provider("slot-one-mac-a", clear: true)
        let stale = self.provider("slot-two-mac-a", cost: 1, at: self.now.addingTimeInterval(-120))
        let owner = self.provider("claude-local-cost:mac-a", cost: 1, owner: true, at: self.now.addingTimeInterval(-60))
        let inert = self.provider("idle-one-mac-a", at: self.now.addingTimeInterval(180))
        let current = SyncedUsageSnapshot(
            providers: [clear, stale, owner, inert],
            syncTimestamp: self.now,
            deviceName: "mac-a",
            deviceID: "mac-a")
        let normalized = ProviderSnapshotMerger.effectiveCostSnapshot(current)
        #expect(normalized.providers.allSatisfy { $0.costSummary == nil })
        #expect(normalized.providers.last?.costSummaryCleared == nil)
        #expect(ProviderSnapshotMerger.effectiveCostSnapshot(normalized) == normalized)
        try self.check([current, b], context: context, cost: 2, tokens: 200)
        let rows = try context.fetch(FetchDescriptor<DailyCostPoint>())
        #expect(rows.filter { $0.deviceID == "mac-a" }.reduce(0) { $0 + $1.costUSD } == 1)
    }

    @Test func `fresh adapter quota clears keep a still valid old machine owner until its own clear`() throws {
        let context = try self.context()
        let b = self.snapshot("mac-b", cost: 2)
        let old = self.provider("claude-local-cost:mac-a", cost: 1, owner: true, at: self.now.addingTimeInterval(-60))
        let quotas = [
            self.provider("adapter:mac-a:tcr:one", clear: true),
            self.provider("adapter:mac-a:tcr:two", clear: true),
        ]
        let startup = SyncedUsageSnapshot(
            providers: quotas + [old],
            syncTimestamp: self.now,
            deviceName: "mac-a",
            deviceID: "mac-a")
        let normalized = ProviderSnapshotMerger.effectiveCostSnapshot(startup)
        #expect(ProviderSnapshotMerger.effectiveCostSnapshot(normalized) == normalized)
        try self.check([startup, b], context: context, cost: 3, tokens: 300)
        let noOwnerYet = SyncedUsageSnapshot(
            providers: quotas,
            syncTimestamp: self.now,
            deviceName: "mac-a",
            deviceID: "mac-a")
        let retained = try CostLedgerService.aggregate(
            windowDays: 30,
            in: context,
            asOf: self.now,
            sourceSnapshots: [noOwnerYet, b],
            readerTimeZone: .gmt)
        #expect(retained.sortedProviderRollups.flatMap(\.dailyPoints).reduce(0) { $0 + $1.costUSD } == 3)
        let clear = self.provider("claude-local-cost:mac-a", clear: true, owner: true)
        let withdrawn = SyncedUsageSnapshot(
            providers: quotas + [clear],
            syncTimestamp: self.now,
            deviceName: "mac-a",
            deviceID: "mac-a")
        try self.check([withdrawn, b], context: context, cost: 2, tokens: 200)
    }

    @Test func `ordinary nil owner is inert and normalization preserves metadata and is idempotent`() {
        let original = self.snapshot("mac-a", cost: 1, legacy: 8)
        let normalized = ProviderSnapshotMerger.effectiveCostSnapshot(original)
        #expect(ProviderSnapshotMerger.effectiveCostSnapshot(normalized) == normalized)
        #expect(normalized.providerPublicationTimestamps == original.providerPublicationTimestamps)
        let before = original.providers[0], after = normalized.providers[0]
        #expect(after.primary == before.primary && after.budget == before.budget)
        #expect(after.details == before.details && after.sourceReport == before.sourceReport)
        #expect(after.accountIdentities == before.accountIdentities && after.accountRecordKey == before
            .accountRecordKey)
        #expect(after.costSummary == nil && after.costSummaryCleared == true)
        let inert = ProviderSnapshotMerger.effectiveCostSnapshot(self.snapshot(
            "mac-a",
            cost: nil,
            legacy: 8,
            inertOwner: true))
        #expect(inert.providers[0].costSummary?.last30DaysCostUSD == 8)
    }

    @Test func `alias cost owners select one deterministic latest publication without changing real device sums`() {
        let base = self.snapshot("mac-a", cost: 1)
        let other = self.provider(
            "claude-local-cost:retired-alias",
            cost: 8,
            owner: true,
            at: self.now.addingTimeInterval(-60))
        let inert = self.provider("claude-local-cost:unknown-alias", owner: true, at: self.now.addingTimeInterval(120))
        let source = SyncedUsageSnapshot(
            providers: base.providers + [other, inert],
            syncTimestamp: self.now,
            deviceName: "mac-a",
            deviceID: "mac-a")
        let normalized = ProviderSnapshotMerger.effectiveCostSnapshot(source)
        #expect(normalized.providers.filter { $0.costSummary != nil }.count == 1)
        #expect(normalized.providers[3].costSummaryCleared == true)
        #expect(normalized.providers.last?.costSummaryCleared == nil)
        #expect(ProviderSnapshotMerger.effectiveCostSnapshot(normalized) == normalized)
    }

    @Test func `incoming inert owner history follows the sole valid owner in both adapter directions`() throws {
        let context = try self.context()
        let key = "claude-local-cost:unknown-alias"
        let previous = self.provider(key, cost: 8, owner: true, at: self.now.addingTimeInterval(-60))
        try SwiftDataBridge.upsert(
            deviceSnapshots: [SyncedUsageSnapshot(
                providers: [previous],
                syncTimestamp: self.now,
                deviceName: "mac-a",
                deviceID: "mac-a")],
            into: context)
        for legacyNewer in [false, true] {
            let base = self.snapshot("mac-a", cost: 1, legacy: legacyNewer ? 4 : nil, legacyNewer: legacyNewer)
            let inert = self.provider(key, owner: true, at: self.now.addingTimeInterval(180))
            let source = SyncedUsageSnapshot(
                providers: base.providers + [inert],
                syncTimestamp: self.now,
                deviceName: "mac-a",
                deviceID: "mac-a",
                providerPublicationTimestamps: base.providerPublicationTimestamps)
            try self.check([source], context: context, cost: legacyNewer ? 4 : 1, tokens: legacyNewer ? 400 : 100)
            let rows = try context.fetch(FetchDescriptor<DailyCostPoint>())
            #expect(rows.count == 1)
            #expect(rows.first?.accountRecordKey == (legacyNewer ? "slot-one-mac-a" : "claude-local-cost:mac-a"))
        }
    }

    @Test func `clear on a new owner hides ledger only old keys until a valid owner returns`() throws {
        let context = try self.context()
        let legacy = self.provider("retired-record", cost: 4)
        try SwiftDataBridge.upsert(
            deviceSnapshots: [SyncedUsageSnapshot(
                providers: [legacy],
                syncTimestamp: self.now,
                deviceName: "mac-a",
                deviceID: "mac-a")],
            into: context)
        let clear = self.snapshot("mac-a", cost: nil, clear: true)
        try SwiftDataBridge.upsert(deviceSnapshots: [clear], into: context)
        let aggregate = try CostLedgerService.aggregate(
            windowDays: 30,
            in: context,
            asOf: self.now,
            sourceSnapshots: [clear],
            readerTimeZone: .gmt)
        #expect(aggregate.providerRollups.isEmpty)
        #expect(try context.fetch(FetchDescriptor<DailyCostPoint>()).first?.costUSD == 4)
        try self.check([self.snapshot("mac-a", cost: 1)], context: context, cost: 1, tokens: 100)
        let rows = try context.fetch(FetchDescriptor<DailyCostPoint>())
        #expect(rows.count == 1 && rows.first?.accountRecordKey == "claude-local-cost:mac-a")
    }

    @Test func `ordinary nil keeps the ledger fallback while an explicit clear suppresses it`() throws {
        let context = try self.context()
        let old = self.provider("legacy", cost: 4)
        let original = SyncedUsageSnapshot(
            providers: [old],
            syncTimestamp: self.now,
            deviceName: "mac-a",
            deviceID: "mac-a")
        try SwiftDataBridge.upsert(deviceSnapshots: [original], into: context)
        for (clear, expected) in [(nil as Bool?, 4.0), (true, 0.0)] {
            let provider = self.provider("legacy", clear: clear)
            let source = SyncedUsageSnapshot(
                providers: [provider],
                syncTimestamp: self.now,
                deviceName: "mac-a",
                deviceID: "mac-a")
            try SwiftDataBridge.upsert(deviceSnapshots: [source], into: context)
            let aggregate = try CostLedgerService.aggregate(
                windowDays: 30,
                in: context,
                asOf: self.now,
                sourceSnapshots: [source],
                readerTimeZone: .gmt)
            let insights = CostDashboardInsights.fromLedger(
                aggregation: aggregate,
                snapshot: source,
                now: self.now,
                calendar: self.calendar)
            #expect(insights.providerRows.reduce(0) { $0 + $1.todayCost } == expected)
            #expect(try context.fetch(FetchDescriptor<DailyCostPoint>()).first?.costUSD == 4)
        }
    }
}

@Suite("v0.79 organization identities")
struct V079OrganizationIdentityTests {
    @Test func `same organization merges across Macs while equal names do not merge different organizations`() throws {
        let now = Date(timeIntervalSince1970: 1_792_612_346)
        func provider(_ key: String, cost: Double) -> ProviderUsageSnapshot {
            ProviderUsageSnapshot(
                providerID: "munito",
                providerName: "Munito",
                primary: .init(
                    id: "primary", label: "Today", usedPercent: 20, windowMinutes: 1440, resetsAt: nil,
                    resetDescription: nil),
                secondary: nil,
                accountEmail: nil,
                loginMethod: nil,
                statusMessage: nil,
                isError: false,
                lastUpdated: now,
                costSummary: .init(
                    sessionCostUSD: nil,
                    sessionTokens: nil,
                    last30DaysCostUSD: cost,
                    last30DaysTokens: nil,
                    daily: [],
                    sourceUpdatedAt: now),
                accountRecordKey: key,
                accountOrganization: "Same editable name")
        }
        let a = SyncedUsageSnapshot(
            providers: [
                provider("organization-shared", cost: 5),
                provider("organization-other", cost: 7),
                provider("device-mac-a", cost: 0),
            ],
            syncTimestamp: now,
            deviceName: "A",
            deviceID: "mac-a")
        let b = SyncedUsageSnapshot(
            providers: [provider("organization-shared", cost: 5), provider("device-mac-b", cost: 0)],
            syncTimestamp: now,
            deviceName: "B",
            deviceID: "mac-b")
        for snapshots in [[a, b], [b, a]] {
            let merged = try #require(ProviderSnapshotMerger.mergeSnapshots(snapshots))
            #expect(merged.providers.count == 4)
            #expect(merged.providers.compactMap { $0.costSummary?.last30DaysCostUSD }.reduce(0, +) == 12)
        }
    }
}
