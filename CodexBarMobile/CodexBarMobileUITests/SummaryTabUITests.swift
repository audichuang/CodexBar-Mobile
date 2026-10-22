import XCTest

final class SummaryTabUITests: XCTestCase {
    override func setUpWithError() throws { self.continueAfterFailure = false }

    @MainActor private func launch(language: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "UI_TEST_PREVIEW_DATA", "UI_TEST_MULTI_ACCOUNT_DATA", "UI_TEST_SKIP_ONBOARDING", "UI_TEST_RESET_DEFAULTS",
            "-cwlEnabled", "NO", "-AppleLanguages", "(\(language))", "-AppleLocale",
            language == "ja" ? "ja_JP" : "en_US",
        ]
        app.launch()
        let names = ["en": "Summary", "zh-Hans": "摘要", "zh-Hant": "摘要", "ja": "概要"]
        let tab = app.nativeTab(names[language] ?? "Summary")
        XCTAssertTrue(tab.waitForExistence(timeout: 8))
        tab.tap()
        XCTAssertTrue(app.scrollViews["summary-grid"].waitForExistence(timeout: 8))
        return app
    }

    @MainActor private func cards(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "summary-card-"))
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }

    @MainActor func testProviderFilterAndEditingCountdownNameAndColor() {
        let app = self.launch()
        self.capture("Summary initial")
        let codex = app.buttons["summary-filter-codex"]
        XCTAssertTrue(codex.waitForExistence(timeout: 5))
        codex.tap()
        XCTAssertGreaterThan(self.cards(app).count, 0)
        XCTAssertTrue(self.cards(app).allElementsBoundByIndex.allSatisfy { $0.identifier.contains("-codex-") })
        app.buttons["summary-filter-all"].tap()
        app.buttons["summary-edit"].tap()
        let first = self.cards(app).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertTrue(app.buttons["summary-save"].waitForExistence(timeout: 5))
        let countdown = app.buttons["Time to reset"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        countdown.tap()
        let name = app.textFields["summary-card-name"]
        name.tap()
        name.typeText("My key limit")
        app.buttons["summary-color-purple"].tap()
        self.capture("Summary edited countdown preview")
        app.buttons["summary-save"].tap()
        XCTAssertTrue(self.cards(app).matching(NSPredicate(format: "label CONTAINS %@", "My key limit")).firstMatch
            .waitForExistence(timeout: 5))
        self.capture("Summary custom card")
    }

    @MainActor func testCancelledCreationDoesNotAddAndCreatingAddsOneCard() {
        let app = self.launch()
        let initial = self.cards(app).count
        app.buttons["summary-add"].tap()
        XCTAssertTrue(app.buttons["summary-add-next"].waitForExistence(timeout: 5))
        app.buttons["summary-add-next"].tap()
        XCTAssertTrue(app.buttons["summary-save"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.scrollViews["summary-grid"].waitForExistence(timeout: 5))
        XCTAssertEqual(self.cards(app).count, initial)
        app.buttons["summary-add"].tap()
        app.buttons["summary-add-next"].tap()
        app.buttons["summary-save"].tap()
        XCTAssertTrue(app.scrollViews["summary-grid"].waitForExistence(timeout: 5))
        XCTAssertEqual(self.cards(app).count, initial + 1)
        self.capture("Summary created metric")
    }

    @MainActor func testSummaryAcrossFourLanguages() {
        for language in ["en", "zh-Hans", "zh-Hant", "ja"] {
            let app = self.launch(language: language)
            XCTAssertGreaterThan(self.cards(app).count, 0)
            self.capture("Summary \(language)")
            app.terminate()
        }
    }
}
