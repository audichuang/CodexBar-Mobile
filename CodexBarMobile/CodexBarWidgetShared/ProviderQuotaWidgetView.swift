import SwiftUI
import UIKit
import WidgetKit

/// The provider quota widget (`WidgetKinds.providerQuotaAppIntent`): one
/// provider's weekly window above its session window, each with its reset and
/// a segmented meter, over a faint copy of the provider's mark. A provider
/// without a session window shows the weekly one alone.
struct ProviderQuotaWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: CodexBarWidgetEntry

    var body: some View {
        Group {
            switch self.entry.snapshot.state {
            case .placeholder, .loaded:
                self.loadedView
            case .syncing:
                self.message(String(localized: "Syncing…"))
            case .noData, .error:
                self.message(String(localized: "No provider data"))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            ZStack(alignment: .bottomTrailing) {
                self.colorScheme == .dark ? Color.black : Color(red: 0.975, green: 0.975, blue: 0.97)
                if let provider = self.provider, let logo = Self.logo(for: provider.providerID) {
                    logo
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundStyle(self.primary.opacity(self.colorScheme == .dark ? 0.07 : 0.05))
                        .offset(x: 28, y: 22)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var provider: CodexBarWidgetProviderSummary? {
        WidgetProviderSelection.resolve(
            from: self.entry.snapshot.topProviders,
            selected: self.entry.configuration.providers,
            family: .systemSmall,
            now: self.entry.date).first
    }

    @ViewBuilder
    private var loadedView: some View {
        if let provider = self.provider {
            VStack(alignment: .leading, spacing: 0) {
                self.header(provider)
                if provider.isError {
                    Spacer(minLength: 0)
                    self.message(String(localized: "Unavailable"))
                    Spacer(minLength: 0)
                } else if provider.sessionUsedPercent != nil {
                    Spacer(minLength: 6)
                    self.weeklySection(provider, large: false)
                    Spacer(minLength: 8)
                    self.sessionSection(provider)
                } else {
                    Spacer(minLength: 6)
                    self.weeklySection(provider, large: true)
                    Spacer(minLength: 6)
                }
            }
        } else {
            self.message(String(localized: "No provider data"))
        }
    }

    // MARK: Sections

    private func header(_ provider: CodexBarWidgetProviderSummary) -> some View {
        HStack(spacing: 6) {
            if let logo = Self.logo(for: provider.providerID) {
                logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
                    .foregroundStyle(self.primary)
                    .accessibilityHidden(true)
            }
            Text(provider.providerName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(self.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            if self.entry.snapshot.isStale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.orange)
                    .accessibilityLabel(String(localized: "Stale"))
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(self.secondary)
                    .accessibilityHidden(true)
            }
            if let synced = self.entry.snapshot.latestSyncAt {
                Text(self.elapsedText(since: synced))
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(self.secondary)
                    .lineLimit(1)
                    .accessibilityLabel(String(format: String(localized: "Updated %@ ago"), self.elapsedText(since: synced)))
            }
        }
    }

    private func weeklySection(_ provider: CodexBarWidgetProviderSummary, large: Bool) -> some View {
        let figures = WidgetProviderSelection.overviewFigures(
            for: provider,
            selection: .manual,
            now: self.entry.date)
        let hasWeekly = provider.weeklyResetsAt != nil || provider.weeklyUsedPercent != nil
        return self.section(
            label: hasWeekly ? String(localized: "Weekly") : String(localized: "Usage"),
            reset: figures.resetsAt.map { self.weeklyResetText($0) },
            percent: figures.usagePercent,
            accent: ProviderColorPalette.color(for: provider.providerID),
            large: large)
    }

    private func sessionSection(_ provider: CodexBarWidgetProviderSummary) -> some View {
        self.section(
            label: self.sessionLabel(provider),
            reset: provider.sessionResetsAt.map { self.sessionResetText($0) },
            percent: provider.sessionUsedPercent,
            accent: ProviderColorPalette.color(for: provider.providerID),
            large: false)
    }

    private func section(label: String, reset: String?, percent: Double?, accent: Color, large: Bool) -> some View {
        VStack(alignment: .leading, spacing: large ? 10 : 6) {
            HStack(alignment: .bottom, spacing: 4) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(self.primary.opacity(0.8))
                        .lineLimit(1)
                    if let reset {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 9, weight: .medium))
                                .accessibilityHidden(true)
                            Text(reset)
                                .font(.system(size: 11))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(self.secondary)
                    }
                }
                Spacer(minLength: 2)
                // The figure keeps its size; the reset line shrinks first.
                self.percentText(percent, size: large ? 46 : 34)
                    .layoutPriority(1)
            }
            SegmentedMeter(
                percent: percent,
                fill: accent,
                track: self.track,
                segments: 20)
                .frame(height: large ? 14 : 11)
        }
    }

    private func percentText(_ percent: Double?, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(percent.map { "\(Int(min(100, max(0, $0)).rounded()))" } ?? "—")
                .font(.system(size: size, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(self.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .privacySensitive()
                .widgetAccentable()
            if percent != nil {
                Text("%")
                    .font(.system(size: size * 0.33, weight: .regular, design: .rounded))
                    .foregroundStyle(self.secondary)
            }
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(self.secondary)
    }

    // MARK: Text

    private func sessionLabel(_ provider: CodexBarWidgetProviderSummary) -> String {
        guard let minutes = provider.sessionWindowMinutes, minutes >= 60, minutes % 60 == 0 else {
            return String(localized: "Session")
        }
        return String(format: String(localized: "%@h"), "\(minutes / 60)")
    }

    /// Time since the last sync, one unit: "8 min", "2 hr", "3 days".
    private func elapsedText(since date: Date) -> String {
        let interval = max(0, self.entry.date.timeIntervalSince(date))
        if interval < 60 { return String(localized: "just now") }
        return Self.duration(
            interval,
            units: interval < 3600 ? [.minute] : interval < 86400 ? [.hour] : [.day],
            style: .short)
    }

    /// "4 hr 30 min from now" for a session reset.
    private func sessionResetText(_ resetsAt: Date) -> String {
        let interval = resetsAt.timeIntervalSince(self.entry.date)
        guard interval >= 60 else { return String(localized: "Now") }
        let units: NSCalendar.Unit = interval < 3600 ? [.minute] : [.hour, .minute]
        return String(format: String(localized: "In %@"), Self.duration(interval, units: units, count: 2))
    }

    /// "3 days from now 18:30" for a weekly reset; under a day it counts
    /// down like a session.
    private func weeklyResetText(_ resetsAt: Date) -> String {
        let interval = resetsAt.timeIntervalSince(self.entry.date)
        guard interval >= 86400 else { return self.sessionResetText(resetsAt) }
        let days = String(format: String(localized: "In %@"), Self.duration(interval, units: [.day]))
        return "\(days) \(Self.clockFormatter.string(from: resetsAt))"
    }

    /// 24-hour clock, as short as the reset line needs.
    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func duration(
        _ interval: TimeInterval,
        units: NSCalendar.Unit,
        count: Int = 1,
        style: DateComponentsFormatter.UnitsStyle = .abbreviated) -> String
    {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = style
        formatter.allowedUnits = units
        formatter.maximumUnitCount = count
        // Whole days and hours read better than a rounded-up figure.
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: interval) ?? ""
    }

    // MARK: Style

    /// The provider's mark from the widget's asset catalog, when it has one.
    static func logo(for providerID: String) -> Image? {
        let name = "ProviderIcon-\(providerID)"
        guard UIImage(named: name) != nil else { return nil }
        return Image(name).renderingMode(.template)
    }

    private var primary: Color {
        self.colorScheme == .dark ? Color.white.opacity(0.94) : Color.black.opacity(0.86)
    }

    private var secondary: Color {
        self.colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.5)
    }

    private var track: Color {
        self.colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }
}

/// A row of rounded bars filled from the left; the bar the fill ends in is
/// drawn at the share it covers.
private struct SegmentedMeter: View {
    let percent: Double?
    let fill: Color
    let track: Color
    let segments: Int

    var body: some View {
        let filled = min(1, max(0, (self.percent ?? 0) / 100)) * Double(self.segments)
        HStack(spacing: 3) {
            ForEach(0..<self.segments, id: \.self) { index in
                let share = min(1, max(0, filled - Double(index)))
                ZStack {
                    RoundedRectangle(cornerRadius: 1.5).fill(self.track)
                    if share > 0 {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(self.fill.opacity(0.35 + 0.65 * share))
                            .widgetAccentable()
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
