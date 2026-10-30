import CodexBarSync
import SwiftUI
import WidgetKit
import XCTest
@testable import CodexBarMobile

@MainActor
extension WidgetProviderSelectionTests {
    func testAccountsShowEveryAccountOfOneProviderInLabelOrder() {
        func account(_ provider: String, _ label: String?) -> CodexBarWidgetProviderSummary {
            CodexBarWidgetProviderSummary(
                id: "\(provider)|\(label ?? "_")", providerName: provider.capitalized, providerID: provider,
                loginMethod: nil, usagePercent: 10, todayCostUSD: nil, thirtyDayCostUSD: nil, tokensToday: nil,
                isError: false, statusMessage: nil, lastUpdated: self.now, accountLabel: label)
        }
        let providers = [
            account("codex", "solo"),
            account("claude", "work"),
            account("claude", "Personal"),
            account("codex", "team"),
            account("claude", "side"),
        ]
        let automatic = WidgetProviderSelection.accounts(from: providers, selected: nil, count: 6, now: self.now)
        XCTAssertEqual(automatic.map(\.accountLabel), ["Personal", "side", "work"])

        let codex = WidgetProviderSelection.accounts(
            from: providers, selected: .init(id: "codex", name: "Codex"), count: 6, now: self.now)
        XCTAssertEqual(codex.map(\.accountLabel), ["solo", "team"])

        XCTAssertEqual(
            WidgetProviderSelection.accounts(from: providers, selected: nil, count: 2, now: self.now).count,
            2)

        let missing = WidgetProviderSelection.accounts(
            from: providers, selected: .init(id: "gemini", name: "Gemini"), count: 3, now: self.now)
        XCTAssertEqual(missing.map(\.providerID), ["gemini"])
        XCTAssertEqual(missing.first?.isError, true)
        XCTAssertTrue(WidgetProviderSelection.accounts(from: [], selected: nil, count: 3, now: self.now).isEmpty)
        XCTAssertEqual(WidgetProviderSelection.columns(count: 3, family: .systemMedium), 3)
    }

    func testAccountLabelPrefersMacNameThenEmailLocalPartThenOrganization() {
        let label = CodexBarWidgetSnapshotBuilder.accountLabel
        XCTAssertEqual(label(" la ", "someone@example.com", "Org"), "la")
        XCTAssertEqual(label("someone@example.com", nil, nil), "someone")
        XCTAssertEqual(label(" ", " someone@example.com ", "Org"), "someone")
        XCTAssertEqual(label(nil, "Team key", nil), "Team key")
        XCTAssertEqual(label(nil, "", "Acme"), "Acme")
        XCTAssertNil(label(nil, nil, " "))
    }

    func testSessionIsTheShortestWindowUnderADayAndRestartsAfterItsReset() {
        func window(_ minutes: Int?, used: Double, resetsIn hours: Double?) -> SyncRateWindow {
            SyncRateWindow(
                usedPercent: used,
                windowMinutes: minutes,
                resetsAt: hours.map { self.now.addingTimeInterval($0 * 3600) },
                resetDescription: nil)
        }
        let provider = ProviderUsageSnapshot(
            providerID: "claude",
            providerName: "Claude",
            primary: window(300, used: 40, resetsIn: 2),
            secondary: window(10080, used: 8, resetsIn: 100),
            accountEmail: nil,
            loginMethod: nil,
            statusMessage: nil,
            isError: false,
            lastUpdated: self.now)
        let session = CodexBarWidgetSnapshotBuilder.summary(for: provider, now: self.now)
        XCTAssertEqual(session.sessionUsedPercent, 40)
        XCTAssertEqual(session.sessionWindowMinutes, 300)
        XCTAssertNotNil(session.sessionResetsAt)
        XCTAssertEqual(session.weeklyUsedPercent, 8)

        let expired = ProviderUsageSnapshot(
            providerID: "claude",
            providerName: "Claude",
            primary: window(300, used: 90, resetsIn: -1),
            secondary: window(10080, used: 8, resetsIn: 100),
            accountEmail: nil,
            loginMethod: nil,
            statusMessage: nil,
            isError: false,
            lastUpdated: self.now)
        let idle = CodexBarWidgetSnapshotBuilder.summary(for: expired, now: self.now)
        XCTAssertEqual(idle.sessionUsedPercent, 0)
        XCTAssertNil(idle.sessionResetsAt)

        let weeklyOnly = ProviderUsageSnapshot(
            providerID: "codex",
            providerName: "Codex",
            primary: window(10080, used: 30, resetsIn: 50),
            secondary: nil,
            accountEmail: nil,
            loginMethod: nil,
            statusMessage: nil,
            isError: false,
            lastUpdated: self.now)
        XCTAssertNil(CodexBarWidgetSnapshotBuilder.summary(for: weeklyOnly, now: self.now).sessionUsedPercent)
    }

