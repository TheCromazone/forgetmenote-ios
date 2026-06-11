import SwiftUI

struct V3Switch: View {
    let palette: V3Palette
    let isOn: Bool
    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? palette.accent : palette.line)
                .frame(width: 50, height: 30)
            Circle()
                .fill(.white)
                .frame(width: 24, height: 24)
                .padding(.horizontal, 3)
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
        }
        .animation(.easeInOut(duration: 0.18), value: isOn)
        .accessibilityValue(isOn ? "on" : "off")
    }
}
