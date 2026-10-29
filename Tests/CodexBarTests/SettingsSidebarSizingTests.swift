import AppKit
import SwiftUI
import Testing
@testable import CodexBar

@MainActor
struct SettingsSidebarSizingTests {
    @Test
    func `native sidebar saves divider changes and restores them in a new view`() async throws {
        let width = SidebarWidth(value: 320)
        let firstWindow = self.makeWindow(width: width)
        try await self.settle(firstWindow)
        let firstContent = try #require(firstWindow.contentView)
        let firstSplit = try #require(self.splitView(in: firstContent))
        let sidebar = try self.sidebar(in: firstSplit)
        #expect(sidebar.viewController.view.frame.width == 320)
        #expect(width.value == 320)

        // The native pane can include system chrome outside the content measured by the modifier.
        // Move its divider to a 300-point content width without assuming that chrome's size.
        let dividerPosition = firstSplit.subviews[0].frame.maxX + (300 - sidebar.viewController.view.frame.width)
        firstSplit.setPosition(dividerPosition, ofDividerAt: 0)
        try await self.settle(firstWindow)
        #expect(sidebar.viewController.view.frame.width == 300)
        #expect(width.value == 300)

        let secondWindow = self.makeWindow(width: width)
        try await self.settle(secondWindow)
        let secondContent = try #require(secondWindow.contentView)
        let secondSplit = try #require(self.splitView(in: secondContent))
        let restoredSidebar = try self.sidebar(in: secondSplit)
        #expect(restoredSidebar.viewController.view.frame.width == 300)
        #expect(width.value == 300)

        #expect(sidebar.canCollapse)
        sidebar.isCollapsed = true
        try await self.settle(firstWindow)
        #expect(sidebar.isCollapsed)
        #expect(width.value == 300)
        sidebar.isCollapsed = false
        try await self.settle(firstWindow)
        #expect(sidebar.viewController.view.frame.width == 300)
        #expect(width.value == 300)
    }

    @Test
    func `native sidebar keeps the existing saved minimum width`() async throws {
        let width = SidebarWidth(value: 200)
        let window = self.makeWindow(width: width)
        try await self.settle(window)
        let content = try #require(window.contentView)
        let split = try #require(self.splitView(in: content))
        let sidebar = try self.sidebar(in: split)
        #expect(sidebar.viewController.view.frame.width == 200)
        #expect(width.value == 200)
        #expect(sidebar.canCollapse)
        #expect(sidebar.minimumThickness == SettingsPane.sidebarMinWidth)
        #expect(sidebar.maximumThickness == SettingsPane.sidebarMaxWidth)
    }

    private func makeWindow(width: SidebarWidth) -> NSWindow {
        _ = NSApplication.shared
        // Wide enough that the detail column's minimum width never limits how far the sidebar can grow.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: SettingsPane.windowHeight),
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.contentViewController = NSHostingController(rootView: SidebarHarness(width: width))
        return window
    }

    private func splitView(in view: NSView) -> NSSplitView? {
        if let split = view as? NSSplitView { return split }
        return view.subviews.lazy.compactMap { self.splitView(in: $0) }.first
    }

    private func sidebar(in split: NSSplitView) throws -> NSSplitViewItem {
        let controller = try #require(split.delegate as? NSSplitViewController)
        return try #require(controller.splitViewItems.first)
    }

    private func settle(_ window: NSWindow) async throws {
        // Allow the hosting view's deferred layout and geometry callbacks to finish without showing a window.
        for _ in 0..<5 {
            window.contentView?.layoutSubtreeIfNeeded()
            if let contentView = window.contentView {
                self.splitView(in: contentView)?.layoutSubtreeIfNeeded()
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
@Observable
private final class SidebarWidth {
    var value: Double

    init(value: Double) {
        self.value = value
    }
}

@MainActor
private struct SidebarHarness: View {
    @Bindable var width: SidebarWidth

    var body: some View {
        NavigationSplitView {
            Color.clear
                .modifier(SettingsSidebarSizing(width: self.$width.value))
        } detail: {
            Color.clear
        }
    }
}
