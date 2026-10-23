import CodexBarSync
import Foundation
import Testing
import UIKit
@testable import CodexBarMobile

@Suite("Account-scoped usage quota overview")
@MainActor
struct UsageQuotaOverviewTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private static func window(
        id: String = "primary", used: Double = 20, minutes: Int? = 300,
        reset: Date? = Self.now.addingTimeInterval(3600), known: Bool = true,
        blocked: Bool = false) -> SyncRateWindow
    {
        SyncRateWindow(
            id: id,
            label: id == "secondary" ? "Weekly" : id.hasPrefix("claude-weekly-scoped-") ? "Fable only" : "Session",
            usedPercent: used, usageKnown: known, windowMinutes: minutes, resetsAt: reset, resetDescription: nil,
            blockingQuota: blocked ? SyncBlockingQuota(
                windowID: "secondary", rawUsedPercent: 100, rawResetsAt: reset,
                rawResetDescription: nil, rawNextRegenPercent: nil) : nil)
    }

    private static func account(
        id: String = "fictional-a", record: String? = "install-a", providerID: String = "claude",
        capturedAt: Date = Self.now, windows: [SyncRateWindow]? = nil,
        wireHistory: [SyncUtilizationSeries]? = nil,
        identities: [String]? = nil) -> ProviderUsageSnapshot
    {
        ProviderUsageSnapshot(
            providerID: providerID, providerName: providerID.capitalized, primary: nil, secondary: nil,
            accountEmail: "\(id)@example.invalid", loginMethod: nil, statusMessage: nil, isError: false,
            lastUpdated: capturedAt, rateWindows: windows ?? [self.window()], utilizationHistory: wireHistory,
            accountIdentities: identities ?? ["\(providerID):account:\(id)"], accountRecordKey: record)
    }

    private static func sampledStore(id: String = "fictional-a") -> UsageQuotaOverviewStore {
        let store = UsageQuotaOverviewStore.inMemory()
        let amounts: [Double] = [10, 10, 12, 18, 18, 20, 25, 25, 30]
        for (index, used) in amounts.enumerated() {
            let captured = Self.now.addingTimeInterval(Double(index - 8) * 300)
            store.reconcile(accounts: [Self.account(
                id: id, capturedAt: captured, windows: [Self.window(used: used)])], now: Self.now)
        }
        return store
    }

    @Test
    func `defaults initialize only once and clearing survives persistence reload`() throws {
        let memory = UsageQuotaMemoryPersistence()
        let store = UsageQuotaOverviewStore(persistence: memory)
        store.reconcile(accounts: [], now: Self.now)
        #expect(!store.preferences.hasInitialized)
        store.reconcile(accounts: [Self.account()], now: Self.now)
        #expect(store.preferences.selections.count == 1)
        try store.remove(id: #require(store.preferences.selections.first).id)
        let reopened = UsageQuotaOverviewStore(persistence: memory)
        reopened.reconcile(accounts: [Self.account()], now: Self.now)
        #expect(reopened.preferences.hasInitialized)
        #expect(reopened.preferences.selections.isEmpty)
    }

    @Test
    func `selection cap uniqueness colors and scoped windows are independent`() throws {
        let windows = (0..<8).map { index in
            Self.window(id: index == 0 ? "primary" : "claude-weekly-scoped-fictitious-\(index)", minutes: 10080)
        }
        let account = Self.account(windows: windows)
        let store = UsageQuotaOverviewStore.inMemory()
        store.reconcile(accounts: [account], now: Self.now)
        for selection in store.preferences.selections {
            store.remove(id: selection.id)
        }
        let candidates = store.catalog(accounts: [account], now: Self.now)
        #expect(candidates.count == 8)
        for candidate in candidates.prefix(5) {
            #expect(store.add(candidate))
        }
        #expect(!store.add(candidates[5]))
        #expect(!store.add(candidates[0]))
        #expect(store.preferences.selections.count == 5)
        #expect(Set(store.preferences.selections.map(\.colorHex)).count == 5)
        var first = try #require(store.preferences.selections.first)
        first.colorHex = "#12abef"
        #expect(store.update(first))
        #expect(store.preferences.selections.first?.colorHex == "12ABEF")
        first.colorHex = "invalid"
        #expect(!store.update(first))
        #expect(store.preferences.selections.first?.colorHex == "12ABEF")
    }

    @Test
    func `default colors come from the existing provider palette`() {
        for providerID in ["grok", "cursor", "claude", "codex"] {
            let expected = UIColor(ProviderColorPalette.color(for: providerID, tintHex: nil))
                .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            let actualHex = UsageQuotaColor.suggested(providerID: providerID, ordinal: 0)
            let value = UInt32(actualHex, radix: 16) ?? 0
            let actual = UIColor(
                red: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: 1)
            var er: CGFloat = 0, eg: CGFloat = 0, eb: CGFloat = 0, ea: CGFloat = 0
            var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
            #expect(expected.getRed(&er, green: &eg, blue: &eb, alpha: &ea))
            #expect(actual.getRed(&ar, green: &ag, blue: &ab, alpha: &aa))
            #expect(abs(er - ar) <= 0.5 / 255)
            #expect(abs(eg - ag) <= 0.5 / 255)
            #expect(abs(eb - ab) <= 0.5 / 255)
        }
        #expect(UsageQuotaColor.suggested(providerID: "claude", ordinal: 0) !=
            UsageQuotaColor.suggested(providerID: "claude", ordinal: 1))
        #expect(UsageQuotaColor.normalized("#aAbB33") == "AABB33")
        #expect(UsageQuotaColor.normalized("fff") == nil)
    }

    @Test
    func `first run gives other providers a weekly line before adding second Claude accounts`() {
        let windows = [Self.window(), Self.window(id: "secondary", minutes: 10080)]
        let accounts = [
            Self.account(id: "claude-a", windows: windows),
            Self.account(id: "claude-b", windows: windows),
            Self.account(id: "codex-a", providerID: "codex", windows: windows),
            Self.account(id: "codex-b", providerID: "codex", windows: windows),
            Self.account(id: "muse-a", providerID: "muse", windows: windows),
            Self.account(id: "grok-a", providerID: "grok", windows: windows),
        ]
        let store = UsageQuotaOverviewStore.inMemory()
        store.reconcile(accounts: accounts, now: Self.now)
        #expect(store.preferences.selections.map(\.providerID) == ["claude", "claude", "codex", "muse", "grok"])
        #expect(store.preferences.selections.map(\.windowID) == [
            "secondary",
            "primary",
            "secondary",
            "secondary",
            "secondary",
        ])
        #expect(Set(store.preferences.selections.prefix(2).map(\.accountAnchorID)).count == 1)
        let original = store.preferences.selections
        store.reconcile(accounts: accounts.reversed(), now: Self.now)
        #expect(store.preferences.selections == original)
    }

    @Test
    func `shared wire history never seeds account-specific curves even with one visible account`() throws {
        let history = SyncUtilizationSeries(name: "session", windowMinutes: 300, entries: [
            SyncUtilizationEntry(capturedAt: Self.now.addingTimeInterval(-1800), usedPercent: 1, resetsAt: nil),
            SyncUtilizationEntry(capturedAt: Self.now.addingTimeInterval(-900), usedPercent: 19, resetsAt: nil),
            SyncUtilizationEntry(capturedAt: Self.now.addingTimeInterval(-300), usedPercent: 19, resetsAt: nil),
        ])
        let account = Self.account(wireHistory: [history])
        let store = UsageQuotaOverviewStore.inMemory()
        store.reconcile(accounts: [account], now: Self.now)
        let line = try #require(store.overview(accounts: [account], now: Self.now).lines.first)
        #expect(line.localObservationCount == 1)
        #expect(line.projectionKind == .uniformMean)
        #expect(line.estimatedSamples.count <= 3)
    }

    @Test
    func `enough real local observations preserve measured pauses and varying consumption as estimates`() throws {
        let store = Self.sampledStore()
        let latest = Self.account(windows: [Self.window(used: 30)])
        let first = try #require(store.overview(accounts: [latest], now: Self.now).lines.first)
        let second = try #require(store.overview(accounts: [latest], now: Self.now).lines.first)
        #expect(first.localObservationCount == 9)
        #expect(first.projectionKind == .observedPattern)
        #expect(first.estimatedSamples == second.estimatedSamples)
        #expect(first.estimatedSamples.first?.date == Self.now)
        // The latest sufficient 900-second segment consumed 5, then 0, then 5 points.
        let pause = first.estimatedSamples.filter {
            $0.date >= Self.now.addingTimeInterval(300) && $0.date <= Self.now.addingTimeInterval(600)
        }
        #expect(pause.count > 1)
        #expect(pause.allSatisfy { abs($0.remainingPercent - 65) < 0.000001 })
        #expect(first.estimatedSamples.contains { $0.remainingPercent < 65 })
        #expect(first.estimatedSamples.allSatisfy { (0...100).contains($0.remainingPercent) })
    }

    @Test(arguments: [60, 300])
    func `frequent weekly observations retain elapsed span and real busy idle estimates`(intervalSeconds: Int) throws {
        let memory = UsageQuotaMemoryPersistence()
        let store = UsageQuotaOverviewStore(persistence: memory)
        let start = Self.now.addingTimeInterval(-8 * 3600)
        let reset = Self.now.addingTimeInterval(3 * 86400)
        func reading(at elapsed: Int) -> ProviderUsageSnapshot {
            let periods = elapsed / 1200
            let activeSeconds = max(0, elapsed % 1200 - 600)
            let used = 10 + Double(periods) * 2 + Double(activeSeconds) / 300
            return Self.account(
                capturedAt: start.addingTimeInterval(Double(elapsed)),
                windows: [Self.window(used: used, minutes: 10080, reset: reset)])
        }
        for elapsed in stride(from: 0, through: 8 * 3600, by: intervalSeconds) {
            let account = reading(at: elapsed)
            store.reconcile(accounts: [account], now: account.lastUpdated)
        }
        func assertEstimate(elapsed: Int) throws {
            let account = reading(at: elapsed)
            let line = try #require(store.overview(accounts: [account], now: account.lastUpdated).lines.first)
            let archive = try JSONDecoder().decode(UsageQuotaArchive.self, from: #require(memory.data))
            let observations = try #require(archive.histories.first).observations
            let first = try #require(observations.first)
            let latest = try #require(observations.last)
            #expect(observations.count <= UsageQuotaOverviewStore.maximumObservationsPerStream)
            #expect(latest.capturedAt.timeIntervalSince(first.capturedAt) >= 6 * 3600)
            #expect(latest.capturedAt == account.lastUpdated)
            #expect(latest.usedPercent == account.rateWindows[0].usedPercent)
            #expect(line.projectionKind == .observedPattern)
            #expect(line.estimatedSamples.first?.date == account.lastUpdated)
            #expect(line.estimatedSamples.first?.remainingPercent == line.currentRemainingPercent)
            let pairs = Array(zip(line.estimatedSamples, line.estimatedSamples.dropFirst()))
            #expect(pairs.contains { $0.remainingPercent == $1.remainingPercent })
            #expect(pairs.contains { $0.remainingPercent > $1.remainingPercent })
            #expect(pairs.allSatisfy { $0.remainingPercent >= $1.remainingPercent })
            #expect(line.estimatedSamples.allSatisfy { $0.date <= reset })
        }
        try assertEstimate(elapsed: 8 * 3600)
        let beforeDuplicate = memory.data
        store.reconcile(accounts: [reading(at: 8 * 3600)], now: Self.now.addingTimeInterval(30))
        #expect(memory.data == beforeDuplicate, "A reader refresh cannot advance a source observation")
        // Once full, trimming old endpoints must continue to retain the minimum elapsed span.
        for elapsed in stride(from: 8 * 3600 + intervalSeconds, through: 9 * 3600, by: intervalSeconds) {
            let account = reading(at: elapsed)
            store.reconcile(accounts: [account], now: account.lastUpdated)
        }
        try assertEstimate(elapsed: 9 * 3600)
    }

    @Test
    func `subminute sampling retains the latest actual endpoint without disabling an eligible pattern`() throws {
        let store = UsageQuotaOverviewStore.inMemory()
        let start = Self.now.addingTimeInterval(-1830)
        for elapsed in stride(from: 0, through: 1830, by: 30) {
            let used = 10 + Double(elapsed / 300)
            let account = Self.account(
                capturedAt: start.addingTimeInterval(Double(elapsed)), windows: [Self.window(used: used)])
            store.reconcile(accounts: [account], now: account.lastUpdated)
        }
        let latest = Self.account(windows: [Self.window(used: 16)])
        let line = try #require(store.overview(accounts: [latest], now: Self.now).lines.first)
        #expect(line.observedAt == Self.now)
        #expect(line.currentRemainingPercent == 84)
        #expect(line.projectionKind == .observedPattern)
        #expect(line.estimatedSamples.first == UsageQuotaPoint(date: Self.now, remainingPercent: 84))
        #expect(line.localObservationCount <= UsageQuotaOverviewStore.maximumObservationsPerStream)
    }

    @Test
    func `time aware retention never relabels a long missing interval as measured idle time`() throws {
        let memory = UsageQuotaMemoryPersistence()
        let store = UsageQuotaOverviewStore(persistence: memory)
        let reset = Self.now.addingTimeInterval(3 * 86400)
        for step in 0...72 {
            let capture = Self.now.addingTimeInterval(-10 * 3600 + Double(step) * 300)
            let account = Self.account(
                capturedAt: capture, windows: [Self.window(used: 10, minutes: 10080, reset: reset)])
            store.reconcile(accounts: [account], now: capture)
        }
        let current = Self.account(windows: [Self.window(used: 10, minutes: 10080, reset: reset)])
        store.reconcile(accounts: [current], now: Self.now)
        let archive = try JSONDecoder().decode(UsageQuotaArchive.self, from: #require(memory.data))
        let observations = try #require(archive.histories.first).observations
        #expect(observations.count >= 4)
        let first = try #require(observations.first)
        let latest = try #require(observations.last)
        #expect(latest.capturedAt.timeIntervalSince(first.capturedAt) >= 6 * 3600)
        #expect(zip(observations, observations.dropFirst()).contains {
            $1.capturedAt.timeIntervalSince($0.capturedAt) > 2 * 3600
        })
        let line = try #require(store.overview(accounts: [current], now: Self.now).lines.first)
        #expect(line.projectionKind == .uniformMean)
    }

    @Test
    func `an old gap does not suppress a newer complete contiguous observation span`() throws {
        let memory = UsageQuotaMemoryPersistence()
        let store = UsageQuotaOverviewStore(persistence: memory)
        let reset = Self.now.addingTimeInterval(3 * 86400)
        func record(_ capture: Date) {
            let account = Self.account(
                capturedAt: capture, windows: [Self.window(used: 10, minutes: 10080, reset: reset)])
            store.reconcile(accounts: [account], now: capture)
        }
        // Keep an older three-hour gap in the archive, followed by six complete hours
        // of direct five-minute observations. The newer period is sufficient on its own.
        for step in 0...12 {
            record(Self.now.addingTimeInterval(-10 * 3600 + Double(step) * 300))
        }
        for step in 0...72 {
            record(Self.now.addingTimeInterval(-6 * 3600 + Double(step) * 300))
        }
        let archive = try JSONDecoder().decode(UsageQuotaArchive.self, from: #require(memory.data))
        let observations = try #require(archive.histories.first).observations
        #expect(zip(observations, observations.dropFirst()).contains {
            $1.capturedAt.timeIntervalSince($0.capturedAt) > 2 * 3600
        })
        let current = Self.account(windows: [Self.window(used: 10, minutes: 10080, reset: reset)])
        let line = try #require(store.overview(accounts: [current], now: Self.now).lines.first)
        #expect(line.projectionKind == .observedPattern)
        #expect(line.estimatedSamples.first?.date == Self.now)
        #expect(line.estimatedSamples.allSatisfy { $0.remainingPercent == 90 })
    }

    @Test
    func `observation stream capacity stays bounded and protects selected bindings`() throws {
        let memory = UsageQuotaMemoryPersistence()
        let store = UsageQuotaOverviewStore(persistence: memory)
        let accounts = (0..<70).map { Self.account(id: "fictional-\($0)", record: "fictional-record-\($0)") }
        store.reconcile(accounts: accounts, now: Self.now)
        let archive = try JSONDecoder().decode(UsageQuotaArchive.self, from: #require(memory.data))
        #expect(archive.histories.count == UsageQuotaOverviewStore.maximumHistoryStreams)
        let savedBindings = Set(archive.histories.map(\.binding))
        #expect(store.preferences.selections.allSatisfy { savedBindings.contains($0.binding) })
    }

    @Test
    func `new source metadata does not wash an old quota observation fresh`() throws {
        let store = UsageQuotaOverviewStore.inMemory()
        let old = Self.now.addingTimeInterval(-7 * 3600)
        var account = Self.account(capturedAt: Self.now)
        account.sourceReport = SyncProviderSourceReport(
            sourceDeviceID: "fictional-mac", sourceDeviceName: "Fictional Mac", sourceCapturedAt: old,
            failures: [], deviceCount: 2)
        let source = SyncedUsageSnapshot(
            providers: [Self.account(capturedAt: old)], syncTimestamp: Self.now,
            deviceName: "Fictional Mac", deviceID: "fictional-mac")
        store.reconcile(accounts: [account], sourceSnapshots: [source], now: Self.now)
        let line = try #require(store.overview(accounts: [account], now: Self.now).lines.first)
        #expect(line.observedAt == old)
        #expect(line.state == .stale)
        #expect(line.projectionKind == .none)
        #expect(line.estimatedSamples.isEmpty)
        #expect(line.currentRemainingPercent == 80)
    }

    @Test
    func `reset rollover duration change and decreasing observations start separate segments`() {
        let store = Self.sampledStore()
        let newTime = Self.now.addingTimeInterval(60)
        let longer = Self.account(capturedAt: newTime, windows: [Self.window(used: 35, minutes: 600)])
        store.reconcile(accounts: [longer], now: newTime)
        #expect(store.overview(accounts: [longer], now: newTime).lines.first?.localObservationCount == 1)
        let resetTime = Self.now.addingTimeInterval(120)
        let rolled = Self.account(capturedAt: resetTime, windows: [Self.window(
            used: 2, minutes: 600, reset: Self.now.addingTimeInterval(36000))])
        store.reconcile(accounts: [rolled], now: resetTime)
        #expect(store.overview(accounts: [rolled], now: resetTime).lines.first?.localObservationCount == 1)
        let correctionTime = Self.now.addingTimeInterval(180)
        let correction = Self.account(capturedAt: correctionTime, windows: [Self.window(
            used: 1, minutes: 600, reset: Self.now.addingTimeInterval(36000))])
        store.reconcile(accounts: [correction], now: correctionTime)
        #expect(store.overview(accounts: [correction], now: correctionTime).lines.first?.localObservationCount == 1)
    }

    @Test
    func `two accounts never inherit each others local observed pattern`() throws {
        let store = Self.sampledStore()
        let first = Self.account(windows: [Self.window(used: 30)])
        let other = Self.account(id: "fictional-b", record: "install-b", windows: [Self.window(used: 45)])
        store.reconcile(accounts: [first, other], now: Self.now)
        let candidate = try #require(store.catalog(accounts: [first, other]).first {
            $0.accountAnchorID != store.preferences.selections.first?.accountAnchorID
        })
        #expect(store.add(candidate))
        let lines = store.overview(accounts: [first, other], now: Self.now).lines
        #expect(lines[0].projectionKind == .observedPattern)
        #expect(lines[1].localObservationCount == 1)
        #expect(lines[1].projectionKind == .uniformMean)
        #expect(lines[1].currentRemainingPercent == 55)
    }

    @Test
    func `linked accounts do not mix samples and unmerge preserves original binding`() throws {
        let store = Self.sampledStore()
        let first = Self.account(windows: [Self.window(used: 30)])
        let other = Self.account(id: "fictional-b", record: "install-b", windows: [Self.window(used: 55)])
        store.reconcile(accounts: [first, other], now: Self.now)
        let link = ProviderAccountLinkage(
            providerID: "claude", linkedIdentifiers: ["claude:account:fictional-a", "claude:account:fictional-b"],
            confirmedFromDeviceID: "fictional-phone")
        store.reconcile(accounts: [other], linkages: [link], now: Self.now)
        let linked = try #require(store.overview(accounts: [other], now: Self.now).lines.first)
        #expect(linked.projectionKind == .uniformMean)
        #expect(linked.localObservationCount == 0)
        store.reconcile(
            accounts: [other],
            linkages: [link, link.inverseUnmerge(confirmedFromDeviceID: "fictional-phone")],
            now: Self.now)
        #expect(store.overview(accounts: [other], now: Self.now).lines.first?.state == .missingAccount)
        store.reconcile(accounts: [first, other], now: Self.now)
        #expect(store.overview(accounts: [first, other], now: Self.now).lines.first?.localObservationCount == 9)
    }

    @Test
    func `combined stable identities cannot reuse a matching old account pattern by timestamp coincidence`() throws {
        let store = Self.sampledStore()
        let first = Self.account(windows: [Self.window(used: 30)])
        let other = Self.account(id: "fictional-b", record: "install-b", windows: [Self.window(used: 55)])
        store.reconcile(accounts: [first, other], now: Self.now)
        let combined = Self.account(
            windows: [Self.window(used: 30)],
            identities: ["claude:account:fictional-a", "claude:account:fictional-b"])
        store.reconcile(accounts: [combined], now: Self.now)
        let line = try #require(store.overview(accounts: [combined], now: Self.now).lines.first)
        #expect(line.localObservationCount == 0)
        #expect(line.projectionKind == .uniformMean)
        store.reconcile(accounts: [first, other], now: Self.now)
        #expect(store.overview(accounts: [first, other], now: Self.now).lines.first?.localObservationCount == 9)
    }

    @Test
    func `identity record flip preserves selection while an unrelated reused slot cannot rebind it`() throws {
        let store = UsageQuotaOverviewStore.inMemory()
        store.reconcile(accounts: [Self.account()], now: Self.now)
        let original = try #require(store.preferences.selections.first)
        let flipped = Self.account(record: "other-mac-install")
        store.reconcile(accounts: [flipped], now: Self.now)
        #expect(store.preferences.selections.first?.id == original.id)
        #expect(store.overview(accounts: [flipped], now: Self.now).lines.first?.state == .available)
        let unrelated = Self.account(id: "unrelated", record: "install-a")
        store.reconcile(accounts: [unrelated], now: Self.now)
        #expect(store.overview(accounts: [unrelated], now: Self.now).lines.first?.state == .missingAccount)
    }

    @Test
    func `calendar range includes unselected available windows and does not jump after removing a line`() throws {
        let near = Self.now.addingTimeInterval(3600)
        let far = Self.now.addingTimeInterval(3 * 86400)
        let account = Self.account(windows: [
            Self.window(reset: near),
            Self.window(id: "secondary", minutes: 10080, reset: far),
        ])
        let store = UsageQuotaOverviewStore.inMemory()
        store.reconcile(accounts: [account], now: Self.now)
        let overview = store.overview(accounts: [account], now: Self.now)
        #expect(overview.start == Self.now)
        #expect(overview.end == far)
        let nearLine = try #require(overview.lines.first { $0.selection.windowID == "primary" })
        let farLine = try #require(overview.lines.first { $0.selection.windowID == "secondary" })
        #expect(nearLine.estimatedSamples.last?.date == near)
        #expect(farLine.estimatedSamples.last?.date == far)
        #expect(overview.lines.allSatisfy { line in line.estimatedSamples.allSatisfy { $0.date <= line.resetDate! } })
        store.remove(id: farLine.id)
        let withoutFarLine = store.overview(accounts: [account], now: Self.now)
        #expect(withoutFarLine.end == far)
        #expect(withoutFarLine.lines.count == 1)
        #expect(withoutFarLine.lines.first?.selection.windowID == "primary")
    }

    @Test
    func `future curve starts at visible current quota and stops at estimated exhaustion`() throws {
        let account = Self.account(
            capturedAt: Self.now.addingTimeInterval(-1800),
            windows: [Self.window(used: 80, reset: Self.now.addingTimeInterval(3 * 3600))])
        let store = UsageQuotaOverviewStore.inMemory()
        store.reconcile(accounts: [account], now: Self.now)
        let line = try #require(store.overview(accounts: [account], now: Self.now).lines.first)
        #expect(line.currentRemainingPercent == 20)
        #expect(line.estimatedSamples.first?.date == Self.now)
        #expect(line.estimatedSamples.first?.remainingPercent == 20)
        #expect(line.observedAt == Self.now.addingTimeInterval(-1800))
        let empty = try #require(line.estimatedDepletionAt)
        #expect(empty < line.resetDate!)
        #expect(line.estimatedSamples.last?.date == empty)
        #expect(line.estimatedSamples.last?.remainingPercent == 0)
        #expect(line.estimatedSamples.filter { $0.date > empty }.isEmpty)
    }

    @Test
    func `unknown blocked and stale windows cannot extend the calendar domain`() {
        let near = Self.now.addingTimeInterval(3600)
        let far = Self.now.addingTimeInterval(30 * 86400)
        let valid = Self.account(windows: [
            Self.window(reset: near),
            Self.window(id: "unknown", reset: far, known: false),
            Self.window(id: "blocked", reset: far, blocked: true),
        ])
        let stale = Self.account(
            id: "stale",
            record: "stale-install",
            capturedAt: Self.now.addingTimeInterval(-7 * 3600),
            windows: [Self.window(reset: far)])
        let store = UsageQuotaOverviewStore.inMemory()
        store.reconcile(accounts: [valid, stale], now: Self.now)
        #expect(store.overview(accounts: [valid, stale], now: Self.now).end == near)
    }

    @Test
    func `missing duration is not given a fictitious curve and known zero is not unknown`() throws {
        let store = UsageQuotaOverviewStore.inMemory()
        let account = Self.account(windows: [Self.window(used: 0, minutes: nil)])
        store.reconcile(accounts: [account], now: Self.now)
        let line = try #require(store.overview(accounts: [account], now: Self.now).lines.first)
        #expect(line.state == .available)
        #expect(line.currentRemainingPercent == 100)
        #expect(line.projectionKind == .none && line.estimatedSamples.isEmpty)
        let unknown = Self.account(windows: [Self.window(used: 0, known: false)])
        #expect(store.overview(accounts: [unknown], now: Self.now).lines.first?.currentRemainingPercent == nil)
        let expired = Self.account(windows: [Self.window(reset: Self.now.addingTimeInterval(-1))])
        #expect(store.overview(accounts: [expired], now: Self.now).lines.first?.state == .resetPassed)
        let blocked = Self.account(windows: [Self.window(blocked: true)])
        #expect(store.overview(accounts: [blocked], now: Self.now).lines.first?.state == .blocked)
    }

    @Test
    func `local samples persist but repeated reads and duplicate syncs do not manufacture observations`() throws {
        let memory = UsageQuotaMemoryPersistence()
        let store = UsageQuotaOverviewStore(persistence: memory)
        let account = Self.account()
        store.reconcile(accounts: [account], now: Self.now)
        let writes = memory.writes
        store.reconcile(accounts: [account], now: Self.now.addingTimeInterval(60))
        #expect(memory.writes == writes)
        _ = store.overview(accounts: [account], now: Self.now.addingTimeInterval(120))
        #expect(memory.writes == writes)
        let reopened = UsageQuotaOverviewStore(persistence: memory)
        let line = try #require(reopened.overview(accounts: [account], now: Self.now).lines.first)
        #expect(line.localObservationCount == 1)
    }

    @Test
    func `demo fixture is deterministic and cannot seed live persistence`() throws {
        let account = Self.account(windows: [Self.window(used: 30)])
        let live = UsageQuotaOverviewStore(persistence: UsageQuotaMemoryPersistence())
        live.reconcile(accounts: [account], now: Self.now)
        let demo1 = UsageQuotaOverviewStore.demo(accounts: [account], now: Self.now)
        let demo2 = UsageQuotaOverviewStore.demo(accounts: [account], now: Self.now)
        let first = try #require(demo1.overview(accounts: [account], now: Self.now).lines.first)
        let second = try #require(demo2.overview(accounts: [account], now: Self.now).lines.first)
        #expect(first.projectionKind == .observedPattern)
        #expect(first.estimatedSamples == second.estimatedSamples)
        #expect(live.overview(accounts: [account], now: Self.now).lines.first?.localObservationCount == 1)
    }

    @Test
    func `future and corrupt archives are readonly and preserved verbatim`() throws {
        var future = UsageQuotaArchive()
        future.preferences.schemaVersion = 999
        for data in try [Data("invalid json".utf8), JSONEncoder().encode(future)] {
            let memory = UsageQuotaMemoryPersistence(data: data)
            let store = UsageQuotaOverviewStore(persistence: memory)
            #expect(store.isReadOnly)
            store.reconcile(accounts: [Self.account()], now: Self.now)
            #expect(store.preferences.selections.isEmpty)
            #expect(memory.data == data)
            #expect(memory.writes == 0)
        }
    }
}

@MainActor
private final class UsageQuotaMemoryPersistence: UsageQuotaPersistence {
    var data: Data?
    var writes = 0
    init(data: Data? = nil) { self.data = data }
    func load() -> Data? { self.data }
    func save(_ data: Data) { self.data = data; self.writes += 1 }
}
