import CodexBarSync
import SwiftUI

/// Keep the information needed to choose an account next to its detail.
/// Group representatives are not totals, so a collapsed multi-account group
/// deliberately shows its account count rather than one account's quota.
struct UsageSidebarSummary: View {
    let provider: ProviderUsageSnapshot
    let accountCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if self.accountCount > 1 {
                Text(String(format: String(localized: "provider-account-count-label"), self.accountCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(self.provider.allRateWindows.prefix(2).enumerated()), id: \.offset) { index, window in
                    let warning = self.provider.quotaWarning(
                        forWindowIndex: index, windowID: window.id, period: window.period)
                    UsageCardView(
                        label: ProviderWindowLabel.localized(
                            window.label,
                            fallback: self.defaultLabel(at: index),
                            providerID: self.provider.providerID,
                            period: window.period),
                        window: window,
                        providerID: self.provider.providerID,
                        tintColor: ProviderColorPalette.color(for: self.provider),
                        quotaWarningThresholds: warning.thresholds,
                        quotaWarningsEnabled: warning.enabled,
                        isEstimated: self.provider.usageDataConfidence == "estimated")
                }
                if let amount = self.provider.providerAmount {
                    ProviderAmountCard(amount: amount, tintColor: ProviderColorPalette.color(for: self.provider))
                } else if self.provider.allRateWindows.isEmpty, let section = self.provider.details.first {
                    ProviderDetailsTeaserView(providerID: self.provider.providerID, section: section)
                }
            }
            if let message = self.provider.statusMessage {
                Label(
                    ProviderDetailLocalization.localizedStatusMessage(message, isError: self.provider.isError),
                    systemImage: self.provider.isError ? "exclamationmark.triangle" : "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let status = ProviderSourceStatus.resolve(provider: self.provider),
               ProviderSourceNoticeContent(status: status, now: Date()) != nil
            {
                ProviderSourceNoticeView(status: status)
            }
        }
        .accessibilityIdentifier("usage-sidebar-summary-" + self.provider.providerID)
    }

    // Older snapshots omit window labels. Keep the same provider-specific
    // fallback as the full usage card and detail, so the two panes agree.
    private func defaultLabel(at index: Int) -> String {
        if self.provider.providerID == "xkiro", index == 0 {
            return String(localized: "Daily free tokens")
        }
        if self.provider.providerID == "aixy" {
            return String(localized: index == 0 ? "Budget" : "Secondary budget")
        }
        return String(localized: index == 0 ? "Session" : "Weekly")
    }

}
