import CodexBarSync
import Foundation
import Testing
@testable import CodexBarMobile

struct V082KimiReaderTests {
    @Test func `Gift names remain verbatim even when they match a translated semantic label`() {
        let locale = Locale(identifier: "ja")
        #expect(ProviderDetailLocalization.localized(
            "Plan", providerID: "kimi", context: .rowLabel(sectionTitle: "Bonus credits"), locale: locale) == "Plan")
        #expect(ProviderDetailLocalization.localized(
            "Bonus credits", providerID: "kimi", context: .rowLabel(sectionTitle: "Bonus credits"),
            locale: locale) != "Bonus credits")
    }

    @Test(arguments: ["en", "zh-Hans", "zh-Hant", "ja"])
    func `Kimi ratios use the reader language and cached gifts expire without another Mac refresh`(
        language: String) throws
    {
        let now = Date(timeIntervalSince1970: 1_793_174_400)
        let expiry = now.addingTimeInterval(60)
        let locale = Locale(identifier: language)
        let gift = SyncProviderDetailSection.Row(
            label: "Synthetic promotion", value: "Mac-language balance", secondaryValue: "Mac-local date",
            progress: .init(used: 0.25, total: 1), expiresAt: expiry)
        let data = try CloudSyncConstants.makeJSONEncoder().encode(gift)
        let cached = try CloudSyncConstants.makeJSONDecoder().decode(SyncProviderDetailSection.Row.self, from: data)
        let before = ProviderDetailRowPresentation(
            providerID: "kimi", row: cached, sectionTitle: "Bonus credits", now: now, locale: locale)
        #expect(!before.isExpired)
        #expect(!before.value.contains("Mac-language"))
        #expect(before.secondaryValue?.contains("Mac-local") == false)
        #expect(before.progressFraction == 0.25)
        let after = ProviderDetailRowPresentation(
            providerID: "kimi", row: cached, sectionTitle: "Bonus credits", now: expiry, locale: locale)
        #expect(after.isExpired)
        #expect(after.progressFraction == nil)
        #expect(after.value == MobileLocalizedString.value("Expired", defaultValue: "Expired", locale: locale))
        let monthly = SyncProviderDetailSection.Row(
            id: "kimi-monthly-other", label: "Other features", value: "Mac-language usage",
            progress: .init(used: 0.2, total: 1))
        let presentation = ProviderDetailRowPresentation(
            providerID: "kimi", row: monthly, sectionTitle: "Total usage", now: now, locale: locale)
        #expect(!presentation.value.contains("Mac-language"))
        #expect(presentation.value.contains(0.2.formatted(.percent.precision(.fractionLength(0...1)).locale(locale))))
        if language != "en" { #expect(!presentation.value.contains("used")) }
    }

    @Test func `Old gift dates and custom provider rows stay verbatim without guessed expiry`() {
        let row = SyncProviderDetailSection.Row(label: "Bonus", value: "75% left", secondaryValue: "Mac date")
        let old = ProviderDetailRowPresentation(providerID: "kimi", row: row, sectionTitle: "Bonus credits")
        #expect(old.value == row.value)
        #expect(old.secondaryValue == row.secondaryValue)
        #expect(!old.isExpired)
        let custom = ProviderDetailRowPresentation(providerID: "custom-meter", row: row, sectionTitle: "Bonus credits")
        #expect(custom.value == row.value)
    }
}
