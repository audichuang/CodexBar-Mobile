import SwiftUI
import XCTest
@testable import CodexBarMobile

final class ReportPanePlanTests: XCTestCase {
    func testPortraitInteriorUsesTwoPanesWithoutAnOrientationCheck() {
        let plan = ReportPanePlan.make(
            size: CGSize(width: 800, height: 1000),
            largeText: false,
            division: nil,
            allowsVerticalSplit: false)
        XCTAssertTrue(plan.isSplit)
        XCTAssertLessThan(plan.first.maxX, plan.second.minX)
        XCTAssertEqual(plan.second.maxX, 800)
    }

    func testTabletopPreviewAndControlsAvoidTheActualOffCenterFold() {
        let fold = CGRect(x: 0, y: 340, width: 900, height: 36)
        let plan = ReportPanePlan.make(
            size: CGSize(width: 900, height: 800),
            largeText: false,
            division: fold,
            allowsVerticalSplit: true)
        XCTAssertTrue(plan.isSplit)
        XCTAssertEqual(plan.first.maxY, fold.minY)
        XCTAssertEqual(plan.second.minY, fold.maxY)
        XCTAssertEqual(plan.second.maxY, 800)
    }

    func testBookFoldKeepsBothPanelsOutOfTheReservedRegion() {
        let fold = CGRect(x: 360, y: 0, width: 44, height: 700)
        let plan = ReportPanePlan.make(
            size: CGSize(width: 900, height: 700),
            largeText: false,
            division: fold,
            allowsVerticalSplit: false)
        XCTAssertTrue(plan.isSplit)
        XCTAssertEqual(plan.first.width, 360)
        XCTAssertEqual(plan.second.minX, 404)
        XCTAssertFalse(plan.first.intersects(fold))
        XCTAssertFalse(plan.second.intersects(fold))
    }

    func testNarrowLargeTextAndShortFoldRegionsKeepBothSectionsInOneScroll() {
        for (size, largeText, fold) in [
            (CGSize(width: 466, height: 800), false, CGRect?.none),
            (CGSize(width: 900, height: 800), true, nil),
            (CGSize(width: 900, height: 800), false, CGRect(x: 0, y: 150, width: 900, height: 30)),
        ] {
            XCTAssertFalse(ReportPanePlan.make(
                size: size,
                largeText: largeText,
                division: fold,
                allowsVerticalSplit: true).isSplit)
        }
    }

    func testCostDoesNotBecomeTwoShortReportsAcrossATabletopFold() {
        XCTAssertFalse(ReportPanePlan.make(
            size: CGSize(width: 900, height: 800), largeText: false,
            division: CGRect(x: 0, y: 390, width: 900, height: 20), allowsVerticalSplit: false).isSplit)
    }
}
