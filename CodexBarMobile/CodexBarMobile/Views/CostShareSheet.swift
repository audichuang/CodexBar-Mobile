import CodexBarSync
import SwiftUI

struct CostShareSheet: View {
    let insights: CostDashboardInsights
    let providers: [ProviderUsageSnapshot]
    let sourceSnapshots: [SyncedUsageSnapshot]
    let useLedger: Bool
    let isDemoMode: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedPeriod: SharePeriod = .month
    @State private var selectedStyle: ShareCardStyleOption = .classic
    @State private var heatmapWindow: HeatmapShareWindow = .days365
    @State private var selectedProviderID: String?
    @State private var tokenSeries: [TokenActivitySeries] = []
    @State private var isLoadingTokens = true
    @State private var tokenLoadFailed = false
    @State private var activityPresentation: ActivityPresentation?
    @State private var showingRenderError = false

    private var theme: ShareCardTheme {
        .from(self.colorScheme)
    }

    private var shareData: ShareCardData {
        ShareCardData(insights: self.insights, period: self.selectedPeriod)
    }

    private var selectedSeries: [TokenActivitySeries] {
        guard let selectedProviderID else { return self.tokenSeries }
        return self.tokenSeries.filter { $0.id == selectedProviderID }
    }

    private var heatmapData: HeatmapShareData? {
        if self.isDemoMode || ProcessInfo.processInfo.arguments.contains("UI_TEST_PREVIEW_DATA"),
           self.tokenSeries.isEmpty
        {
            return .preview
        }
        guard !self.selectedSeries.isEmpty else { return nil }
        let selected = self.selectedSeries.first
        return HeatmapShareData(
            series: self.selectedSeries,
            sourceTitle: Self.heatmapSourceTitle(
                for: self.selectedProviderID,
                in: self.tokenSeries),
            window: self.heatmapWindow,
            color: Self.heatmapColor(for: self.selectedProviderID == nil ? nil : selected),
            referenceDate: self.insights.referenceDate)
    }

