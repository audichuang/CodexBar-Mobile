import SwiftUI
import WidgetKit

// Fork: Lock Screen layouts of the Provider Quota widget. The system tints these
// monochrome, so risk is always spelled out in words and never relies on color.
// Numbers are deliberately not `privacySensitive`: that would redact them while
// locked, which is the one moment this widget exists for.

/// Picks the Home Screen or Lock Screen layout for the widget's family.
struct ProviderQuotaFamilyView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CodexBarWidgetEntry

    var body: some View {
        switch self.family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            ProviderQuotaAccessoryView(entry: self.entry, family: self.family)
                .containerBackground(for: .widget) { Color.clear }
        default:
            ProviderQuotaWidgetView(entry: self.entry)
        }
    }
}

struct ProviderQuotaAccessoryView: View {
    let entry: CodexBarWidgetEntry
    let family: WidgetFamily

    /// One window of the account, as a Lock Screen row.
    private struct Lane {
        let label: String
        let percent: Double
        let detail: String?
        let isAtRisk: Bool
    }

    var body: some View {
        if let provider = WidgetProviderSelection.quotaAccount(for: self.entry), !provider.isError {
            switch self.family {
            case .accessoryCircular: self.circular(provider)
            case .accessoryInline: self.inline(provider)
            default: self.rectangular(provider)
            }
        } else {
            Text(self.family == .accessoryInline ? "CodexBar —" : "—")
        }
    }

    private var now: Date {
        self.entry.date
    }

    private func lanes(_ provider: CodexBarWidgetProviderSummary) -> [Lane] {
        var lanes: [Lane] = []
        if let percent = provider.sessionUsedPercent {
            let forecast = provider.sessionForecast(now: self.now)
            lanes.append(Lane(
                label: self.sessionLabel(provider),
                percent: percent,
                detail: forecast?.riskText(now: self.now)
                    ?? WidgetProviderResetText.hours(provider.sessionResetsAt, now: self.now),
                isAtRisk: forecast?.isAtRisk == true))
        }
        if let percent = provider.weeklyUsedPercent {
            let forecast = provider.weeklyForecast(now: self.now)
            lanes.append(Lane(
                label: String(localized: "Week"),
                percent: percent,
                detail: forecast?.riskText(now: self.now)
                    ?? WidgetProviderResetText.days(provider.weeklyResetsAt, now: self.now),
                isAtRisk: forecast?.isAtRisk == true))
        }
        return lanes
    }

    /// The window to show when there is room for only one: at risk first, then fullest.
    private func leadingLane(_ provider: CodexBarWidgetProviderSummary) -> Lane? {
        self.lanes(provider).max { lhs, rhs in
            if lhs.isAtRisk != rhs.isAtRisk { return rhs.isAtRisk }
            return lhs.percent < rhs.percent
        }
    }

    private func percentText(_ percent: Double) -> String {
        "\(Int(min(100, max(0, percent)).rounded()))%"
    }

    private func sessionLabel(_ provider: CodexBarWidgetProviderSummary) -> String {
        guard let minutes = provider.sessionWindowMinutes, minutes >= 60, minutes % 60 == 0 else {
            return String(localized: "Session")
        }
        return String(format: String(localized: "%@h"), "\(minutes / 60)")
    }

    private func title(_ provider: CodexBarWidgetProviderSummary) -> String {
        WidgetProviderSelection.quotaAccountName(of: provider, in: self.entry.snapshot.topProviders)
            .map { "\(provider.providerName) · \($0)" } ?? provider.providerName
    }

    private func rectangular(_ provider: CodexBarWidgetProviderSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(self.title(provider))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Text(WidgetFreshnessText.text(since: provider.lastUpdated, now: self.now))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            ForEach(self.lanes(provider).prefix(2), id: \.label) { lane in
                HStack(spacing: 4) {
                    Text(lane.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(self.percentText(lane.percent))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    if let detail = lane.detail {
                        Text(detail)
                            .font(.system(size: 11, weight: lane.isAtRisk ? .bold : .regular))
                            .foregroundStyle(lane.isAtRisk ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func circular(_ provider: CodexBarWidgetProviderSummary) -> some View {
        if let lane = self.leadingLane(provider) {
            Gauge(value: min(100, max(0, lane.percent)), in: 0...100) {
                Text(lane.isAtRisk ? "!" : lane.label)
            } currentValueLabel: {
                Text("\(Int(min(100, max(0, lane.percent)).rounded()))")
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            Text("—")
        }
    }

    private func inline(_ provider: CodexBarWidgetProviderSummary) -> some View {
        let lane = self.leadingLane(provider)
        let parts = [
            provider.providerName,
            lane.map { self.percentText($0.percent) },
            lane.flatMap { $0.isAtRisk ? $0.detail : nil },
        ]
        return Text(parts.compactMap(\.self).joined(separator: " "))
    }
}
