import CodexBarCore
import SwiftUI
import WidgetKit

// Fork-owned macOS widgets that follow the iPhone widget's look: large rounded percentages,
// a cost strip and black/off-white tiles. Registered from `CodexBarWidgetBundle` through one
// declared hook (see FORK.md); upstream widgets stay untouched.

// MARK: - Widgets

struct ForkOverviewWidget: Widget {
    static let kind = "ForkOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ForkOverviewTimelineProvider()) { entry in
            ForkOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(ForkWidgetText.t("CodexBar Overview", hant: "CodexBar 總覽", hans: "CodexBar 总览")))
        .description(Text(ForkWidgetText.t(
            "Usage of every provider at a glance, with today's and 30-day cost.",
            hant: "一眼看完所有服務的用量，以及今日與 30 天花費。",
            hans: "一眼看完所有服务的用量，以及今日与 30 天花费。")))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ForkProviderQuotaWidget: Widget {
    static let kind = "ForkProviderQuotaWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: ProviderSelectionIntent.self,
            provider: ForkProviderQuotaTimelineProvider())
        { entry in
            ForkProviderQuotaWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(ForkWidgetText.t("CodexBar Quota", hant: "CodexBar 額度", hans: "CodexBar 额度")))
        .description(Text(ForkWidgetText.t(
            "One provider's weekly and session quota.",
            hant: "單一服務的每週與工作階段額度。",
            hans: "单一服务的每周与会话额度。")))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline

struct ForkWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    var provider: UsageProvider?
}

struct ForkOverviewTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ForkWidgetEntry {
        ForkWidgetEntry(date: Date(), snapshot: ForkWidgetPreview.snapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (ForkWidgetEntry) -> Void) {
        completion(ForkWidgetEntry(date: Date(), snapshot: Self.load(isPreview: context.isPreview)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ForkWidgetEntry>) -> Void) {
        let snapshot = Self.load(isPreview: false)
        completion(ForkWidgetTimeline.make { ForkWidgetEntry(date: $0, snapshot: snapshot) })
    }

    /// The gallery preview falls back to sample data so it never shows an empty tile.
    static func load(isPreview: Bool) -> WidgetSnapshot {
        let stored = WidgetSnapshotStore.load()
        if let stored, !ForkWidgetModel.providers(in: stored).isEmpty { return stored }
        return isPreview ? ForkWidgetPreview.snapshot() : (stored ?? WidgetPreviewData.emptySnapshot())
    }
}

struct ForkProviderQuotaTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ForkWidgetEntry {
        // Provider-specific by design: gallery previews show the sample snapshot, which contains Codex.
        ForkWidgetEntry(date: Date(), snapshot: ForkWidgetPreview.snapshot(), provider: .codex)
    }

    func snapshot(for configuration: ProviderSelectionIntent, in context: Context) async -> ForkWidgetEntry {
        let provider = configuration.provider.provider
        let stored = WidgetSnapshotStore.load(provider: provider)
        let hasEntry = stored?.entries.contains { $0.provider == provider.instanceID } == true
        let snapshot = hasEntry ? stored! : (context.isPreview ? ForkWidgetPreview.snapshot() : stored)
        return ForkWidgetEntry(
            date: Date(),
            snapshot: snapshot ?? WidgetPreviewData.emptySnapshot(),
            provider: hasEntry || !context.isPreview ? provider : .codex)
    }

    func timeline(for configuration: ProviderSelectionIntent, in context: Context) async -> Timeline<ForkWidgetEntry> {
        let provider = configuration.provider.provider
        let snapshot = WidgetSnapshotStore.load(provider: provider) ?? WidgetPreviewData.emptySnapshot()
        return ForkWidgetTimeline.make { ForkWidgetEntry(date: $0, snapshot: snapshot, provider: provider) }
    }
}

/// "N 分鐘前更新" and the reset countdowns are plain text, so the timeline carries one entry per
/// five minutes; the app still reloads every widget whenever it publishes a new snapshot.
enum ForkWidgetTimeline {
    static let step: TimeInterval = 5 * 60
    static let count = 7

    static func make(now: Date = Date(), _ entry: (Date) -> ForkWidgetEntry) -> Timeline<ForkWidgetEntry> {
        Timeline(
            entries: (0..<self.count).map { entry(now.addingTimeInterval(Double($0) * self.step)) },
            policy: .atEnd)
    }
}

