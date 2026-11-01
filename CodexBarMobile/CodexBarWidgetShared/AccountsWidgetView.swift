import SwiftUI
import WidgetKit

/// The accounts widget (`WidgetKinds.accountsAppIntent`): one row per account
/// of one provider, each with its session and weekly usage, colored by how
/// full it is so the account about to run out stands out.
struct AccountsWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var environmentFamily

    let entry: CodexBarWidgetEntry
    let previewFamily: WidgetFamily?

    init(entry: CodexBarWidgetEntry, previewFamily: WidgetFamily? = nil) {
        self.entry = entry
        self.previewFamily = previewFamily
    }

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
        .padding(self.family == .systemSmall ? 12 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            self.colorScheme == .dark
                ? Color(red: 0.02, green: 0.02, blue: 0.02)
                : Color(red: 0.97, green: 0.97, blue: 0.96)
        }
    }

    private var family: WidgetFamily {
        self.previewFamily ?? self.environmentFamily
    }

    /// Every account of the provider, the one that runs out first on top.
    private var rankedAccounts: [CodexBarWidgetProviderSummary] {
        WidgetProviderSelection.accountsByUrgency(
            from: self.entry.snapshot.topProviders,
            selected: self.entry.configuration.providers?.first,
            now: self.entry.date)
    }

    private var accountLimit: Int {
        self.family == .systemLarge || self.family == .systemExtraLarge ? 6 : 3
    }

    private var isLarge: Bool {
        self.family == .systemLarge || self.family == .systemExtraLarge
    }

    private var loadedView: some View {
        let ranked = self.rankedAccounts
        let accounts = Array(ranked.prefix(self.accountLimit))
        return VStack(alignment: .leading, spacing: self.family == .systemSmall ? 7 : 9) {
            self.header(
                accounts,
                switchTo: WidgetProviderSelection.accountToSwitchTo(from: ranked, now: self.entry.date))
            if self.family == .systemSmall, let first = accounts.first(where: { !$0.isError }) {
                self.compactColumnTitles(first)
            }
            if accounts.isEmpty {
                self.message(String(localized: "No provider data"))
            } else {
                let reservesSession = accounts.contains { !$0.isError && $0.sessionUsedPercent != nil }
                ForEach(accounts) { account in
                    if self.family == .systemSmall {
                        self.compactRow(account)
                    } else {
                        if self.isLarge, account.id != accounts.first?.id {
                            Divider().overlay(self.track)
                        }
                        self.row(account, reservesSession: reservesSession)
                            // A large widget spreads its rows instead of leaving the bottom empty.
                                .frame(maxHeight: self.isLarge ? .infinity : nil)
                    }
                }
            }
            if !self.isLarge { Spacer(minLength: 0) }
            if self.family == .systemSmall, let warning = self.compactWarning(accounts.first) {
                warning
            }
        }
    }

    private func header(
        _ accounts: [CodexBarWidgetProviderSummary],
        switchTo: CodexBarWidgetProviderSummary?) -> some View
    {
        HStack(spacing: 4) {
            Text(accounts.first?.providerName ?? String(localized: "Account Quotas"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(self.secondary)
                .lineLimit(1)
                .layoutPriority(1)
            if let label = switchTo?.accountLabel {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .accessibilityHidden(true)
                    Text(label)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .privacySensitive()
                }
                .foregroundStyle(WidgetRiskColor.safe(self.colorScheme))
                .widgetAccentable()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: String(localized: "Switch to %@"), label))
            }
            Spacer(minLength: 4)
            // The oldest report on screen: one fresh account must not vouch for the others.
            if let oldest = accounts.filter({ !$0.isError }).map(\.lastUpdated).min() {
                let isOld = self.entry.snapshot.isStale || WidgetFreshnessText.isOld(oldest, now: self.entry.date)
                HStack(spacing: 2) {
                    if isOld {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .accessibilityHidden(true)
                    }
                    Text(WidgetFreshnessText.text(since: oldest, now: self.entry.date))
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .foregroundStyle(isOld ? Color.orange : self.secondary)
            }
        }
    }

    /// Names the two columns of the compact rows, right above their figures.
    private func compactColumnTitles(_ account: CodexBarWidgetProviderSummary) -> some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            if account.sessionUsedPercent != nil {
                self.compactColumnTitle(self.sessionLabel(account))
            }
            self.compactColumnTitle(String(localized: "Week"))
        }
        .padding(.bottom, -4)
    }

    private func compactColumnTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(self.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: Self.compactColumnWidth, alignment: .trailing)
    }

    /// Fixed so "100%" and "8%" keep the same column from row to row.
    private static let compactColumnWidth: CGFloat = 38

    @ViewBuilder
    private func row(_ account: CodexBarWidgetProviderSummary, reservesSession: Bool) -> some View {
        if self.isLarge {
            // The name gets its own line so both meters span the width.
            VStack(alignment: .leading, spacing: 6) {
                self.name(account, size: 16)
                HStack(spacing: 14) { self.meters(account, reservesSession: reservesSession) }
            }
        } else {
            HStack(alignment: .center, spacing: 10) {
                self.name(account, size: 14)
                    .frame(width: 58, alignment: .leading)
                self.meters(account, reservesSession: reservesSession)
            }
        }
    }

    /// The compact rows have no room for a time, so the top account's gets its own line.
    private func compactWarning(_ account: CodexBarWidgetProviderSummary?) -> AnyView? {
        guard let account, !account.isError else { return nil }
        let now = self.entry.date
        let forecasts = [account.sessionForecast(now: now), account.weeklyForecast(now: now)].compactMap(\.self)
        let urgent = forecasts.filter(\.isAtRisk).min {
            ($0.depletesAt ?? .distantFuture) < ($1.depletesAt ?? .distantFuture)
        }
        guard let text = urgent?.riskText(now: now) else { return nil }
        return AnyView(
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .accessibilityHidden(true)
                Text(account.accountLabel.map { "\($0) \(text)" } ?? text)
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .privacySensitive()
            }
            .foregroundStyle(WidgetRiskColor.color(self.colorScheme)))
    }

    @ViewBuilder
    private func meters(_ account: CodexBarWidgetProviderSummary, reservesSession: Bool) -> some View {
        if account.isError {
            Text(String(localized: "Unavailable"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(self.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            if account.sessionUsedPercent != nil {
                self.meter(
                    label: self.sessionLabel(account),
                    percent: account.sessionUsedPercent,
                    detail: WidgetProviderResetText.hours(account.sessionResetsAt, now: self.entry.date),
                    forecast: account.sessionForecast(now: self.entry.date))
            } else if reservesSession {
                // Keeps the weekly meter in the same column as the other rows.
                Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
            }
            self.meter(
                label: String(localized: "Week"),
                percent: account.weeklyUsedPercent,
                detail: WidgetProviderResetText.days(account.weeklyResetsAt, now: self.entry.date),
                forecast: account.weeklyForecast(now: self.entry.date))
        }
    }

    private func compactRow(_ account: CodexBarWidgetProviderSummary) -> some View {
        HStack(spacing: 6) {
            self.name(account, size: 13)
            Spacer(minLength: 2)
            if account.isError {
                Text(String(localized: "Unavailable"))
                    .font(.system(size: 11))
                    .foregroundStyle(self.secondary)
            } else {
                HStack(spacing: 4) {
                    if account.sessionUsedPercent != nil {
                        self.compactFigure(
                            account.sessionUsedPercent,
                            forecast: account.sessionForecast(now: self.entry.date))
                    }
                    self.compactFigure(
                        account.weeklyUsedPercent,
                        forecast: account.weeklyForecast(now: self.entry.date))
                }
            }
        }
    }

    private func name(_ account: CodexBarWidgetProviderSummary, size: CGFloat) -> some View {
        Text(account.accountLabel ?? account.providerName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(self.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .privacySensitive()
    }

    private func compactFigure(_ percent: Double?, forecast: WidgetQuotaForecast?) -> some View {
        self.percentText(percent, size: 14, isAtRisk: forecast?.isAtRisk == true)
            .frame(width: Self.compactColumnWidth, alignment: .trailing)
    }

    private func meter(label: String, percent: Double?, detail: String?, forecast: WidgetQuotaForecast?) -> some View {
        let risk = forecast?.riskText(now: self.entry.date)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(self.secondary)
                self.percentText(percent, size: self.isLarge ? 20 : 15, isAtRisk: risk != nil)
                Spacer(minLength: 2)
                // When it ends before the reset, that moment matters more than the reset.
                if let text = risk ?? detail {
                    Text(text)
                        .font(.system(size: 10, weight: risk == nil ? .regular : .semibold))
                        .monospacedDigit()
                        .foregroundStyle(risk == nil ? self.secondary : WidgetRiskColor.color(self.colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            self.bar(percent, height: self.isLarge ? 6 : 4, isAtRisk: risk != nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percentText(_ percent: Double?, size: CGFloat, isAtRisk: Bool) -> some View {
        Text(percent.map { (min(100, max(0, $0)) / 100).formatted(.percent.precision(.fractionLength(0))) } ?? "—")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(isAtRisk ? WidgetRiskColor.color(self.colorScheme) : self.usageColor(percent))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .privacySensitive()
            .widgetAccentable()
    }

    private func bar(_ percent: Double?, height: CGFloat, isAtRisk: Bool) -> some View {
        GeometryReader { proxy in
            let fraction = min(1, max(0, (percent ?? 0) / 100))
            ZStack(alignment: .leading) {
                Capsule().fill(self.track)
                if fraction > 0 {
                    Capsule()
                        .fill(isAtRisk ? WidgetRiskColor.color(self.colorScheme) : self.usageColor(percent))
                        .frame(width: max(4, proxy.size.width * fraction))
                        .widgetAccentable()
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func sessionLabel(_ account: CodexBarWidgetProviderSummary) -> String {
        guard let minutes = account.sessionWindowMinutes, minutes >= 60, minutes % 60 == 0 else {
            return String(localized: "Session")
        }
        return String(format: String(localized: "%@h"), "\(minutes / 60)")
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(self.secondary)
    }

    /// Green until 70%, orange until 90%, then red.
    private func usageColor(_ percent: Double?) -> Color {
        guard let percent else { return self.secondary }
        let dark = self.colorScheme == .dark
        if percent >= 90 {
            return dark ? Color(red: 1.0, green: 0.43, blue: 0.40) : Color(red: 0.80, green: 0.12, blue: 0.14)
        }
        if percent >= 70 {
            return dark ? Color(red: 1.0, green: 0.70, blue: 0.28) : Color(red: 0.80, green: 0.46, blue: 0.00)
        }
        return dark ? Color(red: 0.34, green: 0.84, blue: 0.56) : Color(red: 0.05, green: 0.56, blue: 0.30)
    }

    private var primary: Color {
        self.colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.88)
    }

    private var secondary: Color {
        self.colorScheme == .dark ? Color.white.opacity(0.58) : Color.black.opacity(0.52)
    }

    private var track: Color {
        self.colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.10)
    }
}
