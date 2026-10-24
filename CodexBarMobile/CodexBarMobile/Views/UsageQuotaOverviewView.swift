import Charts
import CodexBarSync
import SwiftUI

/// A shared weekly calendar for actual observations; future dates contain no predicted marks.
struct UsageQuotaOverviewView: View {
    @ObservedObject var store: UsageQuotaOverviewStore
    let accounts: [ProviderUsageSnapshot]
    let linkages: [ProviderAccountLinkage]
    var sourceSnapshots: [SyncedUsageSnapshot]?
    var quotaSources: [String: SyncProviderQuotaSource]?
    let publicationRevision: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.mobileAdaptiveLayout) private var layout
    @AppStorage(MobileSettingsKeys.hidePersonalInfo) private var hidesPersonalInfo = false
    @State private var expanded = false
    @State private var showingEditor = false
    @State private var showingExplanation = false

    private var usesCompactLayout: Bool {
        self.layout.usesShortHeight && !self.dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            self.card(overview: self.store.overview(accounts: self.accounts, now: context.date))
        }
        .task(id: self.publicationRevision) {
            self.store.reconcile(
                accounts: self.accounts, sourceSnapshots: self.sourceSnapshots,
                quotaSources: self.quotaSources, linkages: self.linkages)
        }
        .sheet(isPresented: self.$showingEditor) {
            UsageQuotaEditor(store: self.store, accounts: self.accounts)
        }
        .sheet(isPresented: self.$showingExplanation) {
            NavigationStack {
                Form {
                    Text(
                        String(
                            localized: "The chart ends at your nearest upcoming weekly reset across providers and starts 144 hours earlier, with seven date marks. It updates as resets pass or new data arrives. Lines show only actual readings."))
                    Text(
                        String(
                            localized: "No future usage is predicted or missing readings invented. Synced provider history follows the detail chart; long gaps between local readings break the line."))
                    Text(
                        String(
                            localized: "The chart combines readings saved on this iPhone with available provider history shown in the details. Provider history is not account-verified and is omitted when multiple accounts or conflicting sources make it ambiguous. Missing or outdated readings are not new activity."))
                }
                .navigationTitle(String(localized: "About Quota History"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Done")) { self.showingExplanation = false }
                    }
                }
            }
        }
    }

    private func card(overview: UsageQuotaOverview) -> some View {
        VStack(alignment: .leading, spacing: self.usesCompactLayout ? 8 : 12) {
            if self.usesCompactLayout, !self.store.isReadOnly, !overview.lines.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        self.title.fixedSize()
                        Spacer(minLength: 8)
                        self.explanationButton.fixedSize()
                        self.rangeLabel(overview).fixedSize()
                        self.editButton
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        self.header
                        self.chartControls(overview)
                    }
                }
            } else {
                self.header
            }
            if self.store.isReadOnly {
                Text(String(localized: "Saved quota settings could not be read. They have been kept unchanged."))
                    .font(.caption).foregroundStyle(.secondary)
            } else if overview.lines.isEmpty {
                Text(String(localized: "Choose up to 5 account quotas to compare their remaining quota history."))
                    .font(.subheadline).foregroundStyle(.secondary)
                Button(String(localized: "Choose quota lines")) { self.showingEditor = true }
                    .buttonStyle(.bordered)
            } else {
                if !self.usesCompactLayout {
                    self.chartControls(overview)
                }
                self.chart(overview)
                self.legend(overview)
            }
        }
        .padding(self.usesCompactLayout ? 12 : 16)
        .background(MobileSurfaceStyle.cardMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("usage-quota-overview")
    }

    private var title: some View {
        Text(String(localized: "Remaining Quota")).font(.headline)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            self.title
            Spacer(minLength: 8)
            self.editButton
        }
    }

    private var editButton: some View {
        Button { self.showingEditor = true } label: {
            Image(systemName: "slider.horizontal.3")
                .frame(minWidth: 32, minHeight: 32)
        }
        .accessibilityLabel(String(localized: "Choose quota lines"))
        .accessibilityIdentifier("usage-quota-edit")
    }

    private func chartControls(_ overview: UsageQuotaOverview) -> some View {
        HStack {
            self.explanationButton
            Spacer(minLength: 6)
            self.rangeLabel(overview)
        }
    }

    private var explanationButton: some View {
        Button { self.showingExplanation = true } label: {
            Label(String(localized: "Observed history"), systemImage: "info.circle")
                .font(.caption)
        }
        .accessibilityIdentifier("usage-quota-info")
    }

    private func rangeLabel(_ overview: UsageQuotaOverview) -> some View {
        Text((overview.start..<overview.end).formatted(.interval.month(.abbreviated).day()))
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("usage-quota-period")
    }

    private func chart(_ overview: UsageQuotaOverview) -> some View {
        let start = overview.start
        let end = overview.end
        return Chart {
            ForEach(overview.lines) { line in
                ForEach(Array(line.observedSamples.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value(String(localized: "Date"), point.date),
                        y: .value(String(localized: "Remaining Quota"), point.remainingPercent),
                        series: .value(String(localized: "Quota"), line.id.uuidString + "-" + String(point.segment)))
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(self.color(line))
                }
                ForEach(Array(line.observedSamples.enumerated()), id: \.offset) { _, point in
                    PointMark(
                        x: .value(String(localized: "Date"), point.date),
                        y: .value(String(localized: "Remaining Quota"), point.remainingPercent))
                        .foregroundStyle(self.color(line))
                        .symbolSize(point.date == line.observedSamples.last?.date ? 16 : 4)
                }
            }
        }
        .chartXScale(domain: start...end, range: .plotDimension(padding: 12))
        .chartYScale(domain: 0...100, range: .plotDimension(padding: 4))
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let percent = value.as(Double.self) {
                        Text((percent / 100).formatted(.percent.precision(.fractionLength(0))))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: overview.dateTicks()) { value in
                AxisValueLabel(anchor: .top, collisionResolution: .disabled) {
                    if let date = value.as(Date.self) {
                        Text(Calendar.autoupdatingCurrent.component(.day, from: date).formatted())
                            .font(.caption2).monospacedDigit()
                            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                    }
                }
            }
        }
        .chartPlotStyle { $0.clipped() }
        .frame(height: self.dynamicTypeSize.isAccessibilitySize ? 210 : (self.usesCompactLayout ? 140 : 170))
        .accessibilityLabel(String(localized: "Observed remaining quota by date"))
        .accessibilityIdentifier("usage-quota-chart")
    }

    private func legend(_ overview: UsageQuotaOverview) -> some View {
        let visibleLines = Array(overview.lines.prefix(2))
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { self.expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(visibleLines) { line in
                                HStack(spacing: 4) {
                                    Circle().fill(self.color(line)).frame(width: 6, height: 6)
                                    Text(UsageQuotaPresentation.collapsedTitle(
                                        line, visibleLines: visibleLines, providerName: self.providerName(line),
                                        preferences: self.store.preferences, hidesPersonalInfo: self.hidesPersonalInfo))
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if overview.lines.count > 2 {
                        Text("+\(overview.lines.count - 2)").monospacedDigit().fixedSize()
                    }
                    Image(systemName: self.expanded ? "chevron.up" : "chevron.down").font(.caption2)
                }
                .font(.caption).foregroundStyle(.primary)
                .frame(minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(self
                .expanded ? String(localized: "Collapse quota legend") : String(localized: "Expand quota legend"))
            .accessibilityValue(overview.lines.prefix(2).map(self.shortTitle).joined(separator: ", "))
            .accessibilityIdentifier("usage-quota-legend-toggle")
            if self.expanded {
                Divider()
                ForEach(overview.lines) { line in
                    self.legendRow(line)
                }
            }
        }
    }

    private func legendRow(_ line: UsageQuotaResolvedLine) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(self.color(line)).frame(width: 7, height: 7).padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(self.shortTitle(line)).font(.subheadline.weight(.medium))
                Text(UsageQuotaPresentation.accountLabel(
                    self.hidesPersonalInfo ? (line.privateAccountTitle ?? self.providerName(line)) : line.accountTitle,
                    providerID: line.selection.providerID, anchorID: line.selection.accountAnchorID,
                    preferences: self.store.preferences, hidesPersonalInfo: self.hidesPersonalInfo))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if line.usesSyncedProviderHistory {
                    Text(String(localized: "Includes synced provider history"))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if line.state == .available, let reset = line.resetDate {
                    Text(String(
                        format: String(localized: "Resets %@"),
                        reset.formatted(date: .abbreviated, time: .shortened)))
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text(line.isStale ? String(localized: "Out of date") : String(localized: "Waiting for update"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Text(line.state == .available ? SummaryPresentation.percent(line.currentRemainingPercent) : "—")
                .font(.subheadline.weight(.semibold)).monospacedDigit().fixedSize()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("usage-quota-legend-" + line.id.uuidString)
    }

    private func providerName(_ line: UsageQuotaResolvedLine) -> String {
        SummaryPresentation.providerName(id: line.selection.providerID, accounts: self.accounts)
    }

    private func shortTitle(_ line: UsageQuotaResolvedLine) -> String {
        UsageQuotaPresentation.shortTitle(
            line, providerName: self.providerName(line), preferences: self.store.preferences,
            hidesPersonalInfo: self.hidesPersonalInfo)
    }

    private func color(_ line: UsageQuotaResolvedLine) -> Color {
        ProviderColorPalette.color(for: line.selection.providerID, tintHex: line.selection.colorHex)
    }
}