// MARK: - Model

/// One quota window reduced to what the tiles show.
struct ForkQuotaFigure: Equatable {
    let label: String
    let usedPercent: Double
    let resetsAt: Date?
}

struct ForkProviderSummary: Identifiable {
    let provider: UsageProvider
    let entry: WidgetSnapshot.ProviderEntry

    var id: String {
        self.provider.rawValue
    }

    var name: String {
        ProviderDefaults.metadata[self.provider]?.displayName ?? self.provider.rawValue.capitalized
    }

    var color: Color {
        WidgetColors.color(for: self.provider.instanceID)
    }

    var session: ForkQuotaFigure? {
        ForkWidgetModel.figure(self.entry.primary)
    }

    var weekly: ForkQuotaFigure? {
        ForkWidgetModel.figure(self.entry.secondary)
    }

    /// The window that runs out first decides whether the user can keep working.
    var headline: ForkQuotaFigure? {
        [self.entry.primary, self.entry.secondary, self.entry.tertiary]
            .compactMap(ForkWidgetModel.figure)
            .max { $0.usedPercent < $1.usedPercent }
    }

    /// Balance-only providers (DeepSeek and similar) have no quota window.
    var balance: String? {
        self.headline == nil ? self.entry.balanceText : nil
    }
}

enum ForkWidgetModel {
    static func providers(in snapshot: WidgetSnapshot) -> [ForkProviderSummary] {
        let order = snapshot.enabledProviders.isEmpty ? snapshot.entries.map(\.provider) : snapshot.enabledProviders
        return order.compactMap { id in
            guard let provider = id.firstPartyProvider,
                  let entry = snapshot.entries.first(where: { $0.provider == id }) else { return nil }
            let summary = ForkProviderSummary(provider: provider, entry: entry)
            return summary.headline != nil || summary.balance != nil ? summary : nil
        }
    }

    static func figure(_ window: RateWindow?) -> ForkQuotaFigure? {
        guard let window else { return nil }
        // Balance rows reuse RateWindow without a window length; they are not quotas.
        guard window.windowMinutes != nil || window.resetsAt != nil else { return nil }
        return ForkQuotaFigure(
            label: self.windowLabel(minutes: window.windowMinutes),
            usedPercent: min(100, max(0, window.usedPercent)),
            resetsAt: window.resetsAt)
    }

    static func windowLabel(minutes: Int?) -> String {
        guard let minutes else { return W("Usage") }
        switch minutes {
        case 10080: return W("Weekly")
        case 1440: return ForkWidgetText.t("Daily", hant: "每日", hans: "每日")
        case let value where value >= 43200: return ForkWidgetText.t("Monthly", hant: "每月", hans: "每月")
        case let value where value % 60 == 0:
            return ForkWidgetText.t("\(value / 60)h", hant: "\(value / 60) 小時", hans: "\(value / 60) 小时")
        default: return W("Session")
        }
    }

    static func todayCost(_ snapshot: WidgetSnapshot) -> Double? {
        self.sum(snapshot) { $0.tokenUsage?.sessionCostUSD }
    }

    static func thirtyDayCost(_ snapshot: WidgetSnapshot) -> Double? {
        self.sum(snapshot) { $0.tokenUsage?.last30DaysCostUSD }
    }

    static func maxUsage(_ providers: [ForkProviderSummary]) -> Double? {
        providers.compactMap(\.headline?.usedPercent).max()
    }

    private static func sum(_ snapshot: WidgetSnapshot, _ value: (WidgetSnapshot.ProviderEntry) -> Double?) -> Double? {
        let values = snapshot.entries.compactMap(value)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    static func latestUpdate(_ providers: [ForkProviderSummary]) -> Date? {
        providers.map(\.entry.updatedAt).max()
    }
}

// MARK: - Text

enum ForkWidgetText {
    /// The widget's resource catalogs are upstream-generated; fork strings pick their language
    /// from the same lproj the upstream `W()` resolved, so both stay in step.
    static func t(_ english: String, hant: String, hans: String) -> String {
        let language = WidgetLocalization.currentBundle.bundleURL.deletingPathExtension().lastPathComponent.lowercased()
        if language.hasPrefix("zh-hant") || language == "zh-tw" || language == "zh-hk" { return hant }
        if language.hasPrefix("zh") { return hans }
        return english
    }

