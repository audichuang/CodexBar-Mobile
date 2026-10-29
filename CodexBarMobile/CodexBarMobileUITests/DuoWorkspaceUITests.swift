import XCTest

final class DuoWorkspaceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

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
        let app = self.launch(preserveCurrentPose: true)
        app.nativeTab("Cost").tap()
        let share = app.buttons["cost-share-button"]
        XCTAssertTrue(share.waitForExistence(timeout: 15))
        if ProcessInfo.processInfo.environment["DUO_WAIT_FOR_NATIVE_LANDSCAPE"] == "1" {
            let window = app.windows.containing(NSPredicate(format: "identifier == %@", "cost-share-button")).firstMatch
            print("WAIT NATIVE LANDSCAPE - Cost window \(window.frame)")
            XCTAssertEqual(XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(
                    predicate: NSPredicate { _, _ in window.frame.width > window.frame.height }, object: nil)],
                timeout: 180), .completed)
        }
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
        let app = self.launch(preserveCurrentPose: true)
        app.nativeTab("Cost").tap()
        let activeWindow = app.windows.containing(NSPredicate(format: "identifier == %@", "cost-share-button"))
            .firstMatch
        try XCTSkipUnless(activeWindow.frame.width >= 760, "Requires an actually wide active window")
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

    /// Select an open inner display first, then use native Device Hub controls
    /// when each named capture appears. The test verifies actual window changes.
    @MainActor
    func testAccountAndShareDraftSurviveNativeFoldAndUnfold() {
        let app = self.launch(preserveCurrentPose: true)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Codex")
        let account = app.buttons["provider-group-codex"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        account.tap()
        XCTAssertTrue(app.navigationBars["Codex"].waitForExistence(timeout: 5))
        app.nativeTab("Cost").tap()
        let share = app.buttons["cost-share-button"]
        XCTAssertTrue(share.waitForExistence(timeout: 15))
        share.tap()
        let heatmap = app.buttons["share-style-heatmap"]
        self.reveal(heatmap, in: app)
        heatmap.tap()
        let range = app.buttons["share-range-picker"]
        self.reveal(range, in: app)
        let draftRange = range.label
        let close = app.buttons["share-card-close"]
        let shareWindow = app.windows.containing(NSPredicate(format: "identifier == %@", "share-card-close")).firstMatch
        XCTAssertGreaterThan(shareWindow.frame.width, 600)
        self.capture("WAIT NATIVE FOLD - heatmap draft prepared on inner display")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let size = shareWindow.frame.size
                return size.width > 0 && size.height > 0 && min(size.width, size.height) < 550
            }, object: shareWindow)], timeout: 180), .completed)
        XCTAssertTrue(heatmap.isSelected, "Native folding must retain the selected template")
        self.reveal(range, in: app)
        XCTAssertEqual(range.label, draftRange)
        XCTAssertTrue(app.buttons["share-provider-picker"].exists)
        self.capture("Native folded outer display retains reachable heatmap draft")
        close.tap()
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["ActivityListView"].exists)
        app.nativeTab("Usage").tap()
        XCTAssertTrue(app.navigationBars["Codex"].waitForExistence(timeout: 5))
        let detailWindow = app.windows.containing(NSPredicate(format: "identifier == %@", "Codex")).firstMatch
        self.capture("WAIT NATIVE UNFOLD - selected Codex account after cancelling draft")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let size = detailWindow.frame.size
                return min(size.width, size.height) > 600
            }, object: detailWindow)], timeout: 180), .completed)
        XCTAssertTrue(app.navigationBars["Codex"].exists)
        app.nativeTab("Cost").tap()
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        XCTAssertTrue(app.buttons["share-style-classic"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["share-style-classic"].isSelected,
            "Cancel must not export or reuse the cancelled draft")
        self.capture("Native unfolded display permits a fresh share draft")
        app.buttons["share-card-close"].tap()
    }

    @MainActor
    private func launch(preserveCurrentPose: Bool = false) -> XCUIApplication {
        if !preserveCurrentPose { XCUIDevice.shared.orientation = .portrait }
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
            let predicate = NSPredicate(format: "identifier == %@", element.identifier)
            let window = app.windows.containing(predicate).firstMatch.frame
            let ancestors = app.scrollViews.containing(predicate).allElementsBoundByIndex
            let visible = ancestors.compactMap { scroll -> (XCUIElement, CGRect)? in
                let viewport = scroll.frame.intersection(window)
                guard !viewport.isNull, viewport.width >= 100, viewport.height >= 150 else { return nil }
                return (scroll, viewport)
            }
            guard let (scroll, viewport) = visible.min(by: { $0.1.width * $0.1.height < $1.1.width * $1.1.height })
            else {
                XCTFail("No visible scrolling viewport for \(element.identifier)")
                return
            }
            // App-wide coordinates route to the inactive outer display on Duo.
            // Anchor the drag to a real inner-screen ancestor and clip to its window.
            let origin = scroll.coordinate(withNormalizedOffset: .zero)
            let x = viewport.midX - scroll.frame.minX
            let top = viewport.minY - scroll.frame.minY
            origin.withOffset(CGVector(dx: x, dy: top + viewport.height * 0.8))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(
                    dx: x, dy: top + viewport.height * 0.25)))
        }
        if !element.isHittable {
            let attachment = XCTAttachment(string: app.debugDescription)
            attachment.name = "Unreachable control hierarchy"
            attachment.lifetime = .keepAlways
            add(attachment)
            self.capture("Unreachable control on active displays")
        }
        XCTAssertTrue(element.exists)
    }

    @MainActor
    private func capture(_ name: String) {
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let attachment = XCTAttachment(screenshot: screen.screenshot())
            attachment.name = "\(name) - screen \(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}

/// Native tab bars can live at the top, bottom or vertical edge. Match the
/// control rather than assuming a UITabBar hierarchy or a screen coordinate.
extension XCUIApplication {
    @MainActor
    func nativeTab(_ name: String) -> XCUIElement {
        let bottomButton = self.tabBars.buttons[name]
        if bottomButton.exists { return bottomButton }
        let symbol = [
            "Usage": "chart.bar.fill",
            "Summary": "square.grid.2x2.fill",
            "Cost": "dollarsign.circle.fill",
            "Setting": "gearshape",
        ][name] ?? name
        let predicate = NSPredicate(format: "identifier == %@ OR label == %@", symbol, name)
        let local = self.descendants(matching: .any).matching(predicate).firstMatch
        if local.exists { return local }
        return XCUIApplication(bundleIdentifier: "com.apple.springboard")
            .descendants(matching: .any).matching(predicate).firstMatch
    }
}