    func testCatalogueAccountKeysMatchRenderedSummaryIDs() {
        func account(_ email: String?, label: String?) -> ProviderUsageSnapshot {
            ProviderUsageSnapshot(
                providerID: "claude", providerName: "Claude",
                primary: nil, secondary: nil, accountEmail: email, loginMethod: nil,
                statusMessage: nil, isError: false, lastUpdated: self.now, accountLabel: label)
        }
        let providers = [account("work@example.com", label: "Work"), account("home@example.com", label: nil)]
        let snapshot = SyncedUsageSnapshot(
            providers: providers, syncTimestamp: self.now, deviceName: "Fixture Mac", deviceID: "fixture")
        let catalogue = WidgetProviderCatalogue.merged(WidgetActivityPublisher.catalogueEntities(from: providers))
        let rendered = CodexBarWidgetSnapshotBuilder.makeSnapshot(from: [snapshot], now: self.now)
        let choices = catalogue.flatMap { record in (record.accounts ?? []).map { "\(record.id)|\($0.key)" } }
        XCTAssertEqual(Set(choices), Set(rendered.topProviders.map(\.id)))
        XCTAssertEqual(catalogue.first?.accounts?.map(\.label), ["Work", "home"])
    }

    func testAccountsWidgetRendersEveryFamily() throws {
        let families: [(WidgetFamily, CGSize)] = [
            (.systemSmall, .init(width: 158, height: 158)),
            (.systemMedium, .init(width: 338, height: 158)),
            (.systemLarge, .init(width: 338, height: 354)),
        ]
        for (family, size) in families {
            for scheme in [ColorScheme.light, .dark] {
                let view = AccountsWidgetView(
                    entry: .init(
                        date: self.now,
                        configuration: .init(mode: .overview),
                        snapshot: .accountsPreview(now: self.now)),
                    previewFamily: family)
                    .environment(\.colorScheme, scheme)
                    .frame(width: size.width, height: size.height)
                    .background(scheme == .dark ? Color.black : Color.white)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertEqual(image.size.width, size.width)
                let attachment = XCTAttachment(image: image)
                attachment.name = "Accounts-\(family)-\(scheme)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testProviderQuotaWidgetShowsChosenAccountAndNamesIt() {
        let accounts = CodexBarWidgetSnapshot.sampleClaudeAccounts(now: self.now)
        let snapshot = CodexBarWidgetSnapshot.accountsPreview(now: self.now)
        func entry(_ choice: String?) -> CodexBarWidgetEntry {
            .init(date: self.now, configuration: .init(mode: .overview), snapshot: snapshot, accountChoice: choice)
        }
        XCTAssertEqual(WidgetProviderSelection.quotaAccount(for: entry(accounts[2].id))?.id, accounts[2].id)
        // No choice, or an account that is gone, follows the overview pick.
        let automatic = WidgetProviderSelection.quotaAccount(for: entry(nil))?.id
        XCTAssertNotNil(automatic)
        XCTAssertEqual(WidgetProviderSelection.quotaAccount(for: entry("claude|gone@example.com"))?.id, automatic)
        // Several accounts are named; a lone account is not.
        XCTAssertEqual(
            WidgetProviderSelection.quotaAccountName(of: accounts[2], in: accounts),
            accounts[2].accountLabel)
        XCTAssertNil(WidgetProviderSelection.quotaAccountName(of: accounts[2], in: [accounts[2]]))
    }

    func testProviderQuotaWidgetRendersBothLayouts() throws {
        let accounts = CodexBarWidgetSnapshot.sampleClaudeAccounts(now: self.now)
        // "Personal" has a session window; "Side" has only the weekly one.
        let cases: [(name: String, provider: CodexBarWidgetProviderSummary)] = [
            ("two-windows", accounts[1]),
            ("weekly-only", accounts[2]),
        ]
        for (name, provider) in cases {
            for scheme in [ColorScheme.light, .dark] {
                var snapshot = CodexBarWidgetSnapshot.accountsPreview(now: self.now)
                snapshot = CodexBarWidgetSnapshot(
                    state: .loaded,
                    generatedAt: snapshot.generatedAt,
                    latestSyncAt: self.now.addingTimeInterval(-480),
                    deviceCount: 1,
                    providerCount: accounts.count,
                    errorCount: 0,
                    todayCostUSD: nil,
                    thirtyDayCostUSD: nil,
                    todayTokens: nil,
                    maxUsagePercent: provider.usagePercent,
                    topProviders: accounts,
                    message: nil,
                    isStale: false)
                let view = ProviderQuotaWidgetView(
                    entry: .init(
                        date: self.now,
                        configuration: .init(mode: .overview),
                        snapshot: snapshot,
                        accountChoice: provider.id))
                    .environment(\.colorScheme, scheme)
                    .frame(width: 170, height: 170)
                    .background(scheme == .dark ? Color.black : Color.white)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertEqual(image.size.width, 170)
                let attachment = XCTAttachment(image: image)
                attachment.name = "ProviderQuota-\(name)-\(scheme)"
                attachment.lifetime = .keepAlways
                add(attachment)
                if let directory = ProcessInfo.processInfo.environment["CODEXBAR_RENDER_DIR"] {
                    try image.pngData()?
                        .write(to: URL(fileURLWithPath: "\(directory)/ProviderQuota-\(name)-\(scheme).png"))
                }
            }
        }
    }
}
