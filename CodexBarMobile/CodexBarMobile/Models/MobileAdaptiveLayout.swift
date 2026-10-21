import SwiftUI

/// Content-driven breakpoints; these are not device dimensions or hinge geometry.
struct MobileAdaptiveLayout: Equatable {
    var width: CGFloat = 0
    var height: CGFloat = 0
    var largeText = false
    var usesListDetail: Bool {
        self.width >= 760 && self.height >= 500 && !self.largeText
    }

    var usesTwoColumns: Bool {
        self.width >= 760 && self.height >= 500 && !self.largeText
    }

    var providerColumns: Int {
        1
    }
}

extension EnvironmentValues {
    @Entry var mobileAdaptiveLayout: MobileAdaptiveLayout = .init()
}
