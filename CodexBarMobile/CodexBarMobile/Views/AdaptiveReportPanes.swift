import SwiftUI

/// Keeps both pane subtrees alive as the window changes. In a narrow window
/// the outer scroll view owns scrolling; in a split each pane owns its viewport.
/// A custom Layout keeps all controls reachable even when a native arrangement
/// would display only its primary view on the outer display.
struct AdaptiveReportPanes<Primary: View, Secondary: View>: View {
    var allowsVerticalSplit = false
    /// A split viewport lets visual previews fit without changing subtree identity.
    @ViewBuilder let primary: (CGSize?) -> Primary
    @ViewBuilder let secondary: () -> Secondary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var primaryHeight: CGFloat = 1
    @State private var secondaryHeight: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let plan = ReportPanePlan.make(
                size: geometry.size,
                largeText: self.dynamicTypeSize.isAccessibilitySize,
                division: self.activeDivision(in: geometry),
                allowsVerticalSplit: self.allowsVerticalSplit)
            ScrollView(.vertical) {
                ReportPaneLayout(plan: plan) {
                    ScrollView(.vertical) {
                        self.primary(plan.isSplit ? plan.first.size : nil)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .environment(\.isScrollEnabled, true)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                                self.primaryHeight = max(1, $0)
                            }
                    }
                    .environment(\.isScrollEnabled, plan.isSplit)
                    .frame(height: plan.isSplit ? plan.first.height : self.primaryHeight)
                    .accessibilityIdentifier("workspace-primary")
                    ScrollView(.vertical) {
                        self.secondary()
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .environment(\.isScrollEnabled, true)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                                self.secondaryHeight = max(1, $0)
                            }
                    }
                    .environment(\.isScrollEnabled, plan.isSplit)
                    .frame(height: plan.isSplit ? plan.second.height : self.secondaryHeight)
                    .accessibilityIdentifier("workspace-secondary")
                }
            }
            .scrollDisabled(plan.isSplit)
        }
    }

    private func activeDivision(in geometry: GeometryProxy) -> CGRect? {
        if #available(iOS 27.1, *) {
            // Layout uses physical x/y coordinates, so don't mirror the region
            // a second time when the content is right-to-left.
            guard let region = geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed)
                .first(where: { $0.isActive }) else { return nil }
            return CGRect(
                x: region.frame.minX - region.margins.leading,
                y: region.frame.minY - region.margins.top,
                width: region.frame.width + region.margins.leading + region.margins.trailing,
                height: region.frame.height + region.margins.top + region.margins.bottom)
        }
        return nil
    }
}

private struct ReportPaneLayout: Layout {
    let plan: ReportPanePlan

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        if self.plan.isSplit {
            return CGSize(width: self.plan.second.maxX, height: max(self.plan.first.maxY, self.plan.second.maxY))
        }
        let width = proposal.width ?? self.plan.first.width
        let height = subviews.reduce(CGFloat.zero) {
            $0 + $1.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        return CGSize(width: width, height: height + 18)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for (index, view) in subviews.enumerated() {
            if self.plan.isSplit {
                let frame = index == 0 ? self.plan.first : self.plan.second
                view.place(
                    at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(frame.size))
            } else {
                let size = view.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                view.place(
                    at: CGPoint(x: bounds.minX, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: bounds.width, height: size.height))
                y += size.height + 18
            }
        }
    }
}
