import XCTest

final class DuoWorkspaceUITests: XCTestCase {
    @MainActor
    func testAccountAndShareDraftSurviveRotationAndCancel() {
        let app = self.launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Codex")
        let account = app.buttons["provider-group-codex"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        XCTAssertTrue(account.label.contains("Session"))
        XCTAssertTrue(account.label.contains("Weekly"))
        account.tap()
        XCTAssertTrue(app.navigationBars["Codex"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.navigationBars["Codex"].waitForExistence(timeout: 5))
        self.capture("Selected Codex after rotation")
        app.nativeTab("Cost").tap()
        let share = app.buttons["cost-share-button"]
        XCTAssertTrue(share.waitForExistence(timeout: 15))
        share.tap()
        let heatmap = app.buttons["share-style-heatmap"]
        self.reveal(heatmap, in: app)
        heatmap.tap()
        XCTAssertTrue(app.buttons["share-range-picker"].waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .portrait
        let range = app.buttons["share-range-picker"]
        self.reveal(range, in: app)
        XCTAssertTrue(range.isHittable)
        XCTAssertTrue(app.buttons["share-provider-picker"].exists)
        self.capture("Share heatmap draft retained after rotation")
        app.buttons["share-card-close"].tap()
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["ActivityListView"].exists)
        app.nativeTab("Usage").tap()
        XCTAssertTrue(app.navigationBars["Codex"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCostAndSharePanesAreAccessibleAtTheCurrentSize() {
        let app = self.launch()
        app.nativeTab("Cost").tap()
        let share = app.buttons["cost-share-button"]
        XCTAssertTrue(share.waitForExistence(timeout: 15))
        let trend = app.staticTexts["cost-dashboard-daily-spend-title"]
        self.reveal(trend, in: app)
        XCTAssertTrue(trend.isHittable, "The second report must remain reachable in a narrow window")
        self.capture("Cost report production layout")
        share.tap()
        let period = app.buttons["share-period-picker"]
        self.reveal(period, in: app)
        XCTAssertTrue(period.isHittable)
        let action = app.buttons["share-card-action"]
        self.reveal(action, in: app)
        XCTAssertTrue(action.isHittable)
        self.capture("Share editor with reachable controls")
        app.buttons["share-card-close"].tap()
        XCTAssertTrue(share.waitForExistence(timeout: 5))
    }

    @MainActor
    func testWidePanesScrollIndependently() throws {
        let app = self.launch()
        try XCTSkipUnless(app.frame.width >= 760, "Requires a wide container")
        app.nativeTab("Cost").tap()
        let trend = app.staticTexts["cost-dashboard-daily-spend-title"]
        XCTAssertTrue(trend.waitForExistence(timeout: 15))
        let overview = app.staticTexts["Overview"]
        let initialOverviewY = overview.frame.minY
        let initialTrendY = trend.frame.minY
        let primary = app.scrollViews["workspace-primary"]
        let secondary = app.scrollViews["workspace-secondary"]
        XCTAssertTrue(primary.exists && secondary.exists)
        primary.swipeUp()
        XCTAssertLessThan(overview.frame.minY, initialOverviewY - 20)
        XCTAssertEqual(trend.frame.minY, initialTrendY, accuracy: 4)
        let scrolledOverviewY = overview.frame.minY
        secondary.swipeUp()
        XCTAssertEqual(overview.frame.minY, scrolledOverviewY, accuracy: 4)
        XCTAssertLessThan(trend.frame.minY, initialTrendY - 20)
        self.capture("Cost panes independently scrolled")
    }

    @MainActor
    private func launch() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "UI_TEST_PREVIEW_DATA", "UI_TEST_SKIP_ONBOARDING", "UI_TEST_RESET_DEFAULTS",
            "-cwlEnabled", "NO", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<16 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// Native tab bars can live at the top, bottom or vertical edge. Match the
/// control rather than assuming a UITabBar hierarchy or a screen coordinate.
extension XCUIApplication {
    @MainActor
    func nativeTab(_ name: String) -> XCUIElement {
        let bottomButton = self.tabBars.buttons[name]
        if bottomButton.exists { return bottomButton }
        let symbol = ["Usage": "chart.bar.fill", "Summary": "square.grid.2x2.fill", "Cost": "dollarsign.circle.fill", "Setting": "gearshape"][name] ?? name
        let predicate = NSPredicate(format: "identifier == %@ OR label == %@", symbol, name)
        let local = self.descendants(matching: .any).matching(predicate).firstMatch
        if local.exists { return local }
        return XCUIApplication(bundleIdentifier: "com.apple.springboard")
            .descendants(matching: .any).matching(predicate).firstMatch
    }
}
