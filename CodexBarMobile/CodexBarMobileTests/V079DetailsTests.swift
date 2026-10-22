import CodexBarSync
import Foundation
import SwiftUI
import Testing
import UIKit
import XCTest
@testable import CodexBarMobile

@Suite("v0.79 translated provider details")
struct V079DetailsTests {
    @Test(arguments: ["en", "zh-Hans", "zh-Hant", "ja"])
    func `Gemini app time windows translate while CLI model names stay verbatim`(language: String) {
        let expected = [
            "en": ["5-hour", "Weekly"], "zh-Hans": ["5 小时", "每周"],
            "zh-Hant": ["5 小時", "每週"], "ja": ["5時間", "週次"],
        ]
        let locale = Locale(identifier: language)
        for (index, label) in ["5-hour", "Weekly"].enumerated() {
            #expect(ProviderWindowLabel.localized(label, fallback: "", providerID: "gemini", locale: locale)
                == expected[language]?[index])
        }
        for model in ["Pro", "Flash", "Flash Lite"] {
            #expect(ProviderWindowLabel.localized(model, fallback: "", providerID: "gemini", locale: locale) == model)
        }
    }

    @Test(arguments: ["en", "zh-Hans", "zh-Hant", "ja"])
    func `Vercel personal budget labels localize without translating custom plugin text`(language: String) {
        let expected = [
            "en": ["Personal budget", "No personal budget configured"],
            "zh-Hans": ["个人预算", "未配置个人预算"],
            "zh-Hant": ["個人預算", "未設定個人預算"],
            "ja": ["個人予算", "個人予算が設定されていません"],
        ]
        let locale = Locale(identifier: language)
        #expect(ProviderWindowLabel.localized("Personal budget", fallback: "", providerID: "vercel", locale: locale)
            == expected[language]?[0])
        for (index, label) in ["Personal budget", "No personal budget configured"].enumerated() {
            #expect(ProviderDetailLocalization.localized(label, providerID: "vercel", locale: locale)
                == expected[language]?[index])
            #expect(ProviderDetailLocalization.localized(
                label, providerID: "vercel", context: .rowLabel(sectionTitle: "Personal budget"), locale: locale)
                == expected[language]?[index])
            #expect(ProviderDetailLocalization.localized(label, providerID: "plugin:fixture", locale: locale) == label)
        }
    }

    @Test func `first party labels and severity are localized while user defined meter names stay verbatim`() throws {
        let warning = ["en": "Warning", "zh-Hans": "警告", "zh-Hant": "警告", "ja": "警告"]
        let critical = ["en": "Critical", "zh-Hans": "严重警告", "zh-Hant": "嚴重警告", "ja": "重大な警告"]
        let limits = ["en": "Spend limits", "zh-Hans": "支出上限", "zh-Hant": "支出上限", "ja": "支出上限"]
        let active = ["en": "Active", "zh-Hans": "正常", "zh-Hant": "正常", "ja": "有効"]
        for language in ["en", "zh-Hans", "zh-Hant", "ja"] {
            let locale = Locale(identifier: language)
            for key in ["AI credits", "Gateway requests"] {
                #expect(ProviderWindowLabel.localized(key, fallback: "", locale: locale)
                    == MobileLocalizedString.value(key, defaultValue: "", locale: locale))
            }
            #expect(ProviderDetailLocalization.localized("Spend limits", providerID: "munito", locale: locale)
                == limits[language])
            #expect(ProviderDetailLocalization.localizedValue(
                "Active",
                providerID: "munito",
                rowLabel: "Status",
                sectionTitle: "Organization",
                locale: locale) ==
                active[language])
            #expect(ProviderDetailLocalization.localized(
                "Balance",
                providerID: "futureagi",
                context: .rowLabel(sectionTitle: "Used / free allowance"),
                locale: locale) == "Balance")
            #expect(ProviderDetailLocalization
                .localized("Spend limits", providerID: "plugin:fixture", locale: locale) == "Spend limits")
            #expect(ProviderDetailSeverityIndicator.label(for: .warning, locale: locale) == warning[language])
            #expect(ProviderDetailSeverityIndicator.label(for: .critical, locale: locale) == critical[language])
            #expect(ProviderDetailSeverityIndicator.label(for: .normal, locale: locale) == nil)
            #expect(ProviderDetailSeverityIndicator.label(for: nil, locale: locale) == nil)
            let value = ProviderDetailLocalization.localizedValue(
                "View account-specific local costs on your Mac.",
                providerID: "claude",
                rowLabel: "Account-specific history",
                sectionTitle: "Local cost history",
                locale: locale)
            if language != "en" { #expect(value != "View account-specific local costs on your Mac.") }
            for iso in ["2026-10-22T12:30:00.000Z", "2026-10-22T12:30:00Z"] {
                let stop = ProviderDetailLocalization.localizedValue(
                    iso,
                    providerID: "munito",
                    rowLabel: "Today stopped until",
                    sectionTitle: "Spend limits",
                    locale: locale)
                #expect(!stop.contains("T12:30:00"))
            }
        }
        let data = Data(#"{"label":"Queue","value":"Busy","severity":"future-unknown"}"#.utf8)
        #expect(try JSONDecoder().decode(SyncProviderDetailSection.Row.self, from: data).severity == nil)
        for (id, hex) in [("futureagi", "7857FC"), ("munito", "702CF6")] {
            let actual = UIColor(ProviderColorPalette.color(for: id))
                .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            let number = try #require(UInt32(hex, radix: 16))
            let expected = UIColor(
                red: CGFloat((number >> 16) & 255) / 255,
                green: CGFloat((number >> 8) & 255) / 255,
                blue: CGFloat(number & 255) / 255,
                alpha: 1)
            var a: CGFloat = 0, b: CGFloat = 0, c: CGFloat = 0, d: CGFloat = 0
            var x: CGFloat = 0, y: CGFloat = 0, z: CGFloat = 0, w: CGFloat = 0
            actual.getRed(&a, green: &b, blue: &c, alpha: &d)
            expected.getRed(&x, green: &y, blue: &z, alpha: &w)
            #expect(abs(a - x) < 0.01 && abs(b - y) < 0.01 && abs(c - z) < 0.01)
        }
    }
}

