import SwiftUI

/// New surfaces match the existing Usage and Cost canvas and material cards.
/// Apply explicitly so unrelated lists and native sheets retain their own styling.
enum MobileSurfaceStyle {
    static var pageBackground: Color {
        Color(.systemBackground)
    }

    static var cardMaterial: Material {
        .ultraThinMaterial
    }

    /// List supplies the grouped row mask and separators; this view only supplies the fill.
    static var rowBackground: some View {
        Rectangle().fill(self.cardMaterial)
    }
}

private struct MobilePageSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(MobileSurfaceStyle.pageBackground)
    }
}

extension View {
    /// For an explicitly styled List or Form, without process-wide UIKit appearance changes.
    func mobilePageSurface() -> some View {
        self.modifier(MobilePageSurfaceModifier())
    }
}
