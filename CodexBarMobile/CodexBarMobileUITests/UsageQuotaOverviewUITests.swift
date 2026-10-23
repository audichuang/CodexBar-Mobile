import UIKit
import XCTest

/// Run the current-pose case again after selecting each real Duo display/pose and system appearance.
/// Hosting-size render tests complement these captures; they do not establish actual Duo geometry.
final class UsageQuotaOverviewUITests: XCTestCase {
    override func setUpWithError() throws { self.continueAfterFailure = false }

    @MainActor private func launch(hidden: Bool = false, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "UI_TEST_PREVIEW_DATA", "UI_TEST_MULTI_ACCOUNT_DATA", "UI_TEST_SKIP_ONBOARDING", "UI_TEST_RESET_DEFAULTS",
            "-cwlEnabled", "NO", "-openCostByDefault", "NO",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-hidePersonalInfo", hidden ? "YES" : "NO",
        ]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        let usage = app.nativeTab("Usage")
        XCTAssertTrue(usage.waitForExistence(timeout: 10))
        usage.tap()
        XCTAssertTrue(app.buttons["usage-quota-edit"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func capture(_ name: String) {
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let attachment = XCTAttachment(screenshot: screen.screenshot())
            attachment.name = "\(name) - screen \(index)"
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        var visible = false
        if app.buttons["quota-editor-done"].exists {
            for _ in 0..<10 where !(element.exists && element.isHittable) {
                self.scrollEditorForm(app, upward: true)
            }
            visible = element.exists && element.isHittable
        } else {
            visible = self.revealUsageElement(element, in: app)
        }
        if !visible {
            self.attachHierarchy(app, name: "Element still obscured after bounded scrolling")
            self.capture("Element still obscured after bounded scrolling")
        }
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        XCTAssertTrue(element.isHittable)
        XCTAssertTrue(visible, "The requested content must be reachable inside the unobscured scroll viewport")
    }

    @MainActor private func revealUsageElement(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let scroller = self.usageScroller(app)
        let window = app.windows.containing(.scrollView, identifier: "usage-provider-list").firstMatch
        XCTAssertTrue(window.exists)
        let quotaElement = element.exists && element.identifier.hasPrefix("usage-quota-")
        var lastFrame = element.exists ? element.frame : CGRect.null
        for _ in 0..<12 {
            let bounds = window.frame.intersection(scroller.frame)
            var visible = bounds
            let chrome = app.navigationBars.allElementsBoundByIndex + app.tabBars.allElementsBoundByIndex
                + app.searchFields.allElementsBoundByIndex.filter(\.isHittable)
            let tabBounds = ["Usage", "Summary", "Cost", "Setting"].map { app.nativeTab($0) }
                .filter(\.exists).reduce(CGRect.null) { $0.union($1.frame) }
            let obstructions = chrome.filter(\.exists).map(\.frame) + [tabBounds]
            for frame in obstructions where !frame.isNull && frame.intersects(visible) {
                if frame.width > frame.height {
                    if frame.midY < bounds.midY {
                        let bottom = visible.maxY
                        visible.origin.y = max(visible.minY, frame.maxY)
                        visible.size.height = max(0, bottom - visible.minY)
                    } else {
                        visible.size.height = max(0, min(visible.maxY, frame.minY) - visible.minY)
                    }
                } else if frame.midX < bounds.midX {
                    let right = visible.maxX
                    visible.origin.x = max(visible.minX, frame.maxX)
                    visible.size.width = max(0, right - visible.minX)
                } else {
                    visible.size.width = max(0, min(visible.maxX, frame.minX) - visible.minX)
                }
            }
            visible = visible.insetBy(dx: 8, dy: 8)
            XCTAssertGreaterThan(visible.width, 100)
            XCTAssertGreaterThan(visible.height, 80)
            if element.exists {
                lastFrame = element.frame
                // Quota rows must clear the bars in full; a restored provider card
                // only needs to be reachable, since it may be taller than this viewport.
                let verticallyVisible = (!quotaElement && lastFrame.intersects(visible)) ||
                    (quotaElement && (lastFrame.height <= visible.height
                            ? lastFrame.minY >= visible.minY && lastFrame.maxY <= visible.maxY
                            : visible.contains(CGPoint(x: lastFrame.midX, y: lastFrame.midY))))
                if verticallyVisible, element.isHittable { return true }
            } else if quotaElement {
                lastFrame = .null
            }
            // A short, slow drag with a held end avoids flinging past the row.
            // If the quota card was lazily unloaded, it is above the provider list.
            let upward = lastFrame.isNull ? !quotaElement : lastFrame.midY > visible.midY
            let distance = min(72, visible.height * 0.28)
            let startY = visible.midY + (upward ? distance / 2 : -distance / 2)
            let endY = startY + (upward ? -distance : distance)
            let origin = scroller.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(
                dx: visible.midX - scroller.frame.minX,
                dy: startY - scroller.frame.minY))
            let end = origin.withOffset(CGVector(
                dx: visible.midX - scroller.frame.minX,
                dy: endY - scroller.frame.minY))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        return false
    }

    @MainActor private func top(_ app: XCUIApplication) {
        if app.buttons["quota-editor-done"].exists {
            let count = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-5] / 5")).firstMatch
            for _ in 0..<10 where !(count.exists && count.isHittable) {
                XCTAssertTrue(
                    app.buttons["quota-editor-done"].exists,
                    "Scrolling the Form must keep the native editor sheet open")
                self.scrollEditorForm(app, upward: false)
            }
            XCTAssertTrue(count.exists && count.isHittable)
        } else {
            self.reveal(app.buttons["usage-quota-edit"], in: app)
        }
    }

    @MainActor private func scrollEditorForm(_ app: XCUIApplication, upward: Bool) {
        let rowControl = NSPredicate(
            format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
            "quota-line-actions-",
            "quota-catalog-",
            "quota-candidate-")
        let form = app.collectionViews.containing(rowControl).firstMatch
        let visible = form.frame.intersection(app.windows.firstMatch.frame)
        let reachableRow = form.buttons.matching(rowControl).allElementsBoundByIndex.contains {
            $0.isHittable && $0.frame.intersects(visible)
        }
        if !form.exists || visible.isNull || visible.width <= 100 || visible.height <= 100 || !reachableRow {
            self.attachHierarchy(app, name: "Quota editor scroll lacks visible Form or hittable row")
            self.capture("Quota editor scroll before geometry and row assertions")
            let attachment =
                XCTAttachment(
                    string: "Selected Form:\n\(form.debugDescription)\nCollection views:\n"
                        + app.collectionViews.debugDescription)
            attachment.name = "Quota editor selected Form and candidate geometry"
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
        XCTAssertTrue(form.exists, "Scroll the native Form containing quota row controls")
        XCTAssertFalse(visible.isNull)
        XCTAssertGreaterThan(visible.width, 100)
        XCTAssertGreaterThan(visible.height, 100)
        XCTAssertTrue(reachableRow, "A real row control inside the visible editor must remain hittable")
        // Duo's visible Form reports isHittable=false while its row buttons are hittable.
        // Drag inside the observed Form/window intersection, below the sheet's navigation bar,
        // rather than asking XCTest for a hit point on the non-interactive container itself.
        let origin = form.coordinate(withNormalizedOffset: .zero)
        let x = visible.midX - form.frame.minX
        let upperY = visible.minY + visible.height * 0.30 - form.frame.minY
        let lowerY = visible.minY + visible.height * 0.78 - form.frame.minY
        let upper = origin.withOffset(CGVector(dx: x, dy: upperY))
        let lower = origin.withOffset(CGVector(dx: x, dy: lowerY))
        (upward ? lower : upper).press(forDuration: 0.05, thenDragTo: upward ? upper : lower)
    }

    @MainActor private func usageScroller(_ app: XCUIApplication) -> XCUIElement {
        // The chart is lazy and can leave the accessibility tree while scrolling.
        // Identify the persistent provider-list pane rather than an offscreen child.
        let scroller = app.scrollViews["usage-provider-list"]
        XCTAssertTrue(scroller.exists && scroller.isHittable, "The quota card's vertical list must be reachable")
        XCTAssertGreaterThan(scroller.frame.width, 100)
        XCTAssertGreaterThan(scroller.frame.height, 100)
        return scroller
    }

    @MainActor private func actions(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "quota-line-actions-"))
    }

