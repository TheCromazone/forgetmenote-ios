import SwiftUI

/// Replaces SwiftUI's auto-generated NavigationStack back button with one that
/// exposes a stable accessibility identifier ("Back") for Maestro UI tests.
///
/// The default auto-back-button on iOS has no consistently-discoverable
/// identifier — its accessibility label is generated from the previous screen's
/// title which makes test selectors fragile.
struct CustomBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Back")
                    .accessibilityIdentifier("Back")
                }
            }
    }
}

extension View {
    func customBackButton() -> some View {
        modifier(CustomBackButtonModifier())
    }
}
