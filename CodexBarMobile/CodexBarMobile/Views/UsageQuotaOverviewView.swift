import Charts
import CodexBarSync
import SwiftUI

/// A shared date axis for independent account/window quotas. All future marks are estimates.
struct UsageQuotaOverviewView: View {
    @ObservedObject var store: UsageQuotaOverviewStore
    let accounts: [ProviderUsageSnapshot]
    let linkages: [ProviderAccountLinkage]
    var sourceSnapshots: [SyncedUsageSnapshot]?
    var quotaSources: [String: SyncProviderQuotaSource]?
    let publicationRevision: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(MobileSettingsKeys.hidePersonalInfo) private var hidesPersonalInfo = false
    @State private var expanded = false
    @State private var showingEditor = false
    @State private var showingExplanation = false
    @State private var nextDayOnly = false
    @State private var chartWidth: CGFloat = 0

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
                            localized: "The chart starts at each account’s current remaining quota. Each line ends at that window’s reset, or when its quota is estimated to run out."))
                    Text(
                        String(
                            localized: "Future consumption is estimated. With enough observations, the estimate follows this account’s measured busy and idle periods. Until then, it uses the average consumption since the window began. Actual usage may differ."))
                    Text(
                        String(
                            localized: "Observations are collected on this iPhone from synced account data. Missing or outdated readings are not treated as new activity."))
                }
                .navigationTitle(String(localized: "About Quota Estimates"))
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Remaining Quota")).font(.headline)
                Spacer(minLength: 8)
                Button { self.showingEditor = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(minWidth: 32, minHeight: 32)
                }
                .accessibilityLabel(String(localized: "Choose quota lines"))
                .accessibilityIdentifier("usage-quota-edit")
            }
            if self.store.isReadOnly {
                Text(String(localized: "Saved quota settings could not be read. They have been kept unchanged."))
                    .font(.caption).foregroundStyle(.secondary)
            } else if overview.lines.isEmpty {
                Text(String(localized: "Choose up to 5 account quotas to compare their remaining time and balance."))
                    .font(.subheadline).foregroundStyle(.secondary)
                Button(String(localized: "Choose quota lines")) { self.showingEditor = true }
                    .buttonStyle(.bordered)
            } else {
                HStack {
                    Button { self.showingExplanation = true } label: {
                        Label(String(localized: "Estimated"), systemImage: "info.circle")
                            .font(.caption)
                    }
                    .accessibilityIdentifier("usage-quota-info")
                    Spacer(minLength: 6)
                    Menu {
                        Button(String(localized: "All dates")) { self.nextDayOnly = false }
                        Button(String(localized: "Next 24 hours")) { self.nextDayOnly = true }
                    } label: {
                        HStack(spacing: 4) {
                            Text(self.nextDayOnly ? String(localized: "Next 24 hours") : String(localized: "All dates"))
                            Image(systemName: "chevron.down").font(.caption2)
                        }.font(.caption)
                    }
                    .accessibilityIdentifier("usage-quota-range")
                }
                self.chart(overview)
                self.legend(overview)
            }
        }
        .padding(16)
        .background(MobileSurfaceStyle.cardMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("usage-quota-overview")
    }

    private func chart(_ overview: UsageQuotaOverview) -> some View {
        let end = self.nextDayOnly ? min(overview.end, overview.start.addingTimeInterval(86400)) : overview.end
        return Chart {
            ForEach(overview.lines) { line in
                ForEach(Array(line.estimatedSamples.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value(String(localized: "Date"), point.date),
                        y: .value(String(localized: "Remaining Quota"), point.remainingPercent),
                        series: .value(String(localized: "Quota"), line.id.uuidString))
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(self.color(line))
                }
                if line.state == .available, let remaining = line.currentRemainingPercent {
                    PointMark(
                        x: .value(String(localized: "Date"), overview.start),
                        y: .value(String(localized: "Remaining Quota"), remaining))
                        .foregroundStyle(self.color(line))
                        .symbolSize(16)
                }
            }
        }
        .chartXScale(domain: overview.start...max(end, overview.start.addingTimeInterval(60)))
        .chartYScale(domain: 0...100)
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
            AxisMarks(values: self.dynamicTypeSize.isAccessibilitySize || self
                .chartWidth < 300 ? [overview.start, end] : [
                    overview.start,
                    overview.start.addingTimeInterval(end.timeIntervalSince(overview.start) / 2),
                    end,
                ]) { value in
                    AxisValueLabel(
                        anchor: value.as(Date.self) == overview
                            .start ? .topLeading : (value.as(Date.self) == end ? .topTrailing : .top),
                        collisionResolution: .disabled)
                    {
                        if let date = value.as(Date.self) {
                            if date == overview.start {
                                Text(String(localized: "Now")).font(.caption2)
                            } else if end.timeIntervalSince(overview.start) <= 86400 {
                                Text(date, format: .dateTime.hour().minute()).font(.caption2)
                            } else {
                                Text(date, format: .dateTime.month(.abbreviated).day()).font(.caption2)
                            }
                        }
                    }
                }
        }
        .chartPlotStyle { $0.clipped() }
        .frame(height: self.dynamicTypeSize.isAccessibilitySize ? 210 : 170)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { self.chartWidth = $0 }
        .accessibilityLabel(String(localized: "Estimated remaining quota by date"))
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
