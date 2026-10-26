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

    private var accounts: [CodexBarWidgetProviderSummary] {
        WidgetProviderSelection.accounts(
            from: self.entry.snapshot.topProviders,
            selected: self.entry.configuration.providers?.first,
            count: self.family == .systemLarge || self.family == .systemExtraLarge ? 6 : 3,
            now: self.entry.date)
    }

    private var isLarge: Bool {
        self.family == .systemLarge || self.family == .systemExtraLarge
    }

    private var loadedView: some View {
        let accounts = self.accounts
        return VStack(alignment: .leading, spacing: self.family == .systemSmall ? 8 : 10) {
            self.header(accounts)
            if accounts.isEmpty {
                self.message(String(localized: "No provider data"))
            } else {
                ForEach(accounts) { account in
                    if self.family == .systemSmall {
                        self.compactRow(account)
                    } else {
                        self.row(account)
                            // A large widget spreads its rows instead of leaving the bottom empty.
                                .frame(maxHeight: self.isLarge ? .infinity : nil)
                    }
                }
            }
            if !self.isLarge { Spacer(minLength: 0) }
        }
    }

    private func header(_ accounts: [CodexBarWidgetProviderSummary]) -> some View {
        HStack(spacing: 4) {
            Text(accounts.first?.providerName ?? String(localized: "Account Quotas"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(self.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if self.family == .systemSmall, let first = accounts.first(where: { !$0.isError }) {
                // Names the two columns of the compact rows.
                Text(first.sessionUsedPercent == nil
                    ? String(localized: "Week")
                    : "\(self.sessionLabel(first)) · \(String(localized: "Week"))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(self.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if self.entry.snapshot.isStale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.orange)
                    .accessibilityLabel(String(localized: "Stale"))
            }
        }
    }

    @ViewBuilder
    private func row(_ account: CodexBarWidgetProviderSummary) -> some View {
        if self.isLarge {
            // The name gets its own line so both meters span the width.
            VStack(alignment: .leading, spacing: 6) {
                self.name(account, size: 16)
                HStack(spacing: 14) { self.meters(account) }
            }
        } else {
            HStack(alignment: .center, spacing: 10) {
                self.name(account, size: 14)
                    .frame(width: 58, alignment: .leading)
                self.meters(account)
            }
        }
    }

    @ViewBuilder
    private func meters(_ account: CodexBarWidgetProviderSummary) -> some View {
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
                    detail: WidgetProviderResetText.hours(account.sessionResetsAt, now: self.entry.date))
            }
            self.meter(
                label: String(localized: "Week"),
                percent: account.weeklyUsedPercent,
                detail: WidgetProviderResetText.days(account.weeklyResetsAt, now: self.entry.date))
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
                if account.sessionUsedPercent != nil {
                    self.percentText(account.sessionUsedPercent, size: 14)
                }
                self.percentText(account.weeklyUsedPercent, size: 14)
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

    private func meter(label: String, percent: Double?, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(self.secondary)
                self.percentText(percent, size: self.isLarge ? 20 : 15)
                Spacer(minLength: 2)
                if let detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(self.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            self.bar(percent, height: self.isLarge ? 6 : 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percentText(_ percent: Double?, size: CGFloat) -> some View {
        Text(percent.map { (min(100, max(0, $0)) / 100).formatted(.percent.precision(.fractionLength(0))) } ?? "—")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(self.usageColor(percent))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .privacySensitive()
            .widgetAccentable()
    }

    private func bar(_ percent: Double?, height: CGFloat) -> some View {
        GeometryReader { proxy in
            let fraction = min(1, max(0, (percent ?? 0) / 100))
            ZStack(alignment: .leading) {
                Capsule().fill(self.track)
                if fraction > 0 {
                    Capsule()
                        .fill(self.usageColor(percent))
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
