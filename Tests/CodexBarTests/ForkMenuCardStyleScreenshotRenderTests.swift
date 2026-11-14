import AppKit
import CodexBarCore
import SwiftUI
import XCTest
@testable import CodexBar

/// Fork developer tool, skipped by default: renders production menu cards with synthetic usage in
/// light and dark appearance, to review the segmented meter and card typography.
///
/// Run with:
///   CODEXBAR_FORK_CARD_SCREENSHOT_DIR=/tmp/cards swift test --filter ForkMenuCardStyleScreenshotRenderTests
@MainActor
final class ForkMenuCardStyleScreenshotRenderTests: XCTestCase {
    private static let width: CGFloat = 320

    func test_renderMenuCards() throws {
        guard let dir = ProcessInfo.processInfo.environment["CODEXBAR_FORK_CARD_SCREENSHOT_DIR"] else {
            throw XCTSkip("Set CODEXBAR_FORK_CARD_SCREENSHOT_DIR to render menu card screenshots.")
        }
        let directory = URL(fileURLWithPath: NSString(string: dir).expandingTildeInPath, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for dark in [false, true] {
            let view = AnyView(Self.cards(dark: dark))
            let data = try XCTUnwrap(Self.pngData(for: view, dark: dark))
            let url = directory.appendingPathComponent(dark ? "cards-dark.png" : "cards-light.png")
            try data.write(to: url, options: .atomic)
            print("Wrote \(url.path)")
        }
        let extras: [(String, AnyView, Bool)] = [
            ("bars-states-dark", AnyView(Self.barStates(dark: true)), true),
            ("bars-states-light", AnyView(Self.barStates(dark: false)), false),
        ]
        for (name, view, dark) in extras {
            let data = try XCTUnwrap(Self.pngData(for: view, dark: dark))
            let url = directory.appendingPathComponent("\(name).png")
            try data.write(to: url, options: .atomic)
            print("Wrote \(url.path)")
        }
    }

    /// Normal, highlighted (selection background), markers, and stale rows of the bare meter.
    private static func barStates(dark: Bool) -> some View {
        let tint = Color(red: 0.84, green: 0.47, blue: 0.34)
        return VStack(alignment: .leading, spacing: 10) {
            UsageProgressBar(percent: 70, tint: tint, accessibilityLabel: "normal", pacePercent: 45)
            UsageProgressBar(percent: 70, tint: tint, accessibilityLabel: "highlighted", pacePercent: 45)
                .environment(\.menuItemHighlighted, true)
                .padding(4)
                .background(Color(nsColor: .selectedContentBackgroundColor))
            UsageProgressBar(
                percent: 55,
                tint: tint,
                accessibilityLabel: "markers",
                pacePercent: 30,
                warningMarkerPercents: [80],
                workdayMarkerPercents: [20, 40, 60],
                workdayTickAppearance: .highContrast)
            UsageProgressBar(
                percent: 40,
                tint: UsageMenuCardView.Model.staleProgressColor,
                accessibilityLabel: "stale",
                pacePercent: 60)
        }
        .padding(16)
        .frame(width: self.width)
        .background(self.background(dark: dark))
    }

    private static func cards(dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Claude: burning faster than the clock. Codex: comfortably behind it.
            UsageMenuCardView(model: self.model(.claude, session: 82, weekly: 41), width: self.width)
            Divider()
            UsageMenuCardView(model: self.model(.codex, session: 12, weekly: 30), width: self.width)
        }
        .frame(width: self.width)
        // Mirrors the hook in StatusItemController+MenuCardItems.swift, which these bare cards bypass.
        .fontDesign(.monospaced)
        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
        .background(self.background(dark: dark))
    }

    private static func background(dark: Bool) -> Color {
        Color(nsColor: .init(white: dark ? 0.14 : 0.97, alpha: 1))
    }

    private static func model(_ provider: UsageProvider, session: Double, weekly: Double) -> UsageMenuCardView.Model {
        let now = Date()
        let snapshot = UsageSnapshot(
            primary: .init(
                usedPercent: session,
                windowMinutes: 300,
                resetsAt: now.addingTimeInterval(2 * 3600),
                resetDescription: nil),
            secondary: .init(
                usedPercent: weekly,
                windowMinutes: 10080,
                resetsAt: now.addingTimeInterval(3 * 86400),
                resetDescription: nil),
            updatedAt: now)
        return UsageMenuCardView.Model.make(.init(
            provider: provider,
            metadata: ProviderDefaults.metadata[provider]!,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: provider == .claude ? "Max" : "Plus"),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: false,
            hidePersonalInfo: true,
            now: now))
    }

    private static func pngData(for view: AnyView, dark: Bool) -> Data? {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let hosting = NSHostingView(rootView: view)
        hosting.appearance = appearance
        let size = hosting.fittingSize
        guard size.width > 0, size.height > 0 else { return nil }
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        window.appearance = appearance
        window.contentView = hosting
        window.layoutIfNeeded()
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }
}