    static func percent(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded()))" } ?? "—"
    }

    static func cost(_ value: Double?) -> String {
        guard let value else { return "—" }
        // "$" like the iPhone tiles; zh locales would otherwise print "US$".
        return "$" + value.formatted(.number.grouping(.automatic).precision(.fractionLength(value >= 1000 ? 0 : 2)))
    }

    /// "3.6 天" / "4.5 小時" / "25 分" until the reset, like the iPhone tiles.
    static func remaining(until date: Date?, now: Date) -> String? {
        guard let date else { return nil }
        let interval = date.timeIntervalSince(now)
        guard interval > 60 else { return self.t("now", hant: "即將重置", hans: "即将重置") }
        if interval >= 86400 {
            let days = (interval / 86400).formatted(.number.precision(.fractionLength(1)))
            return self.t("\(days)d", hant: "\(days) 天", hans: "\(days) 天")
        }
        if interval >= 3600 {
            let hours = (interval / 3600).formatted(.number.precision(.fractionLength(1)))
            return self.t("\(hours)h", hant: "\(hours) 小時", hans: "\(hours) 小时")
        }
        let minutes = Int(interval / 60)
        return self.t("\(minutes)m", hant: "\(minutes) 分", hans: "\(minutes) 分")
    }

    static func updated(_ date: Date?, now: Date, compact: Bool = false) -> String {
        guard let date else { return W("No data") }
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        if compact {
            // Small tiles share the header row with the provider name.
            if minutes < 1 { return self.t("now", hant: "剛剛", hans: "刚刚") }
            if minutes < 60 { return self.t("\(minutes)m ago", hant: "\(minutes) 分前", hans: "\(minutes) 分前") }
            if minutes < 1440 { return self.t(
                "\(minutes / 60)h ago",
                hant: "\(minutes / 60) 時前",
                hans: "\(minutes / 60) 时前") }
            return self.t("\(minutes / 1440)d ago", hant: "\(minutes / 1440) 天前", hans: "\(minutes / 1440) 天前")
        }
        if minutes < 1 { return self.t("Updated just now", hant: "剛剛更新", hans: "刚刚更新") }
        if minutes < 60 {
            return self.t("Updated \(minutes) min ago", hant: "\(minutes) 分鐘前更新", hans: "\(minutes) 分钟前更新")
        }
        let hours = minutes / 60
        if hours < 24 { return self.t("Updated \(hours) hr ago", hant: "\(hours) 小時前更新", hans: "\(hours) 小时前更新") }
        let days = hours / 24
        return self.t("Updated \(days) d ago", hant: "\(days) 天前更新", hans: "\(days) 天前更新")
    }
}

// MARK: - Style

struct ForkWidgetPalette {
    let scheme: ColorScheme
    /// Tinted and dimmed desktop appearances render through a luminance mask and drop the
    /// container background, so fixed black/white ink must give way to the semantic styles.
    var fullColor: Bool = true

    var background: Color {
        self.scheme == .dark ? .black : Color(red: 0.975, green: 0.975, blue: 0.97)
    }

    var primary: Color {
        guard self.fullColor else { return .primary }
        return self.scheme == .dark ? Color.white.opacity(0.94) : Color.black.opacity(0.86)
    }

    var secondary: Color {
        guard self.fullColor else { return .secondary }
        return self.scheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.5)
    }

    var track: Color {
        guard self.fullColor else { return .primary.opacity(0.15) }
        return self.scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    var divider: Color {
        guard self.fullColor else { return .primary.opacity(0.15) }
        return self.scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.1)
    }

    var risk: Color {
        self.scheme == .dark ? Color(red: 1, green: 0.45, blue: 0.4) : Color(
            red: 0.85,
            green: 0.2,
            blue: 0.15)
    }

    func fill(for percent: Double, accent: Color) -> Color {
        percent >= 90 ? self.risk : accent
    }
}

private struct ForkBar: View {
    let percent: Double?
    let fill: Color
    let track: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(self.track)
                if let percent, percent > 0 {
                    Capsule()
                        .fill(self.fill)
                        .frame(width: max(self.height, proxy.size.width * percent / 100))
                        .widgetAccentable()
                }
            }
        }
        .frame(height: self.height)
        .accessibilityHidden(true)
    }
}

