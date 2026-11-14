import SwiftUI

/// Fork: segmented "block" meter with a clock tick, replacing the continuous capsule bar.
///
/// Each cell is a small rounded square; filled cells take the provider tint, the rest use the track
/// color. The pace marker becomes a single tall tick (the share of the window that has elapsed)
/// instead of the green/red diagonal stripe, so "fill ahead of the tick" reads as burning faster than
/// the clock. Everything is drawn in the same Canvas as upstream (no SwiftUI compositing modifiers,
/// see issue #805).
extension UsageProgressBar {
    /// Total view height. Cells are inset vertically so the clock tick can overhang them.
    static let forkBarHeight: CGFloat = 12
    private static let forkCellHeight: CGFloat = 8
    private static let forkCellGap: CGFloat = 2
    private static let forkCellTargetWidth: CGFloat = 7
    private static let forkTickWidth: CGFloat = 2

    struct ForkCellLayout: Equatable {
        let count: Int
        let cellWidth: CGFloat
        let gap: CGFloat

        func minX(of index: Int) -> CGFloat {
            CGFloat(index) * (self.cellWidth + self.gap)
        }
    }

    nonisolated static func forkCellLayout(width: CGFloat) -> ForkCellLayout {
        let gap = Self.forkCellGap
        let count = max(1, Int(((width + gap) / (Self.forkCellTargetWidth + gap)).rounded(.down)))
        let cellWidth = max(1, (width - gap * CGFloat(count - 1)) / CGFloat(count))
        return ForkCellLayout(count: count, cellWidth: cellWidth, gap: gap)
    }

    /// Number of filled cells. Any visible usage lights at least one cell; only a full meter lights all.
    nonisolated static func forkFilledCells(percent: Double, count: Int) -> Int {
        let rendered = Self.renderedFillPercent(percent)
        if rendered <= 0 { return 0 }
        if rendered >= 100 { return count }
        let raw = Int((rendered / 100 * Double(count)).rounded())
        return min(count - 1, max(1, raw))
    }

    /// Constant switch so the upstream Canvas body stays compiled (and reachable for the compiler) behind the hook.
    static let forkUsesSegmentedMeter = true

    func forkDrawSegmented(
        in context: inout GraphicsContext,
        size: CGSize,
        _ highlighted: Bool,
        _ rawScale: CGFloat)
    {
        let scale = max(rawScale, 1)
        let align: (CGFloat) -> CGFloat = { ($0 * scale).rounded() / scale }
        let layout = Self.forkCellLayout(width: size.width)
        let filled = Self.forkFilledCells(percent: self.percent, count: layout.count)
        let cellHeight = min(Self.forkCellHeight, size.height)
        let cellY = align((size.height - cellHeight) / 2)
        let corner = CGSize(width: 1.5, height: 1.5)
        let track = MenuHighlightStyle.progressTrack(highlighted)
        let fill = MenuHighlightStyle.progressTint(highlighted, fallback: self.tint)

        for index in 0..<layout.count {
            let rect = CGRect(
                x: align(layout.minX(of: index)),
                y: cellY,
                width: max(1 / scale, align(layout.cellWidth)),
                height: cellHeight)
            context.fill(Path(roundedRect: rect, cornerSize: corner), with: .color(index < filled ? fill : track))
        }

        let markers = Self.resolvedMarkers(
            warningPercents: self.warningMarkerPercents,
            workdayPercents: self.workdayMarkerPercents,
            workdayAppearance: self.workdayTickAppearance)
        for marker in markers {
            let x = size.width * marker.percent / 100
            let rect: CGRect
            let color: Color
            switch marker.kind {
            case .quotaWarning:
                rect = CGRect(x: align(x - 0.5), y: cellY, width: max(1 / scale, 1), height: cellHeight)
                color = Self.warningMarkerColor(isHighlighted: highlighted)
            case .workdayBoundary:
                rect = Self.workdayMarkerRect(
                    x: x,
                    size: CGSize(width: size.width, height: cellHeight),
                    scale: scale,
                    appearance: self.workdayTickAppearance)
                    .offsetBy(dx: 0, dy: cellY)
                color = Self.workdayMarkerColor(isHighlighted: highlighted, appearance: self.workdayTickAppearance)
            }
            context.fill(Path(rect), with: .color(color))
        }

        if let pacePercent = self.pacePercent {
            let clampedPace = min(100, max(0, pacePercent))
            let tickWidth = Self.forkTickWidth
            let x = min(size.width - tickWidth, max(0, size.width * clampedPace / 100 - tickWidth / 2))
            let tick = CGRect(x: align(x), y: 0, width: tickWidth, height: size.height)
            context.fill(
                Path(roundedRect: tick, cornerSize: CGSize(width: 1, height: 1)),
                with: .color(highlighted ? .white : .primary))
        }
    }
}
