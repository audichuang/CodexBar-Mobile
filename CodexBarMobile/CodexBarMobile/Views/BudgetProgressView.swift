import CodexBarSync
import SwiftUI

struct BudgetProgressView: View {
    @Environment(\.locale) private var locale
    let budget: SyncBudgetSnapshot
    let providerID: String
    var tintColor: Color = .blue

    private var progress: Double {
        guard self.budget.limitAmount > 0 else { return 0 }
        return min(self.budget.usedAmount / self.budget.limitAmount, 1.0)
    }

    private var progressColor: Color {
        // 70% (orange) / 90% (red) thresholds deliberately match
        // `UsageCardView.usageColor` so every quota-like bar in the app
        // turns the same color at the same percentage. Users learn the
        // semantic once ("orange = close, red = critical") and it applies
        // across rate limits, budgets, and any future quota-shaped UI.
        // If you adjust here, adjust `UsageCardView` in the same commit.
        if self.progress >= 0.9 { return .red }
        if self.progress >= 0.7 { return .orange }
        return self.tintColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Budget").font(.subheadline.weight(.semibold))
                        .fixedSize()
                    Spacer()
                    Text(self.formattedUsed).font(.subheadline.monospacedDigit().weight(.medium))
                        .fixedSize()
                    Text("/ \(self.formattedLimit)").font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary).fixedSize()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Budget").font(.subheadline.weight(.semibold))
                    Text("\(self.formattedUsed) / \(self.formattedLimit)")
                        .font(.subheadline.monospacedDigit())
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ProgressView(value: self.progress)
                .tint(self.progressColor)
                .scaleEffect(y: 2, anchor: .center)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                if let target = DailyAllowanceTarget(budget: self.budget, now: context.date) {
                    Text(target.text(locale: self.locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("budget.daily-target")
                }
            }

            HStack(spacing: 8) {
                if let period = self.budget.period {
                    Text(Self.localizedPeriod(period, providerID: self.providerID))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let resetsAt = self.budget.resetsAt {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                        Text("\(String(localized: "Resets")) \(resetsAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var formattedUsed: String {
        Self.formatCurrency(self.budget.usedAmount, code: self.budget.currencyCode)
    }

    private var formattedLimit: String {
        Self.formatCurrency(self.budget.limitAmount, code: self.budget.currencyCode)
    }

    static func localizedPeriod(
        _ period: String,
        providerID: String,
        locale: Locale = .current) -> String
    {
        ProviderDetailLocalization.localized(period, providerID: providerID, locale: locale)
    }

    static func formatCurrency(_ value: Double, code: String) -> String {
        if code == "Credits" {
            return ProviderAmountCard.formattedAmount(value, currencyCode: code)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

#Preview {
    BudgetProgressView(
        budget: SyncBudgetSnapshot(
            usedAmount: 42.50,
            limitAmount: 100.0,
            currencyCode: "USD",
            period: "Monthly",
            resetsAt: Date().addingTimeInterval(3600 * 24 * 12)),
        providerID: "example",
        tintColor: .orange)
        .padding()
}