/// The iPhone quota widget's meter: rounded bars filled from the left.
private struct ForkSegmentedMeter: View {
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

private struct ForkPercentText: View {
    let percent: Double?
    let size: CGFloat
    let palette: ForkWidgetPalette
    var weight: Font.Weight = .bold

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(ForkWidgetText.percent(self.percent))
                .font(.system(size: self.size, weight: self.weight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(self.palette.primary)
                .widgetAccentable()
            if self.percent != nil {
                Text("%")
                    .font(.system(size: self.size * 0.62, weight: self.weight, design: .rounded))
                    .foregroundStyle(self.palette.primary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

private struct ForkEmptyView: View {
    let palette: ForkWidgetPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(self.palette.primary)
            Text(W("Open CodexBar"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(self.palette.primary)
            Text(ForkWidgetText.t(
                "Usage appears after the next refresh.",
                hant: "下次刷新後就會顯示用量。",
                hans: "下次刷新后就会显示用量。"))
                .font(.system(size: 11))
                .foregroundStyle(self.palette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Overview widget

struct ForkOverviewWidgetView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetFamily) private var environmentFamily
    let entry: ForkWidgetEntry
    /// Render tests cannot set `widgetFamily`; the widget itself leaves this nil.
    var familyOverride: WidgetFamily?

    private var family: WidgetFamily {
        self.familyOverride ?? self.environmentFamily
    }

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.widgetRenderingModeOverride) private var renderingModeOverride

    private var palette: ForkWidgetPalette {
        ForkWidgetPalette(
            scheme: self.scheme,
            fullColor: (self.renderingModeOverride ?? self.renderingMode) == .fullColor)
    }

    private var providers: [ForkProviderSummary] {
        ForkWidgetModel.providers(in: self.entry.snapshot)
    }

    var body: some View {
        Group {
            if self.providers.isEmpty {
                ForkEmptyView(palette: self.palette)
            } else {
                switch self.family {
                case .systemSmall: self.small
                case .systemLarge: self.large
                default: self.medium
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { self.palette.background }
    }

    // Small: two providers stacked, each a big figure over a bar (the iPhone small overview).
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(self.providers.prefix(2).enumerated()), id: \.element.id) { index, provider in
                if index > 0 { Spacer(minLength: 6) }
                self.stackedRow(provider, figureSize: 30)
            }
            if self.providers.count == 1 { Spacer(minLength: 0) }
        }
    }

    // Medium: cost strip, the most constrained provider, then freshness (the iPhone medium overview).
    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            self.metricStrip
            if let top = self.providers
                .max(by: { ($0.headline?.usedPercent ?? -1) < ($1.headline?.usedPercent ?? -1) })
            {
                self.listRow(top)
            }
            Spacer(minLength: 0)
            self.footer
        }
    }

    // Large: cost strip, then every provider (up to five) as a row.
    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            self.metricStrip
            Rectangle().fill(self.palette.divider).frame(height: 1)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(self.providers.prefix(5)) { provider in
                    self.listRow(provider)
                }
            }
            Spacer(minLength: 0)
            self.footer
        }
    }

    private func stackedRow(_ provider: ForkProviderSummary, figureSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Circle().strokeBorder(self.palette.secondary, lineWidth: 1.5).frame(width: 9, height: 9)
                Text(provider.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(self.palette.secondary)
                if let label = provider.headline?.label {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(self.palette.secondary.opacity(0.8))
                }
            }
            .lineLimit(1)
            if let headline = provider.headline {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    ForkPercentText(percent: headline.usedPercent, size: figureSize, palette: self.palette)
                    if let left = ForkWidgetText.remaining(until: headline.resetsAt, now: self.entry.date) {
                        Text(left)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(self.palette.secondary)
                            .lineLimit(1)
                    }
                }
                ForkBar(
                    percent: headline.usedPercent,
                    fill: self.palette.fill(for: headline.usedPercent, accent: self.palette.primary.opacity(0.75)),
                    track: self.palette.track)
            } else if let balance = provider.balance {
                Text(balance)
                    .font(.system(size: figureSize * 0.8, weight: .bold, design: .rounded))
                    .foregroundStyle(self.palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private func listRow(_ provider: ForkProviderSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Circle().strokeBorder(provider.color, lineWidth: 2).frame(width: 11, height: 11)
                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(self.palette.primary)
                    Text(self.subtitle(provider))
                        .font(.system(size: 11))
                        .foregroundStyle(self.palette.secondary)
                }
                .lineLimit(1)
                Spacer(minLength: 4)
                if let headline = provider.headline {
                    ForkPercentText(percent: headline.usedPercent, size: 20, palette: self.palette, weight: .semibold)
                } else if let balance = provider.balance {
                    Text(balance)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(self.palette.primary)
                        .lineLimit(1)
                }
            }
            if let headline = provider.headline {
                ForkBar(
                    percent: headline.usedPercent,
                    fill: self.palette.fill(for: headline.usedPercent, accent: provider.color),
                    track: self.palette.track,
                    height: 4)
            }
        }
    }

