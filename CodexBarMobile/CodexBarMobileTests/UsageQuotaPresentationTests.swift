import CodexBarSync
import Foundation
import Testing
@testable import CodexBarMobile

@Suite("Quota overview private labels")
@MainActor
struct UsageQuotaPresentationTests {
    @Test
    func `collapsed labels preserve distinct metrics without unnecessary account words`() {
        let session = Self.line(anchor: "alpha", metric: "Session")
        let weekly = Self.line(anchor: "alpha", metric: "Weekly")
        let preferences = Self.preferences(lines: [session, weekly])
        let visible = [session, weekly]
        #expect(UsageQuotaPresentation.collapsedTitle(
            session, visibleLines: visible, providerName: "Claude", preferences: preferences,
            hidesPersonalInfo: false) == "Claude · Session")
        #expect(UsageQuotaPresentation.collapsedTitle(
            weekly, visibleLines: visible, providerName: "Claude", preferences: preferences,
            hidesPersonalInfo: false) == "Claude · Weekly")
    }

    @Test
    func `only colliding visible metrics receive stable compact account numbers`() {
        let first = Self.line(anchor: "alpha", metric: "Weekly")
        let second = Self.line(anchor: "beta", metric: "Weekly")
        var preferences = Self.preferences(lines: [first, second])
        for visible in [[first, second], [second, first]] {
            #expect(UsageQuotaPresentation.collapsedTitle(
                first, visibleLines: visible, providerName: "Claude", preferences: preferences,
                hidesPersonalInfo: false) == "Claude · Weekly · #1")
            #expect(UsageQuotaPresentation.collapsedTitle(
                second, visibleLines: visible, providerName: "Claude", preferences: preferences,
                hidesPersonalInfo: true) == "Claude · Weekly · #2")
        }
        preferences.selections.reverse()
        #expect(UsageQuotaPresentation.collapsedTitle(
            second, visibleLines: [first, second], providerName: "Claude", preferences: preferences,
            hidesPersonalInfo: true) == "Claude · Weekly · #2")
        #expect(
            UsageQuotaPresentation.collapsedTitle(
                first, visibleLines: [first], providerName: "Claude", preferences: preferences,
                hidesPersonalInfo: true) == "Claude · Weekly",
            "An account outside the two visible lines must not lengthen the collapsed title")
    }

    @Test
    func `compact labels redact both metric and provider text`() {
        let line = Self.line(anchor: "alpha", metric: "Quota owner@example.invalid")
        let title = UsageQuotaPresentation.collapsedTitle(
            line, visibleLines: [line], providerName: "Fictional support@example.invalid",
            preferences: Self.preferences(lines: [line]), hidesPersonalInfo: true)
        #expect(!title.contains("@"))
        #expect(title.contains("Fictional"))
        #expect(title.contains("Quota"))
    }

    @Test
    func `provider metric and account emails are redacted without collapsing two accounts`() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func account(_ id: String) -> ProviderUsageSnapshot {
            ProviderUsageSnapshot(
                providerID: "fictional", providerName: "Fictional support@example.invalid",
                primary: nil, secondary: nil, accountEmail: "\(id)@example.invalid", loginMethod: nil,
                statusMessage: nil, isError: false, lastUpdated: now,
                rateWindows: [SyncRateWindow(
                    id: "primary", label: "Quota owner@example.invalid", usedPercent: 20,
                    windowMinutes: 300, resetsAt: now.addingTimeInterval(3600), resetDescription: nil)],
                accountIdentities: ["fictional:account:\(id)"], accountRecordKey: "record-\(id)")
        }
        let accounts = [account("alpha"), account("beta")]
        let store = UsageQuotaOverviewStore.inMemory()
        store.reconcile(accounts: accounts, now: now)
        let candidates = store.catalog(accounts: accounts, now: now)
        for candidate in candidates
            where !store.preferences.selections.contains(where: { $0.binding == candidate.id })
        {
            #expect(store.add(candidate))
        }
        let lines = store.overview(accounts: accounts, now: now).lines
        #expect(lines.count == 2)
        let titles = lines.map {
            UsageQuotaPresentation.shortTitle(
                $0, providerName: "Fictional support@example.invalid", preferences: store.preferences,
                hidesPersonalInfo: true)
        }
        #expect(Set(titles).count == 2)
        #expect(titles.allSatisfy { !$0.contains("@") })
        let firstOrdinal = String(format: String(localized: "Account %lld"), Int64(1))
        let secondOrdinal = String(format: String(localized: "Account %lld"), Int64(2))
        #expect(titles[0].hasSuffix(firstOrdinal))
        #expect(titles[1].hasSuffix(secondOrdinal))
        for line in lines {
            let editorLabel = UsageQuotaPresentation.accountLabel(
                line.accountTitle, providerID: line.selection.providerID, anchorID: line.selection.accountAnchorID,
                preferences: store.preferences, candidates: candidates, hidesPersonalInfo: true)
            let legendLabel = UsageQuotaPresentation.accountLabel(
                line.accountTitle, providerID: line.selection.providerID, anchorID: line.selection.accountAnchorID,
                preferences: store.preferences, hidesPersonalInfo: true)
            #expect(editorLabel == legendLabel)
            #expect(!legendLabel.contains("@"))
        }
        // Reversing rows or losing the first account cannot renumber the second account.
        store.reconcile(accounts: [accounts[1]], now: now)
        let remaining = try #require(store.overview(accounts: [accounts[1]], now: now).lines.first {
            $0.selection.accountAnchorID == lines[1].selection.accountAnchorID
        })
        let remainingTitle = UsageQuotaPresentation.shortTitle(
            remaining, providerName: "Fictional support@example.invalid", preferences: store.preferences,
            candidates: candidates.reversed(), hidesPersonalInfo: true)
        #expect(remainingTitle == titles[1])
        #expect(UsageQuotaPresentation.visible("Contact support@example.invalid", hidesPersonalInfo: false)
            == "Contact support@example.invalid")
    }

    private static func preferences(lines: [UsageQuotaResolvedLine]) -> UsageQuotaPreferences {
        var preferences = UsageQuotaPreferences()
        preferences.accountAnchors = ["alpha", "beta"].map {
            UsageAccountAnchor(id: $0, providerID: "claude", tokens: ["fixture:\($0)"])
        }
        preferences.selections = lines.map(\.selection)
        return preferences
    }

    private static func line(anchor: String, metric: String) -> UsageQuotaResolvedLine {
        let selection = UsageQuotaSelection(
            providerID: "claude", accountAnchorID: anchor, windowID: metric,
            colorHex: "D18C47", accountTitle: "Fictional \(anchor)", metricTitle: metric)
        return UsageQuotaResolvedLine(
            selection: selection, provider: nil, accountTitle: selection.accountTitle,
            compactAccountTitle: nil, privateAccountTitle: nil, metricTitle: metric,
            state: .available, isStale: false, currentRemainingPercent: 80,
            observedAt: nil, resetDate: nil, estimatedSamples: [], projectionKind: .none,
            estimatedDepletionAt: nil, localObservationCount: 0)
    }
}
