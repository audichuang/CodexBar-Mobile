import CodexBarSync
import SwiftUI
import WidgetKit
import XCTest
@testable import CodexBarMobile

@MainActor
final class WidgetProviderSelectionTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testAutomaticDefaultsAndExplicitSelection() {
        let providers = CodexBarWidgetSnapshot.placeholder(now: self.now).topProviders
        XCTAssertEqual(
            WidgetProviderSelection.resolve(from: providers, selected: nil, family: .systemSmall, now: self.now).count,
            2)
        XCTAssertEqual(
            WidgetProviderSelection.resolve(from: providers, selected: [], family: .systemMedium, now: self.now).count,
            4)
        let selected = [
            WidgetProviderEntity(id: "claude", name: "Claude"),
            WidgetProviderEntity(id: "codex", name: "Codex"),
        ]
        XCTAssertEqual(
            WidgetProviderSelection.resolve(from: providers, selected: selected, family: .systemLarge, now: self.now)
                .map(\.providerID),
            ["claude", "codex"])
        XCTAssertEqual(
            WidgetProviderSelection
                .resolve(from: providers, selected: selected + selected, family: .systemSmall, now: self.now).count,
            2)
    }

    func testSelectionCapsAtFourAndThreeSmallItemsUseTwoColumns() {
        let providers = CodexBarWidgetSnapshot.placeholder(now: self.now).topProviders
        let selected = providers.map { WidgetProviderEntity(id: $0.providerID, name: $0.providerName) }
            + [WidgetProviderEntity(id: "fifth", name: "Fifth")]
        let result = WidgetProviderSelection.resolve(
            from: providers,
            selected: selected,
            family: .systemSmall,
            now: self.now)
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result.map(\.providerID), Array(selected.prefix(4)).map(\.id))
        XCTAssertEqual(WidgetProviderSelection.columns(count: 3, family: .systemSmall), 2)
        XCTAssertEqual(WidgetProviderSelection.columns(count: 2, family: .systemSmall), 1)
    }

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

    func testMissingProviderNeverSubstitutesAnotherProvider() {
        let providers = CodexBarWidgetSnapshot.placeholder(now: self.now).topProviders
        let result = WidgetProviderSelection.resolve(
            from: providers,
            selected: [.init(id: "missing", name: "Missing")],
            family: .systemMedium,
            now: self.now)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.providerID, "missing")
        XCTAssertNil(result.first?.usagePercent)
        XCTAssertNil(result.first?.resetsAt)
        XCTAssertEqual(result.first?.isError, true)
        XCTAssertEqual(result.first?.statusMessage, String(localized: "Unavailable"))
    }

    func testResetCountdownIsFractionalAndNeverNegative() {
        XCTAssertNil(WidgetProviderResetText.days(nil, now: self.now))
        XCTAssertEqual(
            WidgetProviderResetText.days(self.now.addingTimeInterval(3.7 * 86400), now: self.now),
            String(format: String(localized: "%@d"), "3.7"))
        XCTAssertEqual(
            WidgetProviderResetText.days(self.now.addingTimeInterval(0.6 * 86400), now: self.now),
            String(format: String(localized: "%@d"), "0.6"))
        XCTAssertEqual(
            WidgetProviderResetText.days(self.now.addingTimeInterval(60), now: self.now),
            String(localized: "<0.1d"))
        XCTAssertEqual(
            WidgetProviderResetText.days(self.now.addingTimeInterval(-1), now: self.now),
            String(localized: "Now"))
    }

    func testCatalogueExcludesProviderLevelManagementCostsLikeRenderedSnapshot() {
        let management = ProviderUsageSnapshot(
            providerID: "openrouter", providerName: "OpenRouter",
            primary: nil, secondary: nil, accountEmail: nil, loginMethod: nil,
            statusMessage: nil, isError: false, lastUpdated: self.now,
            accountRecordKey: ProviderUsageSnapshot.openRouterManagementCostRecordKey)
        let usage = ProviderUsageSnapshot(
            providerID: "codex", providerName: "Codex",
            primary: nil, secondary: nil, accountEmail: nil, loginMethod: nil,
            statusMessage: nil, isError: false, lastUpdated: self.now)
        XCTAssertTrue(WidgetActivityPublisher.catalogueEntities(from: [management]).isEmpty)
        let providers = [management, usage]
        let snapshot = SyncedUsageSnapshot(
            providers: providers, syncTimestamp: self.now, deviceName: "Fixture Mac", deviceID: "fixture")
        let catalogue = WidgetActivityPublisher.catalogueEntities(from: providers)
        let rendered = CodexBarWidgetSnapshotBuilder.makeSnapshot(from: [snapshot], now: self.now)
        XCTAssertEqual(catalogue.map(\.id), ["codex"])
        XCTAssertEqual(catalogue.map(\.id), rendered.topProviders.map(\.providerID))
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

    func testCatalogueClearsAuthoritativeEmptySyncAndPreservesTransientFailures() throws {
        for status in [SyncStatus.noData, .synced(ago: 0)] {
            XCTAssertEqual(WidgetActivityPublisher.catalogueUpdate(snapshot: nil, syncStatus: status), [])
        }
        for status in [SyncStatus.syncing, .error(message: "Fixture failure"), .incompatibleData] {
            XCTAssertNil(WidgetActivityPublisher.catalogueUpdate(snapshot: nil, syncStatus: status))
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-catalogue-clear-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("catalogue.json")
        try WidgetProviderCatalogue.write([.init(id: "codex", name: "Codex")], to: url)
        if let update = WidgetActivityPublisher.catalogueUpdate(snapshot: nil, syncStatus: .syncing) {
            try WidgetProviderCatalogue.write(update, to: url)
        }
        XCTAssertEqual(try WidgetProviderCatalogue.read(from: url).map(\.id), ["codex"])
        let cleared = try XCTUnwrap(WidgetActivityPublisher.catalogueUpdate(snapshot: nil, syncStatus: .noData))
        try WidgetProviderCatalogue.write(cleared, to: url)
        XCTAssertTrue(try WidgetProviderCatalogue.read(from: url).isEmpty)
    }

    func testUsageAndResetComeFromTheSameKnownWindow() {
        let firstReset = self.now.addingTimeInterval(86400)
        let secondReset = self.now.addingTimeInterval(3.7 * 86400)
        let provider = ProviderUsageSnapshot(
            providerID: "codex",
            providerName: "Codex",
            primary: SyncRateWindow(usedPercent: 20, windowMinutes: 300, resetsAt: firstReset, resetDescription: nil),
            secondary: SyncRateWindow(
                usedPercent: 70,
                windowMinutes: 10080,
                resetsAt: secondReset,
                resetDescription: nil),
            accountEmail: nil,
            loginMethod: nil,
            statusMessage: nil,
            isError: false,
            lastUpdated: now)
        let source = SyncedUsageSnapshot(
            providers: [provider],
            syncTimestamp: now,
            deviceName: "Fixture Mac",
            deviceID: "fixture")
        let summary = CodexBarWidgetSnapshotBuilder.makeSnapshot(from: [source], now: self.now).topProviders.first
        XCTAssertEqual(summary?.usagePercent, 70)
        XCTAssertEqual(summary?.resetsAt, secondReset)
    }

    func testLegacySummaryDecodesWithoutResetAndCatalogueRoundTrips() throws {
        let summary = CodexBarWidgetSnapshot.placeholder(now: self.now).topProviders[0]
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(summary)) as? [String: Any])
        object.removeValue(forKey: "resetsAt")
        let legacy = try JSONDecoder().decode(
            CodexBarWidgetProviderSummary.self,
            from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(legacy.resetsAt)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-catalogue-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("catalogue-\(UUID().uuidString).json")
        try WidgetProviderCatalogue.write(
            [.init(id: "codex", name: "Codex"), .init(id: "codex", name: "Codex")],
            to: url)
        XCTAssertEqual(try WidgetProviderCatalogue.read(from: url).map(\.id), ["codex"])
    }

    func testOverviewSelectionLayoutsRenderAndExport() throws {
        let snapshot = CodexBarWidgetSnapshot.placeholder(now: self.now)
        let choices = snapshot.topProviders.map { WidgetProviderEntity(id: $0.providerID, name: $0.providerName) }
        let families: [(WidgetFamily, CGSize)] = [
            (.systemSmall, .init(width: 158, height: 158)),
            (.systemMedium, .init(width: 338, height: 162)),
            (.systemLarge, .init(width: 338, height: 354)),
            (.systemExtraLarge, .init(width: 560, height: 274)),
        ]
        for (family, size) in families {
            for count in 1...4 {
                for scheme in [ColorScheme.light, .dark] {
                    for style in [CodexBarWidgetColorStyle.mono, .colorful] {
                        let view = CodexBarWidgetView(
                            entry: .init(
                                date: now,
                                configuration: .init(
                                    mode: .overview,
                                    colorStyle: style,
                                    providers: Array(choices.prefix(count))),
                                snapshot: snapshot),
                            previewFamily: family)
                            .environment(\.colorScheme, scheme)
                            .frame(width: size.width, height: size.height)
                            .background(scheme == .dark ? Color.black : Color.white)
                        let renderer = ImageRenderer(content: view)
                        renderer.scale = 2
                        let image = try XCTUnwrap(renderer.uiImage)
                        XCTAssertEqual(image.size.width, size.width)
                        let attachment = XCTAttachment(image: image)
                        attachment.name = "Overview-\(family)-\(count)-\(scheme)-\(style)"
                        attachment.lifetime = .keepAlways
                        add(attachment)
                    }
                }
            }
        }
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
                    try image.pngData()?.write(to: URL(fileURLWithPath: "\(directory)/ProviderQuota-\(name)-\(scheme).png"))
                }
            }
        }
    }
}
