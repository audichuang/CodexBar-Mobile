import UIKit
import XCTest

final class SummaryTabUITests: XCTestCase {
    override func setUpWithError() throws { self.continueAfterFailure = false }

    @MainActor private func launch(
        language: String = "en", hidePersonalInfo: Bool = false) -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "UI_TEST_PREVIEW_DATA", "UI_TEST_MULTI_ACCOUNT_DATA", "UI_TEST_SKIP_ONBOARDING", "UI_TEST_RESET_DEFAULTS",
            "-cwlEnabled", "NO", "-AppleLanguages", "(\(language))", "-AppleLocale",
            language == "ja" ? "ja_JP" : "en_US",
        ]
        if hidePersonalInfo { app.launchArguments += ["-hidePersonalInfo", "YES"] }
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
        // Duo keeps the inactive outer display as main; preserve every screen so the
        // active inner display is not replaced by a black outer-screen attachment.
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let attachment = XCTAttachment(screenshot: screen.screenshot())
            attachment.name = "\(name) screen \(index)"
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
    }

    /// Select the real inner-display pose in Device Hub before running either case.
    /// XCUIDevice.orientation alone does not reliably rotate Duo's inner display.
    @MainActor func testSummaryExpandedPortraitViewport() {
        self.assertSummaryExpandedViewport(landscape: false)
    }

    @MainActor func testSummaryExpandedLandscapeViewport() {
        self.assertSummaryExpandedViewport(landscape: true)
    }

    @MainActor private func assertSummaryExpandedViewport(landscape: Bool) {
        let app = self.launch()
        let grid = app.scrollViews["summary-grid"]
        XCTAssertTrue(grid.waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["summary-edit"].label, "Edit", "Summary must open outside editing mode")
        XCTAssertEqual(self.summaryDetails(app).count, 0, "Opening or rotating Summary must not select an account")

        // The root app frame may stay in fixed display coordinates on Duo; validate
        // the actual card viewport rather than the requested device orientation.
        XCTAssertEqual(
            grid.frame.width > grid.frame.height, landscape,
            "The actual viewport must match the pose selected in Device Hub")
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
        self.capture("Summary Duo \(landscape ? "landscape" : "portrait") full-width grid with native chrome")
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

    @MainActor func testPrivacyModeKeepsNamesEditableAsPlainText() {
        let app = self.launch(hidePersonalInfo: true)
        app.buttons["summary-edit"].tap()
        self.cards(app).firstMatch.tap()
        let name = app.textFields["summary-card-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertFalse(app.secureTextFields["summary-card-name"].exists)
        name.tap()
        let displayName = "C 5x fictional@example.invalid"
        name.typeText(displayName)
        XCTAssertEqual(name.value as? String, displayName)
        let aliasDisclosure = app.buttons["summary-account-alias-disclosure"]
        XCTAssertTrue(aliasDisclosure.waitForExistence(timeout: 5))
        aliasDisclosure.tap()
        let alias = app.textFields["summary-account-alias"]
        XCTAssertTrue(alias.waitForExistence(timeout: 5))
        XCTAssertFalse(app.secureTextFields["summary-account-alias"].exists)
        alias.tap()
        alias.typeText("Work")
        XCTAssertEqual(alias.value as? String, "Work")
        self.capture("Summary plain-text names with privacy enabled")
        app.buttons["summary-save"].tap()
        let saved = self.cards(app).matching(NSPredicate(format: "label CONTAINS %@", "C 5x")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertFalse(saved.label.contains("fictional@example.invalid"))
        saved.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, displayName)
        app.buttons["Cancel"].tap()
    }

    /// Select the simulator's actual system appearance before running this case.
    /// AppleInterfaceStyle launch defaults do not reliably change Duo's trait environment.
    @MainActor func testTabSurfacesInCurrentSystemAppearance() {
        let app = self.launch()
        self.capture("Summary unified surface")
        for tabName in ["Usage", "Cost", "Setting"] {
            let tab = app.nativeTab(tabName)
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.tap()
            if tabName == "Cost" {
                XCTAssertTrue(app.staticTexts["Overview"].firstMatch.waitForExistence(timeout: 8))
            } else if tabName == "Setting" {
                XCTAssertTrue(app.staticTexts["Setup Guide"].firstMatch.waitForExistence(timeout: 5))
            }
            self.capture("\(tabName) surface reference")
        }
        app.terminate()
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
