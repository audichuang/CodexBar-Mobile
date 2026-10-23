import CodexBarSync
import SwiftUI
import Testing
@testable import CodexBarMobile

@Suite("Summary value presentation")
@MainActor
struct SummaryPresentationTests {
    @Test func `credits and noncurrency units are not formatted as money`() {
        let now = Date()
        let credits = SummaryCardAmount(value: 42, currencyCode: "Credits", observedAt: now, isEstimated: false)
        #expect(SummaryPresentation.amount(credits).contains("42"))
        #expect(SummaryPresentation.amount(credits).contains(String(localized: "Credits")))
        #expect(!SummaryPresentation.amount(credits).contains("$"))
        let requests = SummaryCardAmount(value: 17, currencyCode: "requests", observedAt: now, isEstimated: false)
        #expect(SummaryPresentation.amount(requests).contains("17"))
        #expect(SummaryPresentation.amount(requests).contains("requests"))
        #expect(SummaryPresentation.amount(nil) == "—")
    }

    @Test func `extra usage speaks utilization when an amount is absent`() {
        let utilization = SummaryPresentation.extraUsageDescription(amount: nil, usedPercent: 42)
        #expect(utilization.contains("42"))
        #expect(!utilization.contains("—"))
        let amount = SummaryCardAmount(value: 7, currencyCode: "USD", observedAt: Date(), isEstimated: false)
        let both = SummaryPresentation.extraUsageDescription(amount: amount, usedPercent: 42)
        #expect(both.contains("7"))
        #expect(both.contains("42"))
    }

    @Test func `passed resets wait for observations and unknown usage is not zero`() {
        let now = Date()
        #expect(SummaryPresentation.countdown(to: now.addingTimeInterval(-1), now: now)
            == String(localized: "Waiting for update"))
        #expect(SummaryPresentation.percent(nil) == "—")
        #expect(SummaryPresentation.percent(.nan) == "—")
        #expect(SummaryPresentation.percent(0) != "—")
    }

    @Test func `privacy redacts emails in custom titles and stored full identities`() {
        let title = "Fictional Account fictional@example.invalid Plus"
        #expect(!SummaryPresentation.redact(title, enabled: true).contains("fictional@example.invalid"))
        #expect(SummaryPresentation.redact(title, enabled: false) == title)
        #expect(SummaryPresentation.redact("C 5x", enabled: true) == "C 5x")
    }
}
