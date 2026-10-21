import SwiftUI
import XCTest
@testable import CodexBarMobile

@MainActor
final class MobileAdaptiveLayoutTests: XCTestCase {
    func testPreviewInitializationDoesNotHydrateStoredAccounts() {
        let data = SyncedUsageData(hydrateFromPersistence: false)
        XCTAssertNil(data.snapshot)
        XCTAssertTrue(data.deviceSnapshots.isEmpty)
        XCTAssertTrue(data.providerLinkages.isEmpty)
        XCTAssertTrue(data.deviceLifecycleEvents.isEmpty)
    }

    func testContentBreakpointsKeepPhoneLandscapeCompactAndLargeTypeReadable() {
        XCTAssertFalse(MobileAdaptiveLayout(width: 844, height: 390).usesListDetail)
        XCTAssertTrue(MobileAdaptiveLayout(width: 768, height: 1024).usesListDetail)
        XCTAssertEqual(MobileAdaptiveLayout(width: 768, height: 1024).providerColumns, 1)
        XCTAssertTrue(MobileAdaptiveLayout(width: 1024, height: 768).usesListDetail)
        XCTAssertFalse(MobileAdaptiveLayout(width: 600, height: 768).usesListDetail)
        XCTAssertFalse(MobileAdaptiveLayout(width: 1024, height: 768, largeText: true).usesTwoColumns)
    }

    func testWidePortraitAndLandscapeBothUseAccountNavigation() {
        for size in [CGSize(width: 800, height: 1000), CGSize(width: 1000, height: 800)] {
            let layout = MobileAdaptiveLayout(width: size.width, height: size.height)
            XCTAssertTrue(layout.usesListDetail)
            XCTAssertEqual(layout.providerColumns, 1, "The sidebar must not become a grid inside a split view")
        }
    }

    func testRenderActualPagesAtIllustrativeContainerSizes() async throws {
        let directory = URL(
            fileURLWithPath: ProcessInfo.processInfo.environment["MOBILE_LAYOUT_ARTIFACTS"]
                ?? "/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/LayoutPreviews",
            isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sizes: [(String, CGSize)] = [
            ("outer-portrait", CGSize(width: 390, height: 844)),
            ("outer-landscape", CGSize(width: 844, height: 390)),
            ("inner-portrait", CGSize(width: 768, height: 1024)),
            ("inner-landscape", CGSize(width: 1024, height: 768)),
            ("narrow-split", CGSize(width: 600, height: 768)),
            ("inner-dark", CGSize(width: 1024, height: 768)),
            ("inner-large-text", CGSize(width: 1024, height: 768)),
            ("inner-empty", CGSize(width: 768, height: 1024)),
        ]
        for (pose, size) in sizes {
            for tab in MobileRootTab.allCases {
                let preview = MobileLayoutPreview(
                    tab: tab,
                    size: size,
                    colorScheme: pose == "inner-dark" ? .dark : .light,
                    largeText: pose == "inner-large-text",
                    isEmpty: pose == "inner-empty")
                let controller = UIHostingController(rootView: preview)
                let window = UIWindow(frame: CGRect(origin: .zero, size: size))
                window.rootViewController = controller
                window.isHidden = false
                controller.view.frame = window.bounds
                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()
                try await Task.sleep(for: .seconds(2))
                controller.view.layoutIfNeeded()
                let image = UIGraphicsImageRenderer(size: size).image { _ in
                    controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
                }
                let png = try XCTUnwrap(image.pngData())
                try png.write(to: directory.appendingPathComponent("\(pose)-\(tab.rawValue).png"))
                let attachment = XCTAttachment(image: image)
                attachment.name = "Layout preview only - \(pose) - \(tab.rawValue)"
                attachment.lifetime = .keepAlways
                add(attachment)
                window.isHidden = true
                window.rootViewController = nil
            }
        }
    }
}
