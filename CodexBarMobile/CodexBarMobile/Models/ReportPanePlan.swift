import SwiftUI

/// Measured in the container's coordinates, never inferred from a device name
/// or hinge angle. The same policy serves resizable iPad windows.
struct ReportPanePlan: Equatable {
    var first: CGRect
    var second: CGRect
    var isSplit: Bool

    static func make(size: CGSize, largeText: Bool, division: CGRect?, allowsVerticalSplit: Bool) -> Self {
        let bounds = CGRect(origin: .zero, size: size)
        let stacked = Self(first: bounds, second: bounds, isSplit: false)
        guard !largeText else { return stacked }
        if let division, bounds.intersects(division) {
            if division.width > division.height, allowsVerticalSplit {
                let top = max(0, division.minY)
                let bottom = max(0, size.height - division.maxY)
                if size.width >= 340, min(top, bottom) >= 220 {
                    return Self(
                        first: CGRect(x: 0, y: 0, width: size.width, height: top),
                        second: CGRect(x: 0, y: division.maxY, width: size.width, height: bottom),
                        isSplit: true)
                }
            } else if division.height > division.width {
                let leading = max(0, division.minX)
                let trailing = max(0, size.width - division.maxX)
                if min(leading, trailing) >= 300, size.height >= 360 {
                    return Self(
                        first: CGRect(x: 0, y: 0, width: leading, height: size.height),
                        second: CGRect(x: division.maxX, y: 0, width: trailing, height: size.height),
                        isSplit: true)
                }
            }
            // An active fold takes precedence over an unrelated width breakpoint.
            return stacked
        }
        guard size.width >= 760, size.height >= 400 else { return stacked }
        let width = (size.width - 20) / 2
        return Self(
            first: CGRect(x: 0, y: 0, width: width, height: size.height),
            second: CGRect(x: width + 20, y: 0, width: width, height: size.height),
            isSplit: true)
    }
}
