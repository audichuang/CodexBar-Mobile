import CodexBarSync
import Foundation
import Testing
@testable import CodexBarMobile

struct V082DailyAllowanceTargetTests {
    @Test func `Calendar month metadata works without a duration and still requires a future reset`() {
        let reset = self.now.addingTimeInterval(86400 * 4)
        let calendarMonth = SyncRateWindow(
            usedPercent: 25, windowMinutes: nil, period: .monthly, resetsAt: reset, resetDescription: nil)
        #expect(DailyAllowanceTarget(window: calendarMonth, now: self.now) != nil)
        let noReset = SyncRateWindow(
            usedPercent: 25, windowMinutes: nil, period: .monthly, resetsAt: nil, resetDescription: nil)
        #expect(DailyAllowanceTarget(window: noReset, now: self.now) == nil)
    }

    @Test(arguments: ["en", "zh-Hans", "zh-Hant", "ja"])
    func `Known allowance units translate while custom units remain verbatim`(language: String) throws {
        let locale = Locale(identifier: language)
        for (unit, key) in [
            ("credits", "Credits"),
            ("Credits", "Credits"),
            ("requests", "Requests"),
            ("tokens", "tokens"),
            ("points", "points"),
        ] {
            let window = SyncRateWindow(
                usedPercent: 20, windowMinutes: 43200, resetsAt: self.now.addingTimeInterval(86400),
                resetDescription: nil, quotaLimit: 1000, quotaUnit: unit)
            let target = try #require(DailyAllowanceTarget(window: window, now: self.now))
            let translated = MobileLocalizedString.value(key, defaultValue: unit, locale: locale)
            #expect(target.text(locale: locale).contains(translated))
            if language != "en", key != "tokens" { #expect(translated.lowercased() != unit.lowercased()) }
        }
        let custom = SyncRateWindow(
            usedPercent: 20, windowMinutes: 43200, resetsAt: self.now.addingTimeInterval(86400),
            resetDescription: nil, quotaLimit: 1000, quotaUnit: "Workspace events")
        let target = try #require(DailyAllowanceTarget(window: custom, now: self.now))
        #expect(target.text(locale: locale).contains("Workspace events"))
    }

    private let now = Date(timeIntervalSince1970: 1_793_174_400) // Fixed synthetic observation.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func `Monthly allowance uses calendar days including today and excludes a midnight reset day`() throws {
        let start = self.calendar.startOfDay(for: self.now)
        let reset = try #require(self.calendar.date(byAdding: .day, value: 4, to: start))
        let window = SyncRateWindow(
            usedPercent: 20, windowMinutes: 43200, resetsAt: reset, resetDescription: nil,
            quotaLimit: 1000, quotaUnit: "credits")
        let target = try #require(DailyAllowanceTarget(window: window, now: self.now, calendar: self.calendar))
        #expect(target.amount == 200)
        #expect(target.unit == "credits")
    }

    @Test func `Unknown usage expired resets and nonmonthly windows never invent a target`() {
        for window in [
            SyncRateWindow(
                usedPercent: 0,
                usageKnown: false,
                windowMinutes: 43200,
                resetsAt: self.now.addingTimeInterval(86400),
                resetDescription: nil),
            SyncRateWindow(usedPercent: 0, windowMinutes: 43200, resetsAt: self.now, resetDescription: nil),
            SyncRateWindow(
                usedPercent: 0,
                windowMinutes: 10080,
                resetsAt: self.now.addingTimeInterval(86400),
                resetDescription: nil),
        ] {
            #expect(DailyAllowanceTarget(window: window, now: self.now, calendar: self.calendar) == nil)
        }
    }

    @Test func `Old monthly payload falls back to percentage and a depleted allowance has a zero target`() throws {
        let window = SyncRateWindow(
            usedPercent: 100, windowMinutes: 43200,
            resetsAt: self.now.addingTimeInterval(86400), resetDescription: nil)
        let target = try #require(DailyAllowanceTarget(window: window, now: self.now, calendar: self.calendar))
        #expect(target.amount == 0)
        #expect(target.unit == "%")
    }
}
