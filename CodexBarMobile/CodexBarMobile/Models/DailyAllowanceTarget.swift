import CodexBarSync
import Foundation

/// Remaining allowance spread over local calendar days, including today.
/// This is a target, not a measurement or an extrapolated consumption history.
struct DailyAllowanceTarget: Equatable {
    let amount: Double
    let unit: String

    init?(window: SyncRateWindow, now: Date, calendar: Calendar = .current) {
        let monthlyDuration = window.windowMinutes.map { (28.0...31.0).contains((Double($0) / 1440).rounded()) }
            ?? false
        guard window.period == .monthly || monthlyDuration,
              window.usageKnown, !window.isSyntheticPlaceholder, window.blockingQuota == nil,
              window.usedPercent.isFinite, window.usedPercent >= 0
        else { return nil }
        let limit = window.quotaLimit ?? 100
        guard limit.isFinite, limit > 0 else { return nil }
        self.init(
            remaining: limit * max(0, 100 - window.usedPercent) / 100,
            unit: window.quotaLimit == nil ? "%" : (window.quotaUnit ?? ""),
            resetsAt: window.resetsAt, now: now, calendar: calendar)
    }

    init?(budget: SyncBudgetSnapshot, now: Date, calendar: Calendar = .current) {
        guard ["monthly", "month", "this month", "monthly cap", "monthly credit limit"]
            .contains(budget.period?.lowercased() ?? ""),
            budget.limitAmount.isFinite, budget.limitAmount > 0,
            budget.usedAmount.isFinite, budget.usedAmount >= 0
        else { return nil }
        self.init(
            remaining: max(0, budget.limitAmount - budget.usedAmount),
            unit: budget.currencyCode, resetsAt: budget.resetsAt, now: now, calendar: calendar)
    }

    private init?(remaining: Double, unit: String, resetsAt: Date?, now: Date, calendar: Calendar) {
        guard remaining.isFinite, remaining >= 0,
              now.timeIntervalSince1970.isFinite,
              let resetsAt, resetsAt.timeIntervalSince1970.isFinite, resetsAt > now,
              let resetDay = calendar.dateInterval(of: .day, for: resetsAt),
              let days = calendar.dateComponents(
                  [.day], from: calendar.startOfDay(for: now), to: resetDay.start).day
        else { return nil }
        self.amount = remaining / Double(max(1, days + (resetsAt > resetDay.start ? 1 : 0)))
        self.unit = unit
    }

    func text(locale: Locale = .current) -> String {
        let value: String
        if self.unit == "%" {
            value = (self.amount / 100).formatted(.percent.precision(.fractionLength(0...1)).locale(locale))
        } else if Locale.commonISOCurrencyCodes.contains(self.unit.uppercased()) {
            value = self.amount.formatted(.currency(code: self.unit.uppercased()).locale(locale))
        } else {
            let number = self.amount.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
            let key: String? = switch self.unit.lowercased() {
            case "credits": "Credits"
            case "requests": "Requests"
            case "tokens": "tokens"
            case "points": "points"
            default: nil
            }
            let unit = key.map { MobileLocalizedString.value($0, defaultValue: self.unit, locale: locale) } ?? self.unit
            value = unit.isEmpty ? number : "\(number) \(unit)"
        }
        return String(
            format: MobileLocalizedString.value(
                "Daily target: %@ per day", defaultValue: "Daily target: %@ per day", locale: locale),
            locale: locale, arguments: [value])
    }
}
