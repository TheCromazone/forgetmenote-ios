import SwiftUI

struct V3AuthShell<Content: View>: View {
    let palette: V3Palette
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [palette.paper, palette.accentBg],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // corner flower decorations
            FlowerMark(size: 90, color: palette.accent, pollen: palette.pollen)
                .opacity(0.18)
                .offset(x: -32, y: -16)
            FlowerMark(size: 64, color: palette.accent, pollen: palette.pollen)
                .opacity(0.14)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: 24, y: -8)

            FlowerMark(size: 80, color: palette.accent, pollen: palette.pollen)
                .opacity(0.16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 24, y: 24)

            content()
                .padding(.horizontal, 28)
                .padding(.top, 60)
                .padding(.bottom, 32)
        }
    }
}