    private func subtitle(_ provider: ForkProviderSummary) -> String {
        guard let headline = provider.headline else { return ForkWidgetText.t("Balance", hant: "餘額", hans: "余额") }
        guard let left = ForkWidgetText.remaining(until: headline.resetsAt, now: self.entry.date) else {
            return headline.label
        }
        return "\(headline.label) · \(ForkWidgetText.t("resets in \(left)", hant: "\(left)後重置", hans: "\(left)后重置"))"
    }

    private var metricStrip: some View {
        HStack(alignment: .top, spacing: 0) {
            self.metric(
                icon: "dollarsign.circle",
                label: W("Today"),
                value: ForkWidgetText.cost(ForkWidgetModel.todayCost(self.entry.snapshot)))
            self.stripDivider
            self.metric(
                icon: "calendar",
                label: ForkWidgetText.t("30 Days", hant: "30 天", hans: "30 天"),
                value: ForkWidgetText.cost(ForkWidgetModel.thirtyDayCost(self.entry.snapshot)))
            self.stripDivider
            self.metric(
                icon: "gauge.with.dots.needle.67percent",
                label: ForkWidgetText.t("Usage", hant: "用量", hans: "用量"),
                value: ForkWidgetModel.maxUsage(self.providers).map { "\(ForkWidgetText.percent($0))%" } ?? "—")
        }
    }

    private var stripDivider: some View {
        Rectangle().fill(self.palette.divider).frame(width: 1, height: 34).padding(.horizontal, 10)
    }