    var body: some View {
        NavigationStack {
            AdaptiveReportPanes(allowsVerticalSplit: true) { paneSize in
                self.preview
                    .frame(maxWidth: paneSize.map { min(560, max(1, $0.height - 40) * 3 / 4) } ?? 560)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            } secondary: {
                VStack(alignment: .leading, spacing: 24) {
                    self.controls
                    self.shareButton
                }
                .padding(20)
            }
            .navigationTitle(String(localized: "Create Share Card"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { self.dismiss() } label: {
                        Label(String(localized: "Close"), systemImage: "xmark")
                    }
                    .accessibilityIdentifier("share-card-close")
                }
            }
            .sheet(item: self.$activityPresentation) { presentation in
                ActivityViewController(activityItems: [presentation.image])
                    .presentationDetents([.medium, .large])
            }
            .alert(String(localized: "Could Not Create Image"), isPresented: self.$showingRenderError) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(String(localized: "Please try again."))
            }
            .task { await self.loadTokenSeries() }
        }
        .presentationDetents([.large])
    }

    private var shareButton: some View {
        Button { self.renderImage() } label: {
            Label(String(localized: "Share Image"), systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
        }
        .buttonStyle(.borderedProminent)
        .disabled(self.selectedStyle == .heatmap && self.heatmapData == nil)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
        .accessibilityIdentifier("share-card-action")
    }

    @ViewBuilder
    private var preview: some View {
        if self.selectedStyle == .heatmap, self.heatmapData == nil {
            RoundedRectangle(cornerRadius: 20)
                .fill(.secondary.opacity(0.08))
                .overlay {
                    VStack(spacing: 12) {
                        if self.isLoadingTokens {
                            ProgressView()
                            Text(String(localized: "Preparing token history…"))
                        } else {
                            Image(systemName: "exclamationmark.triangle")
                            Text(String(localized: "Token history is unavailable."))
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .aspectRatio(3 / 4, contentMode: .fit)
        } else {
            ShareCardPreview(
                period: self.selectedPeriod,
                data: self.shareData,
                theme: self.theme,
                style: self.selectedStyle,
                heatmapData: self.heatmapData)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Template")).font(.headline)
                HStack(spacing: 10) {
                    ForEach(ShareCardStyleOption.allCases) { style in
                        Button {
                            withAnimation(.snappy) { self.selectedStyle = style }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: style.symbol)
                                    .font(.title2)
                                    .frame(height: 28)
                                Text(style.displayName)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 76)
                            .foregroundStyle(self.selectedStyle == style ? Color.accentColor : .primary)
                            .background(
                                self.selectedStyle == style ? Color.accentColor.opacity(0.12) : Color.secondary
                                    .opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(self.selectedStyle == style ? Color.accentColor : .clear, lineWidth: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(self.selectedStyle == style ? .isSelected : [])
                        .accessibilityIdentifier("share-style-" + style.rawValue)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Details")).font(.headline)
                if self.selectedStyle == .heatmap {
                    ShareSelectionRow(
                        title: String(localized: "Range"),
                        value: self.heatmapWindow.displayName,
                        symbol: "calendar",
                        identifier: "share-range-picker")
                    {
                        ForEach(HeatmapShareWindow.allCases) { window in
                            Button { self.heatmapWindow = window } label: {
                                if self.heatmapWindow == window {
                                    Label(window.displayName, systemImage: "checkmark")
                                } else {
                                    Text(window.displayName)
                                }
                            }
                        }
                    }
                    ShareSelectionRow(
                        title: String(localized: "Provider"),
                        value: self.selectedProviderID.flatMap(self.providerTitle(for:))
                            ?? String(localized: "All Providers"),
                        symbol: "circle.hexagongrid",
                        identifier: "share-provider-picker")
                    {
                        Button { self.selectedProviderID = nil } label: {
                            if self.selectedProviderID == nil {
                                Label(String(localized: "All Providers"), systemImage: "checkmark")
                            } else {
                                Text(String(localized: "All Providers"))
                            }
                        }
                        ForEach(self.tokenSeries) { item in
                            Button { self.selectedProviderID = item.id } label: {
                                if self.selectedProviderID == item.id {
                                    Label(
                                        self.providerTitle(for: item.id) ?? item.provider.providerName,
                                        systemImage: "checkmark")
                                } else {
                                    Text(self.providerTitle(for: item.id) ?? item.provider.providerName)
                                }
                            }
                        }
                    }
                } else {
                    ShareSelectionRow(
                        title: String(localized: "Period"),
                        value: self.selectedPeriod.displayName,
                        symbol: "calendar",
                        identifier: "share-period-picker")
                    {
                        ForEach(SharePeriod.allCases) { period in
                            Button { self.selectedPeriod = period } label: {
                                if self.selectedPeriod == period {
                                    Label(period.displayName, systemImage: "checkmark")
                                } else {
                                    Text(period.displayName)
                                }
                            }
                        }
                    }
                }
            }

            Text(self.selectedStyle == .heatmap
                ? String(localized: "One square is one day. Missing history remains different from zero usage.")
                : String(localized: "The preview and shared image always use the same report data."))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if self.tokenLoadFailed, self.selectedStyle == .heatmap {
                Button(String(localized: "Try Again")) {
                    Task { await self.loadTokenSeries() }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func providerTitle(for id: String) -> String? {
        guard self.tokenSeries.contains(where: { $0.id == id }) else { return nil }
        return Self.heatmapSourceTitle(for: id, in: self.tokenSeries)
    }

    static func heatmapSourceTitle(
        for selectedProviderID: String?,
        in tokenSeries: [TokenActivitySeries]) -> String
    {
        guard let selectedProviderID,
              let item = tokenSeries.first(where: { $0.id == selectedProviderID })
        else {
            return String(localized: "All Providers")
        }
        let duplicates = tokenSeries.filter { $0.provider.providerName == item.provider.providerName }
        guard duplicates.count > 1 else { return item.provider.providerName }
        if let email = item.provider.accountEmail, !email.isEmpty {
            return item.provider.providerName + " · " + email
        }
        if let loginMethod = item.provider.loginMethod,
           !loginMethod.isEmpty,
           duplicates.count(where: { $0.provider.loginMethod == loginMethod }) == 1
        {
            return item.provider.providerName + " · " + loginMethod
        }
        let ordinal = (duplicates.firstIndex(where: { $0.id == item.id }) ?? 0) + 1
        return item.provider.providerName + " · " + String.localizedStringWithFormat(
            String(localized: "Account %lld"), ordinal)
    }

    static func heatmapColor(for selectedSeries: TokenActivitySeries?) -> Color {
        selectedSeries.map { ProviderColorPalette.color(for: $0.provider) } ?? .blue
    }

    static func usesSideBySideLayout(width: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Bool {
        width >= 700 && !dynamicTypeSize.isAccessibilitySize
    }

    @MainActor
    private func loadTokenSeries() async {
        self.isLoadingTokens = true
        self.tokenLoadFailed = false
        do {
            let result = if self.useLedger, !self.isDemoMode {
                try await CostHistoryWorker.shared.tokenActivity(
                    providers: self.providers,
                    sourceSnapshots: self.sourceSnapshots,
                    referenceDate: self.insights.referenceDate)
            } else {
                try await CostHistoryWorker.shared.snapshotTokenActivity(
                    providers: self.providers,
                    referenceDate: self.insights.referenceDate)
            }
            guard !Task.isCancelled else { return }
            self.tokenSeries = result
            self.isLoadingTokens = false
        } catch {
            guard !Task.isCancelled else { return }
            self.tokenLoadFailed = true
            self.isLoadingTokens = false
        }
    }

    @MainActor
    private func renderImage() {
        let image = CostShareService.renderImage(
            period: self.selectedPeriod,
            data: self.shareData,
            theme: self.theme,
            style: self.selectedStyle,
            heatmapData: self.heatmapData)
        guard let image else {
            self.showingRenderError = true
            return
        }
        self.activityPresentation = ActivityPresentation(image: image)
    }
}

private struct ActivityPresentation: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ShareCardPreview: View {
    let period: SharePeriod
    let data: ShareCardData
    let theme: ShareCardTheme
    let style: ShareCardStyleOption
    let heatmapData: HeatmapShareData?

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 390, proxy.size.height / 520)
            CostShareCardView(
                period: self.period,
                data: self.data,
                theme: self.theme,
                style: self.style,
                heatmapData: self.heatmapData)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.16), radius: 16, y: 7)
                .scaleEffect(scale)
                .frame(width: 390 * scale, height: 520 * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("share-card-preview")
    }
}

private struct ShareSelectionRow<Content: View>: View {
    let title: String
    let value: String
    let symbol: String
    let identifier: String
    @ViewBuilder let content: Content

    var body: some View {
        Menu {
            self.content
        } label: {
            HStack(spacing: 12) {
                Image(systemName: self.symbol)
                    .frame(width: 24)
                    .foregroundStyle(.secondary)
                Text(self.title)
                Spacer()
                Text(self.value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(self.title + ", " + self.value)
        .accessibilityIdentifier(self.identifier)
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: self.activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    CostShareSheet(
        insights: CostDashboardInsights(snapshot: PreviewData.sampleSnapshot),
        providers: PreviewData.sampleSnapshot.providers,
        sourceSnapshots: [],
        useLedger: false,
        isDemoMode: true)
}
