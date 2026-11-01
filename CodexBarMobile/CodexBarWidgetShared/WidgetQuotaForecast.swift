import Foundation
import SwiftUI

// Fork: turns a window's used percent into "will it last until the reset?" for
// the Provider Quota and Account Quotas widgets.

/// Linear projection from the Mac's latest observation. Unlike `QuotaPace`,
/// which only covers windows of at least a day, this also covers the 5-hour
/// session, where running out is most likely.
struct WidgetQuotaForecast: Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        case lasts
        case runsOut(Date)
        case usedUp
    }

    /// Under this share of the window the rate is too noisy: 5% used in the
    /// first two minutes of a session would predict running out within the hour.
    static let minimumElapsedShare = 0.05

    let outcome: Outcome

    init?(usedPercent: Double?, resetsAt: Date?, windowMinutes: Int?, capturedAt: Date, now: Date) {
        guard let usedPercent, usedPercent.isFinite, usedPercent >= 0,
              let resetsAt, resetsAt > now,
              let windowMinutes, windowMinutes > 0
        else { return nil }
        if usedPercent >= 100 {
            self.outcome = .usedUp
            return
        }
        let duration = Double(windowMinutes) * 60
        let elapsed = duration - resetsAt.timeIntervalSince(capturedAt)
        // Negative elapsed: the observation predates this window (a rolled-over reset).
        guard elapsed >= duration * Self.minimumElapsedShare, elapsed <= duration else { return nil }
        guard usedPercent > 0 else {
            self.outcome = .lasts
            return
        }
        let emptyAt = capturedAt.addingTimeInterval((100 - usedPercent) * elapsed / usedPercent)
        self.outcome = emptyAt < resetsAt ? .runsOut(emptyAt) : .lasts
    }

    /// When it ends before the reset. `.distantPast` for already used up, so
    /// sorting by this date puts the most urgent first.
    var depletesAt: Date? {
        switch self.outcome {
        case .lasts: nil
        case let .runsOut(date): date
        case .usedUp: .distantPast
        }
    }

    var isAtRisk: Bool {
        self.depletesAt != nil
    }

    /// "14:05 用完", the words a glance needs. Nil when it lasts.
    func riskText(now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String? {
        switch self.outcome {
        case .lasts:
            return nil
        case .usedUp:
            return String(localized: "Used up")
        case let .runsOut(date):
            // The Mac has not reported since: the projected moment already passed.
            guard date > now else { return String(localized: "Likely used up") }
            let clock = Self.clock(date, now: now, calendar: calendar, locale: locale)
            return String(format: String(localized: "Out %@"), clock)
        }
    }

    private static func clock(_ date: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(calendar.isDate(date, inSameDayAs: now) ? "HHmm" : "EEEHHmm")
        return formatter.string(from: date)
    }
}

extension CodexBarWidgetProviderSummary {
    func sessionForecast(now: Date) -> WidgetQuotaForecast? {
        WidgetQuotaForecast(
            usedPercent: self.sessionUsedPercent,
            resetsAt: self.sessionResetsAt,
            windowMinutes: self.sessionWindowMinutes,
            capturedAt: self.lastUpdated,
            now: now)
    }

    func weeklyForecast(now: Date) -> WidgetQuotaForecast? {
        WidgetQuotaForecast(
            usedPercent: self.weeklyUsedPercent,
            resetsAt: self.weeklyResetsAt,
            windowMinutes: 7 * 24 * 60,
            capturedAt: self.lastUpdated,
            now: now)
    }

    /// The soonest moment any window of this account ends before its reset.
    func depletesAt(now: Date) -> Date? {
        [self.sessionForecast(now: now), self.weeklyForecast(now: now)]
            .compactMap { $0?.depletesAt }
            .min()
    }

    var highestUsedPercent: Double {
        max(self.sessionUsedPercent ?? 0, self.weeklyUsedPercent ?? 0)
    }
}

extension WidgetProviderSelection {
    /// A provider's accounts, the one that runs out first on top, then by how
    /// full they are, with unavailable accounts last. Ranked before truncating
    /// so an urgent account is never cut off a small widget.
    static func accountsByUrgency(
        from providers: [CodexBarWidgetProviderSummary],
        selected: WidgetProviderEntity?,
        now: Date) -> [CodexBarWidgetProviderSummary]
    {
        self.accounts(from: providers, selected: selected, count: .max, now: now).sorted { lhs, rhs in
            if lhs.isError != rhs.isError { return rhs.isError }
            let left = lhs.depletesAt(now: now)
            let right = rhs.depletesAt(now: now)
            if left != right {
                guard let left else { return false }
                guard let right else { return true }
                return left < right
            }
            if lhs.highestUsedPercent != rhs.highestUsedPercent {
                return lhs.highestUsedPercent > rhs.highestUsedPercent
            }
            return (lhs.accountLabel ?? lhs.id).localizedStandardCompare(rhs.accountLabel ?? rhs.id)
                == .orderedAscending
        }
    }

    /// The account to move to: only when the top account is in trouble and
    /// another one lasts, picking the emptiest. `accounts` is urgency-ranked.
    static func accountToSwitchTo(
        from accounts: [CodexBarWidgetProviderSummary],
        now: Date) -> CodexBarWidgetProviderSummary?
    {
        guard let top = accounts.first, !top.isError, top.depletesAt(now: now) != nil else { return nil }
        return accounts
            .dropFirst()
            .filter { !$0.isError && $0.depletesAt(now: now) == nil }
            .min { $0.highestUsedPercent < $1.highestUsedPercent }
    }
}

/// How old the Mac's last report is, as the widgets show it.
enum WidgetFreshnessText {
    /// Past this the number may no longer describe reality; the Mac refreshes every few minutes.
    static let warningAge: TimeInterval = 60 * 60

    static func isOld(_ date: Date, now: Date) -> Bool {
        now.timeIntervalSince(date) > self.warningAge
    }

    /// "just now", "6 min ago", "2 hr ago".
    static func text(since date: Date, now: Date) -> String {
        let interval = max(0, now.timeIntervalSince(date))
        guard interval >= 60 else { return String(localized: "just now") }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .short
        formatter.allowedUnits = interval < 3600 ? [.minute] : interval < 86400 ? [.hour] : [.day]
        formatter.maximumUnitCount = 1
        return String(format: String(localized: "%@ ago"), formatter.string(from: interval) ?? "")
    }
}

extension CodexBarWidgetEntry {
    /// The same data at later dates, so countdowns and "6 min ago" keep moving
    /// between timeline reloads instead of freezing for up to 15 minutes.
    func ticking(until reload: TimeInterval, every step: TimeInterval = 5 * 60) -> [CodexBarWidgetEntry] {
        stride(from: 0, to: reload, by: step).map { offset in
            CodexBarWidgetEntry(
                date: self.date.addingTimeInterval(offset),
                configuration: self.configuration,
                snapshot: self.snapshot,
                paceWindowChoice: self.paceWindowChoice,
                overviewSelection: self.overviewSelection,
                accountChoice: self.accountChoice)
        }
    }
}

enum WidgetRiskColor {
    /// Reads as a warning next to any provider color, including Claude's orange.
    static func color(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 1.0, green: 0.43, blue: 0.40) : Color(red: 0.80, green: 0.12, blue: 0.14)
    }

    static func safe(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.34, green: 0.84, blue: 0.56) : Color(red: 0.05, green: 0.56, blue: 0.30)
    }
}