    private func metric(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(.system(size: 11))
            }
            .foregroundStyle(self.palette.secondary)
            .lineLimit(1)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(self.palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        Text(ForkWidgetText.updated(ForkWidgetModel.latestUpdate(self.providers), now: self.entry.date))
            .font(.system(size: 11))
            .foregroundStyle(self.palette.secondary)
            .lineLimit(1)
    }
}

// MARK: - Provider quota widget

struct ForkProviderQuotaWidgetView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetFamily) private var environmentFamily
    let entry: ForkWidgetEntry
    /// Render tests cannot set `widgetFamily`; the widget itself leaves this nil.
    var familyOverride: WidgetFamily?

    private var family: WidgetFamily {
        self.familyOverride ?? self.environmentFamily
    }

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.widgetRenderingModeOverride) private var renderingModeOverride

    private var palette: ForkWidgetPalette {
        ForkWidgetPalette(
            scheme: self.scheme,
            fullColor: (self.renderingModeOverride ?? self.renderingMode) == .fullColor)
    }

    private var summary: ForkProviderSummary? {
        guard let provider = self.entry.provider else { return nil }
        return ForkWidgetModel.providers(in: self.entry.snapshot).first { $0.provider == provider }
    }

    var body: some View {
        Group {
            if let summary {
                self.content(summary)
            } else {
                ForkEmptyView(palette: self.palette)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            ZStack(alignment: .bottomTrailing) {
                self.palette.background
                if let provider = self.summary?.provider {
                    Text(ProviderMonogram.text(for: provider))
                        .font(.system(size: 92, weight: .heavy, design: .rounded))
                        .foregroundStyle(self.palette.primary.opacity(self.scheme == .dark ? 0.06 : 0.045))
                        .offset(x: 14, y: 22)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func content(_ summary: ForkProviderSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            self.header(summary)
            let weekly = summary.weekly ?? summary.headline
            let session = summary.weekly == nil ? nil : summary.session
            if let weekly {
                Spacer(minLength: 6)
                if self.family == .systemMedium, let session {
                    HStack(alignment: .bottom, spacing: 18) {
                        self.section(weekly, summary: summary, large: false)
                        self.section(session, summary: summary, large: false)
                    }
                } else {
                    self.section(weekly, summary: summary, large: session == nil)
                    if let session {
                        Spacer(minLength: 8)
                        self.section(session, summary: summary, large: false)
                    }
                }
                if session == nil { Spacer(minLength: 6) }
            } else if let balance = summary.balance {
                Spacer(minLength: 0)
                Text(balance)
                    .font(.system(size: 34, weight: .regular, design: .rounded))
                    .foregroundStyle(self.palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(ForkWidgetText.t("Balance", hant: "餘額", hans: "余额"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(self.palette.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private func header(_ summary: ForkProviderSummary) -> some View {
        HStack(spacing: 6) {
            ProviderMark(provider: summary.provider, isSelected: true, size: 18)
            Text(summary.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(self.palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            let isOld = WidgetFreshness.isStale(summary.entry.updatedAt, now: self.entry.date)
            Text(ForkWidgetText.updated(
                summary.entry.updatedAt,
                now: self.entry.date,
                compact: self.family == .systemSmall))
                .font(.system(size: 10))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isOld ? Color.orange : self.palette.secondary)
        }
    }

    private func section(_ figure: ForkQuotaFigure, summary: ForkProviderSummary, large: Bool) -> some View {
        let fill = self.palette.fill(for: figure.usedPercent, accent: summary.color)
        return VStack(alignment: .leading, spacing: large ? 10 : 6) {
            HStack(alignment: .bottom, spacing: 4) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(figure.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(self.palette.primary.opacity(0.8))
                        .lineLimit(1)
                    if let left = ForkWidgetText.remaining(until: figure.resetsAt, now: self.entry.date) {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.arrow.circlepath").font(.system(size: 9, weight: .medium))
                            Text(left).font(.system(size: 11)).monospacedDigit()
                        }
                        .foregroundStyle(self.palette.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                }
                Spacer(minLength: 2)
                ForkPercentText(
                    percent: figure.usedPercent,
                    size: large ? 46 : 34,
                    palette: self.palette,
                    weight: .regular)
                    .layoutPriority(1)
            }
            ForkSegmentedMeter(percent: figure.usedPercent, fill: fill, track: self.palette.track, segments: 20)
                .frame(height: large ? 14 : 11)
        }
    }
}

// MARK: - Preview data

enum ForkWidgetPreview {
    static func snapshot() -> WidgetSnapshot {
        let now = Date()
        func window(_ used: Double, minutes: Int, hours: Double) -> RateWindow {
            RateWindow(
                usedPercent: used,
                windowMinutes: minutes,
                resetsAt: now.addingTimeInterval(hours * 3600),
                resetDescription: nil)
        }
        func tokens(today: Double, month: Double) -> WidgetSnapshot.TokenUsageSummary {
            WidgetSnapshot.TokenUsageSummary(
                sessionCostUSD: today,
                sessionTokens: nil,
                last30DaysCostUSD: month,
                last30DaysTokens: nil)
        }
        // Provider-specific by design: sample data for gallery previews mirrors the iPhone screenshots.
        let claude = WidgetSnapshot.ProviderEntry(
            provider: .claude,
            updatedAt: now.addingTimeInterval(-180),
            primary: window(35, minutes: 300, hours: 2.5),
            secondary: window(54, minutes: 10080, hours: 86),
            tertiary: nil,
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: tokens(today: 8.12, month: 141.3),
            dailyUsage: [])
        let codex = WidgetSnapshot.ProviderEntry(
            provider: .codex,
            updatedAt: now.addingTimeInterval(-180),
            primary: window(12, minutes: 300, hours: 4),
            secondary: window(39, minutes: 10080, hours: 70),
            tertiary: nil,
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: tokens(today: 11.3, month: 97.47),
            dailyUsage: [])
        return WidgetSnapshot(entries: [claude, codex], enabledProviders: [.claude, .codex], generatedAt: now)
    }
}