@MainActor
final class V079DetailsRenderTests: XCTestCase {
    func testVercelPersonalBudgetFullAndTeaserInFourLanguages() throws {
        let section = SyncProviderDetailSection(title: "Personal budget", rows: [
            .init(label: "No personal budget configured", value: "—"),
        ])
        for language in ["en", "zh-Hans", "zh-Hant", "ja"] {
            let content = VStack(spacing: 16) {
                ProviderDetailsView(providerID: "vercel", sections: [section], tintColor: .primary)
                ProviderDetailsTeaserView(providerID: "vercel", section: section)
            }
            .padding(16).frame(width: 390).background(Color.white)
            .environment(\.locale, Locale(identifier: language)).environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            let attachment = XCTAttachment(image: image)
            attachment.name = "v079-vercel-personal-budget-\(language)"
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
    }

    func testDetailsAndTeaserInFourLanguagesAppearancesAndLargeText() throws {
        let section = SyncProviderDetailSection(title: "Spend limits", rows: [
            .init(label: "Today", value: "$2.00 of $10.00", severity: .warning),
            .init(label: "Today stopped until", value: "2026-10-22T12:30:00.000Z", severity: .critical),
            .init(label: "Usage tier", value: "Business"),
        ])
        for language in ["en", "zh-Hans", "zh-Hant", "ja"] {
            for dark in [false, true] {
                let content = VStack(spacing: 16) {
                    ProviderDetailsView(providerID: "munito", sections: [section], tintColor: .purple)
                    ProviderDetailsTeaserView(providerID: "munito", section: section)
                }
                .padding(16)
                .frame(width: 390)
                .background(dark ? Color.black : Color.white)
                .environment(\.locale, Locale(identifier: language))
                .environment(\.colorScheme, dark ? .dark : .light)
                let renderer = ImageRenderer(content: content)
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertGreaterThan(image.size.height, 200)
                let attachment = XCTAttachment(image: image)
                attachment.name = "v079-details-\(language)-\(dark ? "dark" : "light")"
                attachment.lifetime = .keepAlways
                self.add(attachment)
            }
        }
        let renderer = ImageRenderer(content: ProviderDetailsView(
            providerID: "munito",
            sections: [section],
            tintColor: .purple)
            .padding(16).frame(width: 390).background(Color.white)
            .environment(\.locale, Locale(identifier: "ja"))
            .environment(\.colorScheme, .light).environment(\.dynamicTypeSize, .accessibility3))
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "v079-details-ja-accessibility3"
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }
}
