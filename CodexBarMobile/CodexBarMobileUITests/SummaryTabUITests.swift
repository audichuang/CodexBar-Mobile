import UIKit
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

    @MainActor func testSummaryDefaultGridUsesFullWidthAcrossDuoOrientations() async {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = self.launch()
        let orientations: [(UIDeviceOrientation, String)] = [(.portrait, "portrait"), (.landscapeLeft, "landscape")]
        var previousFrame: CGRect?
        for (orientation, name) in orientations {
            XCUIDevice.shared.orientation = orientation
            let didRotate = await self.waitForSummaryGeometry(
                app, landscape: orientation.isLandscape, previousFrame: previousFrame)
            guard didRotate else {
                XCTFail(
                    "Requested \(name) but the app never reached that aspect ratio with changed geometry. "
                        +
                        "Observed app frame: \(app.frame). Rotation is unverified; no \(name) screenshot was captured.")
                return
            }
            let grid = app.scrollViews["summary-grid"]
            XCTAssertTrue(grid.waitForExistence(timeout: 8))
            XCTAssertEqual(app.buttons["summary-edit"].label, "Edit", "Summary must open outside editing mode")
            XCTAssertEqual(self.summaryDetails(app).count, 0, "Opening or rotating Summary must not select an account")

            // Measure the app's current content container rather than the device model or
            // orientation name: Duo can expose different window widths at the same orientation.
            let width = grid.frame.width
            XCTAssertGreaterThan(width, 0)
            XCTAssertGreaterThanOrEqual(
                width, app.frame.width * 0.82,
                "Summary's grid must occupy the available window, not a split-view sidebar")
            let columns = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "summary-grid-columns-")).firstMatch
            XCTAssertTrue(columns.waitForExistence(timeout: 5))
            // The native Duo rail contributes a safe area inside the full-window scroll view.
            // LazyVGrid's frame is the actual card area; its parent adds 16pt padding per side.
            let contentWidth = columns.frame.width
            let expectedColumns = max(2, min(4, Int((contentWidth + 32) / 175)))
            XCTAssertEqual(
                columns.identifier, "summary-grid-columns-\(expectedColumns)",
                "Columns must follow the actual safe-area content width")

            let visibleCards = self.cards(app).allElementsBoundByIndex.filter(\.isHittable)
            XCTAssertGreaterThanOrEqual(visibleCards.count, expectedColumns)
            if let firstY = visibleCards.map(\.frame.minY).min() {
                let firstRow = visibleCards.filter { abs($0.frame.minY - firstY) < 4 }
                XCTAssertEqual(firstRow.count, expectedColumns)
                if let left = firstRow.map(\.frame.minX).min(),
                   let right = firstRow.map(\.frame.maxX).max()
                {
                    XCTAssertEqual(
                        right - left, contentWidth, accuracy: 4,
                        "The first card row must span its full card container, excluding the native rail safe area")
                }
            }
            // Capture the whole screen, including the system-owned Duo tab/navigation chrome.
            self.capture("Summary Duo \(name) full-width grid with native chrome")
            previousFrame = app.frame
        }
    }

    @MainActor private func waitForSummaryGeometry(
        _ app: XCUIApplication,
        landscape: Bool,
        previousFrame: CGRect?) async -> Bool
    {
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            let frame = app.frame
            if frame.width > 0, frame.height > 0 {
                let hasExpectedAspect = landscape ? frame.width > frame.height : frame.height > frame.width
                let changedAspect = previousFrame.map { previous in
                    abs(frame.width / frame.height - previous.width / previous.height) > 0.1
                } ?? true
                if hasExpectedAspect, changedAspect { return true }
            }
            // Await actual viewport geometry, not merely XCUIDevice's requested orientation.
            // Async waiting keeps the main actor available for XCTest's accessibility updates.
            do { try await Task.sleep(for: .milliseconds(100)) }
            catch { return false }
        }
        return false
    }

    @MainActor func testSummaryCardPushAndBackPreserveProviderFilter() {
        XCUIDevice.shared.orientation = .portrait
        let app = self.launch()
        XCTAssertEqual(self.summaryDetails(app).count, 0)
        XCTAssertEqual(app.buttons["summary-edit"].label, "Edit")
        let codex = app.buttons["summary-filter-codex"]
        XCTAssertTrue(codex.waitForExistence(timeout: 5))
        codex.tap()
        XCTAssertGreaterThan(self.cards(app).count, 0)
        XCTAssertTrue(self.cards(app).allElementsBoundByIndex.allSatisfy { $0.identifier.contains("-codex-") })
        XCTAssertEqual(self.summaryDetails(app).count, 0, "Filtering alone must leave Summary on the grid")

        let first = self.cards(app).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        let detail = app.descendants(matching: .any)
            .matching(identifier: "summary-selected-detail-codex").firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 8), "An explicit card tap must push that account's details")
        XCTAssertFalse(app.buttons["summary-save"].exists, "A normal tap must not open the customization sheet")
        self.capture("Summary Duo account details after explicit card tap")

        let back = self.summaryBackButton(app)
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.scrollViews["summary-grid"].waitForExistence(timeout: 8))
        XCTAssertEqual(self.summaryDetails(app).count, 0)
        XCTAssertTrue(app.buttons["summary-filter-codex"].isSelected)
        XCTAssertGreaterThan(self.cards(app).count, 0)
        XCTAssertTrue(self.cards(app).allElementsBoundByIndex.allSatisfy { $0.identifier.contains("-codex-") })
        XCTAssertEqual(app.buttons["summary-edit"].label, "Edit")
        self.capture("Summary Duo returned to grid with Codex filter retained")
    }

    @MainActor private func summaryDetails(_ app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "summary-selected-detail-"))
    }

    @MainActor private func summaryBackButton(_ app: XCUIApplication) -> XCUIElement {
        // Duo's actual accessibility tree identifies the native rail control as BackButton,
        // outside NavigationBar. The rail may be hosted by the app or by SpringBoard.
        let railBack = app.buttons["BackButton"]
        if railBack.exists { return railBack }
        let navigationBack = app.navigationBars.buttons["Summary"]
        if navigationBack.exists { return navigationBack }
        return XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["BackButton"]
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
