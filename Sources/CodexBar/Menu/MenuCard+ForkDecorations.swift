import SwiftUI

// Fork: Burnstate-style decorations for the menu card — a provider avatar in the card header,
// a pace status glyph before each metric's percent, and a warning tint on the pace phrase.

/// Pace health of one metric, derived from where the fill sits against the clock tick.
enum ForkPaceStatus: Equatable {
    /// Behind or on the clock.
    case onTrack
    /// Ahead of the clock.
    case burningFast
    /// Far ahead of the clock, or ahead with little left.
    case runningOut

    private static let runningOutDelta: Double = 15
    private static let runningOutRemaining: Double = 20

    init?(metric: UsageMenuCardView.Model.Metric) {
        guard metric.statusText == nil, let pace = metric.pacePercent else { return nil }
        if metric.paceOnTop {
            self = .onTrack
            return
        }
        let remaining = metric.percentStyle == .left ? metric.percent : 100 - metric.percent
        let delta = abs(metric.percent - pace)
        self = delta >= Self.runningOutDelta || remaining < Self.runningOutRemaining ? .runningOut : .burningFast
    }

    var symbolName: String {
        switch self {
        case .onTrack: "circle"
        case .burningFast: "circle.lefthalf.filled"
        case .runningOut: "exclamationmark.circle.fill"
        }
    }

    func color(highlighted: Bool) -> Color {
        if highlighted { return MenuHighlightStyle.selectionText }
        return switch self {
        case .onTrack: Color(nsColor: .systemGreen)
        case .burningFast: Color(nsColor: .systemOrange)
        case .runningOut: Color(nsColor: .systemRed)
        }
    }

    /// Only the warning states tint text; being on track stays quiet.
    var tintsText: Bool {
        self != .onTrack
    }
}

extension EnvironmentValues {
    @Entry var forkPaceStatus: ForkPaceStatus?
}

/// Metric header label: title, then status glyph and percent.
struct ForkMetricTitleLabel: View {
    let title: String
    let percentText: String?
    @Environment(\.forkPaceStatus) private var status
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(self.title)
                .fontWeight(.medium)
            if let percentText {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if let status {
                        Image(systemName: status.symbolName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(status.color(highlighted: self.isHighlighted))
                            .accessibilityHidden(true)
                    }
                    Text(percentText)
                        .monospacedDigit()
                        .fontWeight(.semibold)
                }
                // Truncate the title before the percent when space runs out.
                .layoutPriority(1)
            }
        }
        .font(.body)
        .lineLimit(1)
    }
}

extension MetricRow {
    /// Tints the leading pace phrase ("22% in deficit") when the metric is burning ahead of the clock.
    func forkStyledMeta(_ text: String, highlighted: Bool) -> AttributedString {
        var styled = AttributedString(text)
        guard self.metric.detailIsPaceDerived,
              let status = ForkPaceStatus(metric: self.metric), status.tintsText,
              let phrase = self.metric.detailLeftText, !phrase.isEmpty,
              text.hasPrefix(phrase),
              let range = styled.range(of: phrase)
        else { return styled }
        styled[range].foregroundColor = status.color(highlighted: highlighted)
        return styled
    }
}

/// Card header title: a round initial avatar in the provider color, then the provider name.
struct ForkProviderTitle: View {
    let name: String
    let color: Color
    @Environment(\.menuItemHighlighted) private var isHighlighted

    private static let avatarSize: CGFloat = 18

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(self.initial)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(self.isHighlighted ? self.color : Color.black.opacity(0.78))
                .frame(width: Self.avatarSize, height: Self.avatarSize)
                .background(Circle().fill(self.isHighlighted ? MenuHighlightStyle.selectionText : self.color))
                .alignmentGuide(.firstTextBaseline) { dimensions in dimensions[VerticalAlignment.center] + 5 }
                .accessibilityHidden(true)
            Text(self.name)
        }
    }

    private var initial: String {
        self.name.first.map { String($0).uppercased() } ?? "?"
    }
}
