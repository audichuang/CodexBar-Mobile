import Foundation
import SwiftUI
import UIKit
import WidgetKit
import XCTest
@testable import CodexBarMobile

@MainActor
final class WidgetQuotaForecastTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func session(used: Double?, resetIn hours: Double, capturedAgo: TimeInterval = 0) -> WidgetQuotaForecast? {
        WidgetQuotaForecast(
            usedPercent: used,
            resetsAt: self.now.addingTimeInterval(hours * 3600),
            windowMinutes: 300,
            capturedAt: self.now.addingTimeInterval(-capturedAgo),
            now: self.now)
    }

    private func account(
        _ label: String,
        session: Double? = nil,
        sessionResetIn: Double = 2.5,
        weekly: Double = 10,
        isError: Bool = false) -> CodexBarWidgetProviderSummary
    {
        CodexBarWidgetProviderSummary(
            id: "claude|\(label)",
            providerName: "Claude",
            providerID: "claude",
            loginMethod: nil,
            usagePercent: nil,
            todayCostUSD: nil,
            thirtyDayCostUSD: nil,
            tokensToday: nil,
            isError: isError,
            statusMessage: nil,
            lastUpdated: self.now,
            weeklyResetsAt: self.now.addingTimeInterval(3.5 * 86400),
            weeklyUsedPercent: weekly,
            accountLabel: label,
            sessionUsedPercent: session,
            sessionResetsAt: session.map { _ in self.now.addingTimeInterval(sessionResetIn * 3600) },
            sessionWindowMinutes: 300)
    }

    // MARK: Forecast

    func testFastSessionRunsOutBeforeReset() {
        // 60% in the first 2.5 h of 5 h: the last 40% lasts 1 h 40 min.
        XCTAssertEqual(
            self.session(used: 60, resetIn: 2.5)?.outcome,
            .runsOut(self.now.addingTimeInterval(100 * 60)))
    }

    func testSlowSessionLastsUntilReset() {
        XCTAssertEqual(self.session(used: 30, resetIn: 2.5)?.outcome, .lasts)
        XCTAssertEqual(self.session(used: 0, resetIn: 2.5)?.outcome, .lasts)
    }

    func testFullWindowIsUsedUpEvenRightAfterItStarts() {
        XCTAssertEqual(self.session(used: 100, resetIn: 4.99)?.outcome, .usedUp)
    }

    func testBrandNewWindowHasNoForecast() {
        // 5% in the first 6 minutes would otherwise predict running out in 2 hours.
        XCTAssertNil(self.session(used: 5, resetIn: 4.9))
    }

    func testNoForecastWithoutUsableInputs() {
        XCTAssertNil(self.session(used: nil, resetIn: 2))
        XCTAssertNil(self.session(used: .nan, resetIn: 2))
        XCTAssertNil(self.session(used: 50, resetIn: -1))
        // An observation older than the window it would be projected onto.
        XCTAssertNil(self.session(used: 50, resetIn: 2, capturedAgo: 6 * 3600))
    }

    func testProjectionStartsAtTheMacsObservationNotThePhonesClock() {
        // Observed 60 min ago at 60% with 3.5 h left then, so 1.5 h elapsed:
        // the last 40% lasts 1 h from that observation, which is right now.
        XCTAssertEqual(
            self.session(used: 60, resetIn: 2.5, capturedAgo: 3600)?.outcome,
            .runsOut(self.now))
    }

    func testRiskTextSaysWhenAndHandlesAProjectionAlreadyPast() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Taipei"))
        let locale = Locale(identifier: "en_US_POSIX")
        let today = try XCTUnwrap(self.session(used: 60, resetIn: 2.5))
        let clock = try XCTUnwrap(today.riskText(now: self.now, calendar: calendar, locale: locale))
        XCTAssertEqual(clock, String(format: String(localized: "Out %@"), "17:40"))

        XCTAssertEqual(
            self.session(used: 60, resetIn: 2.5, capturedAgo: 2 * 3600)?.riskText(now: self.now),
            String(localized: "Likely used up"))
        XCTAssertEqual(self.session(used: 100, resetIn: 2)?.riskText(now: self.now), String(localized: "Used up"))
        XCTAssertNil(self.session(used: 10, resetIn: 2)?.riskText(now: self.now))
    }

    // MARK: Ranking

    func testAccountsRankByWhoRunsOutFirstThenFullnessWithErrorsLast() {
        let accounts = [
            self.account("a-idle", session: 10),
            self.account("b-broken", session: 99, isError: true),
            self.account("c-busy", session: 45),
            self.account("d-soon", session: 80),
            self.account("e-later", session: 60),
            self.account("f-out", session: 100),
        ]
        let ranked = WidgetProviderSelection.accountsByUrgency(from: accounts, selected: nil, now: self.now)
        XCTAssertEqual(
            ranked.compactMap(\.accountLabel),
            ["f-out", "d-soon", "e-later", "c-busy", "a-idle", "b-broken"])
    }

    func testUrgentAccountSurvivesTruncationThatAlphabeticalOrderWouldCut() {
        let accounts = ["a", "b", "c"].map { self.account($0, session: 10) } + [self.account("z", session: 90)]
        let ranked = WidgetProviderSelection.accountsByUrgency(from: accounts, selected: nil, now: self.now)
        XCTAssertEqual(ranked.first?.accountLabel, "z")
    }

    func testSuggestsTheEmptiestAccountThatLasts() {
        let ranked = WidgetProviderSelection.accountsByUrgency(
            from: [
                self.account("full", session: 80),
                self.account("half", session: 45),
                self.account("idle", session: 10),
            ],
            selected: nil,
            now: self.now)
        XCTAssertEqual(WidgetProviderSelection.accountToSwitchTo(from: ranked, now: self.now)?.accountLabel, "idle")
    }

    func testNoSuggestionWhenNothingIsWrongOrNothingIsBetter() {
        let calm = WidgetProviderSelection.accountsByUrgency(
            from: [self.account("a", session: 10), self.account("b", session: 20)],
            selected: nil,
            now: self.now)
        XCTAssertNil(WidgetProviderSelection.accountToSwitchTo(from: calm, now: self.now))

        let allBad = WidgetProviderSelection.accountsByUrgency(
            from: [self.account("a", session: 80), self.account("b", session: 90)],
            selected: nil,
            now: self.now)
        XCTAssertNil(WidgetProviderSelection.accountToSwitchTo(from: allBad, now: self.now))

        let onlyBrokenOther = WidgetProviderSelection.accountsByUrgency(
            from: [self.account("a", session: 80), self.account("b", session: 5, isError: true)],
            selected: nil,
            now: self.now)
        XCTAssertNil(WidgetProviderSelection.accountToSwitchTo(from: onlyBrokenOther, now: self.now))
    }

    // MARK: Freshness and ticking

    func testFreshnessWarnsOnlyAfterAnHour() {
        XCTAssertFalse(WidgetFreshnessText.isOld(self.now.addingTimeInterval(-3599), now: self.now))
        XCTAssertTrue(WidgetFreshnessText.isOld(self.now.addingTimeInterval(-3601), now: self.now))
        XCTAssertEqual(
            WidgetFreshnessText.text(since: self.now.addingTimeInterval(-30), now: self.now),
            String(localized: "just now"))
    }

    func testTimelineEntriesAdvanceAndKeepTheSameData() {
        let entry = CodexBarWidgetEntry(
            date: self.now,
            configuration: .init(mode: .overview),
            snapshot: .accountsPreview(now: self.now),
            accountChoice: "claude|Work")
        let entries = entry.ticking(until: 15 * 60)
        XCTAssertEqual(entries.map(\.date), [0, 300, 600].map { self.now.addingTimeInterval($0) })
        XCTAssertTrue(entries.allSatisfy { $0.snapshot == entry.snapshot && $0.accountChoice == "claude|Work" })
    }

    // MARK: Rendering

    func testAccessoryLayoutsRender() throws {
        let families: [(WidgetFamily, CGSize)] = [
            (.accessoryRectangular, .init(width: 172, height: 76)),
            (.accessoryCircular, .init(width: 76, height: 76)),
            (.accessoryInline, .init(width: 234, height: 26)),
        ]
        let snapshot = CodexBarWidgetSnapshot.accountsPreview(now: self.now)
        for (family, size) in families {
            let view = ProviderQuotaAccessoryView(
                entry: .init(
                    date: self.now,
                    configuration: .init(mode: .overview),
                    snapshot: snapshot,
                    accountChoice: "claude|Personal"),
                family: family)
                .frame(width: size.width, height: size.height)
                .background(Color.white)
            try self.render(view, name: "Accessory-\(family)", width: size.width)
        }
    }

    func testAccountWidgetsRenderForEachFamilyAndScheme() throws {
        let snapshot = CodexBarWidgetSnapshot.accountsPreview(now: self.now)
        let entry = CodexBarWidgetEntry(date: self.now, configuration: .init(mode: .overview), snapshot: snapshot)
        let families: [(WidgetFamily, CGSize)] = [
            (.systemSmall, .init(width: 170, height: 170)),
            (.systemMedium, .init(width: 364, height: 170)),
            (.systemLarge, .init(width: 364, height: 382)),
        ]
        for scheme in [ColorScheme.light, .dark] {
            for (family, size) in families {
                let view = AccountsWidgetView(entry: entry, previewFamily: family)
                    .environment(\.colorScheme, scheme)
                    .frame(width: size.width, height: size.height)
                    .background(scheme == .dark ? Color.black : Color.white)
                try self.render(view, name: "Accounts-\(family)-\(scheme)", width: size.width)
            }
            let provider = ProviderQuotaWidgetView(
                entry: .init(
                    date: self.now,
                    configuration: .init(mode: .overview),
                    snapshot: snapshot,
                    accountChoice: "claude|Personal"))
                .environment(\.colorScheme, scheme)
                .frame(width: 170, height: 170)
                .background(scheme == .dark ? Color.black : Color.white)
            try self.render(provider, name: "Provider-\(scheme)", width: 170)
        }
    }

    private func render(_ view: some View, name: String, width: CGFloat) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        XCTAssertEqual(image.size.width, width)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }
}