    @MainActor private func legendRows(_ app: XCUIApplication) -> [XCUIElement] {
        let matches = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier != %@",
            "usage-quota-legend-",
            "usage-quota-legend-toggle"))
        var seen = Set<String>()
        return matches.allElementsBoundByIndex.filter { seen.insert($0.identifier).inserted }
    }

    @MainActor private func assertQuotaClearsNativeChrome(_ app: XCUIApplication) {
        let chart = app.descendants(matching: .any)["usage-quota-chart"].firstMatch
        let legend = app.buttons["usage-quota-legend-toggle"]
        let window = app.windows.containing(.any, identifier: "usage-quota-chart").firstMatch
        let scroller = app.scrollViews.containing(.button, identifier: "usage-quota-edit").firstMatch
        XCTAssertTrue(chart.exists && legend.exists && window.exists && scroller.exists)
        // A hittable element may still be partly hidden. Check every edge of both
        // production elements against their actual window, viewport and native bars.
        let viewport = window.frame.intersection(scroller.frame)
        let tabs = ["Usage", "Summary", "Cost", "Setting"].map { app.nativeTab($0) }
        let chrome = app.navigationBars.allElementsBoundByIndex + app.tabBars.allElementsBoundByIndex
            + app.searchFields.allElementsBoundByIndex.filter(\.isHittable) + tabs
        var problems: [String] = []
        if viewport.isNull || viewport.width <= 0 || viewport.height <= 0 {
            problems.append("Quota viewport is empty: \(viewport)")
        }
        for tab in tabs where !tab.exists || !tab.isHittable {
            problems.append("Native tab must remain reachable: \(tab)")
        }
        for element in [chart, legend] {
            let frame = element.frame
            if !viewport.insetBy(dx: -1, dy: -1).contains(frame) {
                problems.append("\(element.identifier) \(frame) escapes visible viewport \(viewport)")
            }
            for obstruction in chrome where obstruction.exists && !obstruction.frame.isEmpty {
                if frame.insetBy(dx: 1, dy: 1).intersects(obstruction.frame.insetBy(dx: 1, dy: 1)) {
                    problems.append("\(element.identifier) overlaps \(obstruction.elementType) "
                        + "\(obstruction.label) at \(obstruction.frame)")
                }
            }
        }
        if !legend.isHittable { problems.append("The collapsed legend must be directly tappable") }
        if !problems.isEmpty {
            self.attachHierarchy(app, name: "Quota native chrome overlap")
            self.capture("Quota visibility failure with complete native app")
        }
        XCTAssertTrue(problems.isEmpty, problems.joined(separator: "\n"))
    }

    @MainActor private func waitForOrientation(_ app: XCUIApplication, landscape: Bool) {
        let predicate = NSPredicate { _, _ in
            landscape ? app.frame.width > app.frame.height : app.frame.height > app.frame.width
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: app)], timeout: 8),
            .completed)
    }

    @MainActor private func openProviderSearch(_ app: XCUIApplication) -> XCUIElement {
        let field = app.searchFields.firstMatch
        if !field.exists || !field.isHittable {
            let search = app.buttons.matching(NSPredicate(
                format: "label == %@ OR label == %@ OR identifier == %@",
                "Search",
                "Search providers",
                "magnifyingglass")).firstMatch
            if !search.waitForExistence(timeout: 5) {
                self.attachHierarchy(app, name: "Missing native minimized search control")
            }
            XCTAssertTrue(search.exists && search.isHittable)
            search.tap()
        }
        XCTAssertTrue(field.waitForExistence(timeout: 5) && field.isHittable)
        field.tap()
        self.dismissKeyboardIntroductionIfVisible(app)
        return field
    }

    @MainActor private func dismissKeyboardIntroductionIfVisible(_ app: XCUIApplication) {
        // Fresh Simulators can show the system's one-time Slide to Type tutorial.
        // Dismiss only that observed onboarding view, never an arbitrary Continue action.
        let introduction = app.otherElements["UIContinuousPathIntroductionView"]
        guard introduction.waitForExistence(timeout: 2) else { return }
        let explanation = introduction.staticTexts[
            "Speed up your typing by sliding your finger across the letters to compose a word.",
        ]
        let continueButton = introduction.buttons["Continue"]
        guard explanation.exists, explanation.frame.intersects(app.frame), continueButton.isHittable else { return }
        continueButton.tap()
        XCTAssertTrue(introduction.waitForNonExistence(timeout: 5), "System keyboard onboarding must close")
    }

    @MainActor func testPhoneQuotaChartAndLegendClearBarsThroughLandscapeSearchAndRotation() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = self.launch()
        self.waitForOrientation(app, landscape: false)
        XCTAssertLessThan(app.frame.width, 600, "Run this regression on an ordinary compact iPhone")
        self.assertQuotaClearsNativeChrome(app)
        self.capture("Phone quota portrait first viewport with complete native app")
        let toggle = app.buttons["usage-quota-legend-toggle"]
        let selectedLines = toggle.value as? String

        XCUIDevice.shared.orientation = .landscapeLeft
        self.waitForOrientation(app, landscape: true)
        // No scrolling before this assertion: revealing a clipped chart would hide the regression.
        self.assertQuotaClearsNativeChrome(app)
        self.capture("Phone quota landscape first viewport with complete native app")
        let search = self.openProviderSearch(app)
        search.typeText("Codex")
        XCTAssertEqual(search.value as? String, "Codex")
        XCTAssertTrue(app.buttons["provider-group-codex"].exists)
        XCTAssertFalse(app.buttons["provider-group-claude"].exists, "Search must filter the provider list")
        let clear = search.buttons["Clear text"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5) && clear.isHittable)
        clear.tap()
        let clearedValue = search.value as? String
        let queryCleared = clearedValue?.isEmpty == true || clearedValue == search.placeholderValue
        if !queryCleared {
            self.attachHierarchy(app, name: "Native search clear-text state")
            self.capture("Native search clear-text state")
        }
        XCTAssertTrue(queryCleared, "Clear text must leave an empty query or its native placeholder")
        // The unfiltered LazyVGrid need not instantiate the offscreen Claude row.
        // Search for it explicitly to verify the query can change providers.
        search.typeText("Claude")
        XCTAssertTrue(app.buttons["provider-group-claude"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["provider-group-codex"].exists)
        clear.tap()
        search.typeText("Codex")
        XCTAssertEqual(search.value as? String, "Codex")
        XCTAssertFalse(app.buttons["provider-group-claude"].exists)
        self.attachHierarchy(app, name: "Active native landscape search")
        self.capture("Phone quota active native landscape search")
        let cancel = app.navigationBars.buttons.matching(NSPredicate(
            format: "label IN %@", ["Cancel", "Cancel Search", "Close", "close"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5) && cancel.isHittable)
        cancel.tap()
        // iOS 26 keeps a Close button on its idle toolbar search field; iOS 27
        // collapses it. Verify the completed interaction, not that OS-specific shell.
        let keyboardDismissed = app.keyboards.firstMatch.waitForNonExistence(timeout: 5)
        let editOrder = app.buttons["usage-edit-order"]
        let searchEnded = NSPredicate { _, _ in
            let field = app.searchFields.firstMatch
            let value = field.exists ? field.value as? String : nil
            let emptyQuery = !field.exists || value?.isEmpty == true || value == field.placeholderValue
            guard emptyQuery, editOrder.exists else { return false }
            let frame = editOrder.frame
            return frame.width > 0 && frame.height > 0 && app.windows.firstMatch.frame.intersects(frame)
        }
        let searchDismissed = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: searchEnded, object: app)], timeout: 5) == .completed
        if !searchDismissed || !keyboardDismissed {
            self.attachHierarchy(app, name: "Native search dismissal state")
            self.capture("Native search dismissal state")
        }
        XCTAssertTrue(searchDismissed, "Closing search must clear the query and restore normal navigation")
        XCTAssertTrue(keyboardDismissed, "Closing native search must dismiss the keyboard")
        self.assertQuotaClearsNativeChrome(app)
        XCTAssertEqual(toggle.value as? String, selectedLines, "Search must not change selected quota lines")
        // The first unfiltered provider proves clearing restored the list without
        // scrolling past multiple full provider cards; Claude was verified by search above.
        self.reveal(app.buttons["provider-group-antigravity"], in: app)
        self.top(app)

        toggle.tap()
        let rows = self.legendRows(app)
        XCTAssertEqual(rows.count, 5)
        for row in rows {
            self.reveal(row, in: app)
        }
        self.capture("Phone quota landscape expanded legend last row reachable")
        self.top(app)
        self.reveal(toggle, in: app)
        toggle.tap()
        self.top(app)
        app.nativeTab("Summary").tap()
        app.nativeTab("Usage").tap()
        XCTAssertEqual(toggle.label, "Expand quota legend")
        XCTAssertEqual(toggle.value as? String, selectedLines)

        XCUIDevice.shared.orientation = .portrait
        self.waitForOrientation(app, landscape: false)
        self.top(app)
        self.assertQuotaClearsNativeChrome(app)
        self.capture("Phone quota portrait restored after search legend and rotation")
    }

    @MainActor func testNativeUsageChartInCurrentDisplayPose() {
        let app = self.launch()
        let card = app.descendants(matching: .any)["usage-quota-overview"].firstMatch
        let chart = app.descendants(matching: .any)["usage-quota-chart"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(chart.frame.width, 140)
        XCTAssertGreaterThanOrEqual(chart.frame.height, 139)
        XCTAssertGreaterThanOrEqual(chart.frame.minX, card.frame.minX - 2)
        XCTAssertLessThanOrEqual(chart.frame.maxX, card.frame.maxX + 2)
        XCTAssertTrue(self.legendRows(app).isEmpty, "Detailed legend rows must start collapsed")
        let toggle = app.buttons["usage-quota-legend-toggle"]
        XCTAssertEqual(toggle.label, "Expand quota legend")
        XCTAssertTrue(app.staticTexts["+3"].exists, "Only two default labels and the remaining count should be shown")
        XCTAssertTrue(app.nativeTab("Usage").exists, "Capture must include the real native navigation surface")
        self.assertQuotaClearsNativeChrome(app)
        self.capture("Usage quota collapsed with native tabs in current display pose")

        toggle.tap()
        XCTAssertEqual(toggle.label, "Collapse quota legend")
        let rows = self.legendRows(app)
        XCTAssertEqual(rows.count, 5)
        for row in rows {
            XCTAssertGreaterThan(row.frame.height, 20)
            XCTAssertGreaterThan(row.frame.width, 120)
            XCTAssertGreaterThanOrEqual(row.frame.minX, card.frame.minX - 2)
            XCTAssertLessThanOrEqual(row.frame.maxX, card.frame.maxX + 2)
        }
        self.capture("Usage quota expanded five lines with native tabs")
        toggle.tap()
        XCTAssertEqual(toggle.label, "Expand quota legend")
        for title in ["Summary", "Cost", "Setting"] {
            let tab = app.nativeTab(title)
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Every tab must remain a native reachable control")
            tab.tap()
            if title == "Summary" {
                XCTAssertTrue(app.scrollViews["summary-grid"].waitForExistence(timeout: 8))
            } else if title == "Cost" {
                XCTAssertTrue(app.buttons["cost-group-order-button"].waitForExistence(timeout: 15))
            } else {
                XCTAssertTrue(app.staticTexts["Setup Guide"].firstMatch.waitForExistence(timeout: 5))
            }
            self.capture("Native \(title) complete app in current display pose")
        }
        let usage = app.nativeTab("Usage")
        XCTAssertTrue(usage.exists)
        usage.tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.label, "Expand quota legend", "Tab changes must retain the explicitly collapsed state")
        self.capture("Native Usage restored with compact quota legend")
    }

    @MainActor func testEditorLimitRemoveAddColorAndOrderSurviveReentry() {
        let app = self.launch()
        app.buttons["usage-quota-edit"].tap()
        XCTAssertTrue(app.buttons["quota-editor-done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["5 / 5"].waitForExistence(timeout: 5))
        let add = app.buttons["quota-editor-add"]
        self.reveal(add, in: app)
        XCTAssertFalse(add.isEnabled, "A sixth selection must not be possible")
        self.top(app)
        let color = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "quota-line-color-")).firstMatch
        if !color.exists { self.attachHierarchy(app, name: "Missing production ColorPicker identifier") }
        XCTAssertTrue(color.exists, "Every selected line must expose the production ColorPicker")
        XCTAssertGreaterThan(color.frame.width, 20)

        let removed = self.actions(app).firstMatch
        let removedID = removed.identifier
        removed.tap()
        app.buttons["Remove"].tap()
        XCTAssertFalse(app.buttons[removedID].exists)
        XCTAssertTrue(app.staticTexts["4 / 5"].exists)
        self.reveal(add, in: app)
        XCTAssertTrue(add.isEnabled)
        add.tap()
        XCTAssertTrue(app.navigationBars["Add quota"].waitForExistence(timeout: 5))

        let metrics = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "quota-catalog-"))
        XCTAssertTrue(metrics.firstMatch.waitForExistence(timeout: 5))
        let metricIDs = metrics.allElementsBoundByIndex.map(\.identifier)
        var didAdd = false
        for metricID in metricIDs {
            let metric = app.buttons[metricID]
            self.reveal(metric, in: app)
            metric.tap()
            let available = app.buttons.matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND enabled == true", "quota-candidate-")).firstMatch
            if available.waitForExistence(timeout: 1) {
                available.tap()
                didAdd = true
                break
            }
            self.back(app, title: "Add quota")
        }
        XCTAssertTrue(didAdd, "Removing a selection must make at least one account quota addable again")
        XCTAssertTrue(app.staticTexts["5 / 5"].waitForExistence(timeout: 5))
        self.capture("Quota editor restored to five lines with color controls")

        self.top(app)
        let visible = self.actions(app).allElementsBoundByIndex.filter(\.isHittable)
            .sorted { $0.frame.minY < $1.frame.minY }
        XCTAssertGreaterThanOrEqual(visible.count, 2)
        guard visible.count >= 2 else { return }
        let firstID = visible[0].identifier
        let secondID = visible[1].identifier
        app.buttons[firstID].tap()
        app.buttons["Move down"].tap()
        XCTAssertLessThan(app.buttons[secondID].frame.minY, app.buttons[firstID].frame.minY)
        app.buttons["quota-editor-done"].tap()
        XCTAssertTrue(app.buttons["usage-quota-edit"].waitForExistence(timeout: 5))
        app.buttons["usage-quota-edit"].tap()
        XCTAssertTrue(app.buttons["quota-editor-done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["5 / 5"].exists)
        XCTAssertLessThan(app.buttons[secondID].frame.minY, app.buttons[firstID].frame.minY)
        self.capture("Quota editor order retained after closing and reentering")
        app.buttons["quota-editor-done"].tap()
    }

    @MainActor func testQuotaEditorAndExpandedLegendHideAccountEmails() {
        let app = self.launch(hidden: true)
        app.buttons["usage-quota-legend-toggle"].tap()
        XCTAssertEqual(self.legendRows(app).count, 5)
        XCTAssertTrue(self.legendRows(app).allSatisfy { !$0.label.contains("@") })
        self.top(app)
        app.buttons["usage-quota-edit"].tap()
        XCTAssertTrue(app.buttons["quota-editor-done"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "@")).count, 0)
        self.capture("Quota editor with hidden personal info and distinguishable account ordinals")
        self.actions(app).firstMatch.tap()
        app.buttons["Remove"].tap()
        let add = app.buttons["quota-editor-add"]
        self.reveal(add, in: app)
        add.tap()
        let metric = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "quota-catalog-")).firstMatch
        XCTAssertTrue(metric.waitForExistence(timeout: 5))
        metric.tap()
        let candidates = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "quota-candidate-"))
        XCTAssertTrue(candidates.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(candidates.allElementsBoundByIndex.allSatisfy { !$0.label.contains("@") })
        self.capture("Quota account picker respects hidden personal info")
    }

    @MainActor func testExpandedLegendAtAccessibilitySizeKeepsAllRowsReachable() {
        let app = self.launch(largeText: true)
        let chart = app.descendants(matching: .any)["usage-quota-chart"].firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(
            chart.frame.height,
            200,
            "The real app must have applied an accessibility content size before claiming AX evidence")
        app.buttons["usage-quota-legend-toggle"].tap()
        let rows = self.legendRows(app)
        XCTAssertEqual(rows.count, 5)
        let card = app.descendants(matching: .any)["usage-quota-overview"].firstMatch
        self.capture("Usage quota accessibility legend expanded top")
        for row in rows {
            self.reveal(row, in: app)
            XCTAssertGreaterThan(row.frame.height, 40)
            XCTAssertGreaterThanOrEqual(row.frame.minX, card.frame.minX - 2)
            XCTAssertLessThanOrEqual(
                row.frame.maxX,
                card.frame.maxX + 2,
                "Large text must wrap inside the quota card rather than escape horizontally")
            XCTAssertFalse(row.label.isEmpty)
        }
        self.capture("Usage quota accessibility fifth legend row reached by scrolling")
    }

    @MainActor func testCostWholeGroupOrderMovesNumbersAcrossTheOldPaneBoundary() {
        let app = self.launch()
        app.nativeTab("Cost").tap()
        let edit = app.buttons["cost-group-order-button"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        edit.tap()
        let spend = app.staticTexts["cost-order-dailySpend"]
        let overview = app.staticTexts["cost-order-overview"]
        XCTAssertTrue(spend.waitForExistence(timeout: 5))
        XCTAssertTrue(overview.exists)
        XCTAssertGreaterThan(spend.frame.minY, overview.frame.minY)
        let source = app.cells.containing(.staticText, identifier: "cost-order-dailySpend").firstMatch
        let destination = app.cells.containing(.staticText, identifier: "cost-order-overview").firstMatch
        XCTAssertTrue(source.exists && destination.exists)
        source.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            .press(
                forDuration: 0.7,
                thenDragTo: destination.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.1)))
        XCTAssertLessThan(spend.frame.minY, overview.frame.minY)
        self.capture("Cost whole group native reorder editor")
        app.buttons["cost-order-done"].tap()
        let primary = app.scrollViews["workspace-primary"]
        let spendTitle = primary.staticTexts["cost-dashboard-daily-spend-title"]
        let overviewTitle = primary.staticTexts["Overview"].firstMatch
        if !spendTitle.exists { self.attachHierarchy(app, name: "Cost production group after reorder") }
        XCTAssertTrue(
            spendTitle.waitForExistence(timeout: 5),
            "Daily Spend must move from the secondary to primary sequence")
        XCTAssertTrue(overviewTitle.exists)
        XCTAssertLessThan(spendTitle.frame.minY, overviewTitle.frame.minY)
        XCTAssertGreaterThan(spendTitle.frame.width, 60)
        self.capture("Cost reordered production numbers with native tabs")
        edit.tap()
        XCTAssertTrue(spend.waitForExistence(timeout: 5))
        XCTAssertLessThan(spend.frame.minY, overview.frame.minY)
        app.buttons["cost-order-done"].tap()
    }

    @MainActor private func back(_ app: XCUIApplication, title: String) {
        let rail = app.buttons["BackButton"]
        if rail.exists { rail.tap(); return }
        let navigation = app.navigationBars.buttons[title]
        if navigation.exists { navigation.tap(); return }
        let systemRail = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["BackButton"]
        XCTAssertTrue(systemRail.exists)
        systemRail.tap()
    }

    @MainActor private func attachHierarchy(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }
}
