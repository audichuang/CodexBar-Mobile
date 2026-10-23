import CodexBarSync
import SwiftUI
import XCTest
@testable import CodexBarMobile

/// Native visual evidence for values absent from the demo's below-pace accounts.
/// These fixtures never enter the app's live or demo snapshots.
@MainActor
final class SummaryCardRenderTests: XCTestCase {
    func testMetricVariantsAtPhoneSidebarAndAccessibilitySizes() async throws {
        let now = Date()
        let window = SyncRateWindow(
            label: "Weekly", usedPercent: 80, windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(4 * 86400), resetDescription: nil)
        let account = ProviderUsageSnapshot(
            providerID: "claude", providerName: "Claude", primary: window, secondary: nil,
            accountEmail: "fictional@example.invalid",
            loginMethod: "Max 5x", statusMessage: nil, isError: false, lastUpdated: now,
            accountOrganization: "Personal")
        let store = SummaryPreferencesStore.inMemory()
        store.reconcile(accounts: [account], now: now)
        let catalog = store.catalog(accounts: [account], now: now)
        let quota = try XCTUnwrap(catalog.first {
            if case .quota = $0.metric {
                true
            } else {
                false
            }
        })
        let depletion = try XCTUnwrap(catalog.first {
            if case .depletion = $0.metric {
                true
            } else {
                false
            }
        })
        var countdown = quota.configuration()
        countdown.emphasis = .countdown
        countdown.color = .blue
        var forecast = depletion.configuration()
        forecast.color = .orange
        let forecastCard = store.resolve(forecast, accounts: [account], now: now)
        guard case let .emptyAt(date) = forecastCard.forecast else {
            return XCTFail("The synthetic above-pace window must yield a depletion date")
        }
        XCTAssertGreaterThan(date, now)
        XCTAssertLessThan(date, try XCTUnwrap(window.resetsAt))
        let cards = [
            store.resolve(quota.configuration(), accounts: [account], now: now),
            store.resolve(countdown, accounts: [account], now: now),
            forecastCard,
            SummaryResolvedCard(
                configuration: SummaryCardConfiguration(
                    accountAnchorID: "fictional-balance", providerID: "moonshot", metric: .balance),
                provider: nil, accountTitle: "Moonshot Personal", metricTitle: String(localized: "Balance"),
                state: .available, isStale: false, observedAt: now, window: nil, usedPercent: nil,
                resetDate: nil, forecast: nil,
                amount: SummaryCardAmount(value: 24.58, currencyCode: "USD", observedAt: now, isEstimated: false)),
        ]
        for (name, width, scheme, largeText) in [
            ("phone-light", CGFloat(390), ColorScheme.light, false),
            ("sidebar-dark", CGFloat(320), ColorScheme.dark, false),
            ("phone-accessibility", CGFloat(390), ColorScheme.light, true),
        ] {
            let size = CGSize(width: width, height: largeText ? 1000 : 620)
            let board = VStack(alignment: .leading, spacing: 10) {
                Text("Native card variants · synthetic data").font(.caption)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: largeText ? 1 : 2)) {
                    ForEach(cards) { card in SummaryMetricTile(card: card, now: now) }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color(.systemGroupedBackground))
            .environment(\.colorScheme, scheme)
            .environment(\.dynamicTypeSize, largeText ? .accessibility2 : .large)
            let controller = UIHostingController(rootView: board)
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.rootViewController = controller
            window.isHidden = false
            controller.view.frame = window.bounds
            try await Task.sleep(for: .seconds(1))
            controller.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(size: size).image { _ in
                controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            }
            _ = try XCTUnwrap(image.pngData())
            let attachment = XCTAttachment(image: image)
            attachment.name = "Synthetic Summary metric variants - " + name
            attachment.lifetime = .keepAlways
            self.add(attachment)
            window.isHidden = true
            window.rootViewController = nil
        }
    }
}
