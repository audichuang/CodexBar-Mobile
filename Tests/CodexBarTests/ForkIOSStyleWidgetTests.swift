import AppKit
import CodexBarCore
import Foundation
import SwiftUI
import Testing
import WidgetKit
@testable import CodexBarWidget

struct ForkIOSStyleWidgetModelTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func entry(
        _ provider: UsageProvider,
        primary: RateWindow? = nil,
        secondary: RateWindow? = nil,
        balance: String? = nil,
        today: Double? = nil) -> WidgetSnapshot.ProviderEntry
    {
        WidgetSnapshot.ProviderEntry(
            provider: provider,
            updatedAt: self.now,
            primary: primary,
            secondary: secondary,
            tertiary: nil,
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: today.map {
                WidgetSnapshot.TokenUsageSummary(
                    sessionCostUSD: $0, sessionTokens: nil, last30DaysCostUSD: $0 * 10, last30DaysTokens: nil)
            },
            dailyUsage: [],
            balanceText: balance)
    }

    @Test
    func `headline is the most constrained window`() {
        let summary = ForkProviderSummary(provider: .claude, entry: self.entry(
            .claude,
            primary: RateWindow(usedPercent: 59, windowMinutes: 300, resetsAt: self.now, resetDescription: nil),
            secondary: RateWindow(usedPercent: 89, windowMinutes: 10080, resetsAt: self.now, resetDescription: nil)))
        #expect(summary.headline?.usedPercent == 89)
        #expect(summary.balance == nil)
    }

    @Test
    func `balance-only providers show their balance, not a quota`() {
        let summary = ForkProviderSummary(provider: .deepseek, entry: self.entry(
            .deepseek,
            primary: RateWindow(usedPercent: 0, windowMinutes: nil, resetsAt: nil, resetDescription: "$14.60"),
            balance: "$14.60"))
        #expect(summary.headline == nil)
        #expect(summary.balance == "$14.60")
    }

    @Test
    func `providers follow enabled order and costs add up`() {
        let snapshot = WidgetSnapshot(
            entries: [
                self.entry(.codex, secondary: RateWindow(
                    usedPercent: 27, windowMinutes: 10080, resetsAt: self.now, resetDescription: nil), today: 2),
                self.entry(.claude, primary: RateWindow(
                    usedPercent: 10, windowMinutes: 300, resetsAt: self.now, resetDescription: nil), today: 3),
            ],
            enabledProviders: [.claude, .codex],
            generatedAt: self.now)
        #expect(ForkWidgetModel.providers(in: snapshot).map(\.provider) == [.claude, .codex])
        #expect(ForkWidgetModel.todayCost(snapshot) == 5)
        #expect(ForkWidgetModel.thirtyDayCost(snapshot) == 50)
    }
}

@MainActor
struct ForkIOSStyleWidgetRenderTests {
    @Test(arguments: [WidgetFamily.systemSmall, .systemMedium, .systemLarge], [ColorScheme.dark, .light])
    func `iPhone-style widgets render at macOS tile sizes`(family: WidgetFamily, scheme: ColorScheme) throws {
        let snapshot = Self.snapshot()
        let size = CGSize(width: family == .systemSmall ? 155 : 329, height: family == .systemLarge ? 345 : 155)
        let palette = ForkWidgetPalette(scheme: scheme)
        var views: [(String, AnyView)] = [(
            "overview",
            AnyView(ForkOverviewWidgetView(entry: ForkWidgetEntry(date: Date(), snapshot: snapshot), familyOverride: family)))]
        if family != .systemLarge {
            for provider in [UsageProvider.claude, .codex] {
                views.append((
                    "quota-\(provider.rawValue)",
                    AnyView(ForkProviderQuotaWidgetView(
                        entry: ForkWidgetEntry(date: Date(), snapshot: snapshot, provider: provider),
                        familyOverride: family))))
            }
        }
        for (name, view) in views {
            try WidgetLocalizationOverride.$language.withValue(Self.language) {
                let content = view
                    .environment(\.colorScheme, scheme)
                    .frame(width: size.width - 28, height: size.height - 28)
                    .padding(14)
                    .background(palette.background)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                let renderer = ImageRenderer(content: content)
                renderer.scale = 2
                let image = try #require(renderer.cgImage)
                #expect(image.width == Int(size.width * 2))
                if let dir = ProcessInfo.processInfo.environment["CODEXBAR_FORK_WIDGET_PROOF_DIR"] {
                    let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                    try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name)-\(family)-\(scheme).png"))
                }
            }
        }
    }

    private static var language: String {
        ProcessInfo.processInfo.environment["CODEXBAR_FORK_WIDGET_PROOF_LANG"] ?? "en"
    }

    /// A real snapshot file can be supplied for proof renders; tests otherwise use sample data.
    private static func snapshot() -> WidgetSnapshot {
        if let path = ProcessInfo.processInfo.environment["CODEXBAR_FORK_WIDGET_PROOF_SNAPSHOT"],
           let snapshot = WidgetSnapshotStore.load(from: URL(fileURLWithPath: path))
        {
            return snapshot
        }
        return ForkWidgetPreview.snapshot()
    }
}
