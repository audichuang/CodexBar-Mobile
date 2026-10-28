import CodexBarSync
import SwiftUI
import XCTest
@testable import CodexBarMobile

/// Production views with synthetic billing/quota data; these do not publish to CloudKit.
@MainActor
final class V082RenderTests: XCTestCase {
    func testMonthlyTargetsAndNativeDetailPaceInFourLanguagesAndThemes() async throws {
        for language in ["en", "zh-Hans", "zh-Hant", "ja"] {
            for dark in [false, true] {
                try await self.capture(language: language, dark: dark, largeText: false)
            }
        }
        try await self.capture(language: "ja", dark: false, largeText: true)
    }

    private func capture(language: String, dark: Bool, largeText: Bool) async throws {
        let locale = Locale(identifier: language)
        let now = Date()
        let reset = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 4, to: now))
        let quota = SyncRateWindow(
            label: "Workspace allowance", usedPercent: 25, windowMinutes: 43200,
            resetsAt: reset, resetDescription: nil, quotaLimit: 1000, quotaUnit: "credits")
        let target = try XCTUnwrap(DailyAllowanceTarget(window: quota, now: now))
        let localizedTarget = target.text(locale: locale)
        XCTAssertFalse(localizedTarget.contains("%@"))
        if language != "en" { XCTAssertFalse(localizedTarget.contains("Daily target")) }
        let expected = MobileLocalizedString.value(
            "Expected usage: %@", defaultValue: "Expected usage: %@", locale: locale)
        if language != "en" { XCTAssertFalse(expected.contains("Expected usage")) }
        if language != "en" {
            XCTAssertNotEqual(
                ProviderDetailLocalization.localized("Other features", providerID: "kimi", locale: locale),
                "Other features")
        }

        let budget = SyncBudgetSnapshot(
            usedAmount: 12.5, limitAmount: 100, currencyCode: "USD", period: "This month",
            resetsAt: reset, observedAt: now)
        let details = SyncProviderDetailSection(title: "Monthly", rows: [
            .init(label: "Kimi Code", value: "25 / 100", progress: .init(used: 25, total: 100, expectedUsed: 40)),
            .init(label: "Other features", value: "5 / 100", progress: .init(used: 5, total: 100)),
        ])
        let expiredGift = SyncProviderDetailSection(title: "Bonus credits", rows: [
            .init(label: "Synthetic gift", value: "75% left", progress: .init(used: 0.25, total: 1),
                  expiresAt: now.addingTimeInterval(-60)),
        ])
        let content = VStack(alignment: .leading, spacing: 16) {
            UsageCardView(label: "Workspace allowance", window: quota, providerID: "synthetic-workspace")
            BudgetProgressView(budget: budget, providerID: "soniox")
            ProviderDetailsView(providerID: "kimi", sections: [details, expiredGift], tintColor: .blue)
            HStack {
                ForEach(["soniox", "traecn", "abliteration", "chatbox"], id: \.self) { providerID in
                    Text(providerID).font(.caption).foregroundStyle(ProviderColorPalette.color(for: providerID))
                }
            }
        }
        .padding(16).frame(width: 390)
        .background(dark ? Color.black : Color.white)
        .environment(\.locale, locale)
        .environment(\.colorScheme, dark ? .dark : .light)
        .environment(\.dynamicTypeSize, largeText ? .accessibility3 : .large)
        // UIKit-backed controls such as ProgressView need a real hosting window;
        // ImageRenderer substitutes unsupported-control placeholders.
        let size = CGSize(width: 390, height: largeText ? 1800 : 700)
        let controller = UIHostingController(rootView: content)
        let host = UIWindow(frame: CGRect(origin: .zero, size: size))
        host.overrideUserInterfaceStyle = dark ? .dark : .light
        host.rootViewController = controller
        host.isHidden = false
        defer { host.isHidden = true; host.rootViewController = nil }
        controller.view.frame = host.bounds
        try await Task.sleep(for: .milliseconds(500))
        controller.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            controller.view.drawHierarchy(in: host.bounds, afterScreenUpdates: true)
        }
        XCTAssertGreaterThan(image.size.height, 300)
        let attachment = XCTAttachment(image: image)
        attachment.name = "v082-monthly-pace-\(language)-\(dark ? "dark" : "light")-\(largeText ? "AX3" : "regular")"
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }
}
