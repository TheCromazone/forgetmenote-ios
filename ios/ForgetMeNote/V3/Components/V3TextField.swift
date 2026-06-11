import SwiftUI

struct V3TextField<Trailing: View>: View {
    let palette: V3Palette
    let label: String
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var autocapitalize: TextInputAutocapitalization = .never
    var error: String? = nil
    var accessibilityID: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.ink3)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(error == nil ? palette.ink3 : palette.danger)
                    Group {
                        if isSecure {
                            SecureField(placeholder, text: $text)
                        } else {
                            TextField(placeholder, text: $text)
                        }
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(palette.ink)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(autocapitalize)
                    .autocorrectionDisabled()
                    .focused($focused)
                    // The accessibility identifier sits on the inner field
                    // (not the labeled HStack) so Maestro's `tapOn id` focuses
                    // the actual TextField/SecureField rather than the label.
                    .accessibilityIdentifier(accessibilityID ?? "v3-textfield-\(label.lowercased())")
                }
                trailing()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(error == nil ? (focused ? palette.accent : Color.clear) : palette.danger,
                            lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)

            if let error {
                HStack(spacing: 5) {
                    Circle().fill(palette.danger).frame(width: 4, height: 4)
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.danger)
                }
                .padding(.leading, 4)
            }
        }
    }
}

extension V3TextField where Trailing == EmptyView {
    init(palette: V3Palette, label: String, placeholder: String, text: Binding<String>,
         icon: String? = nil, isSecure: Bool = false,
         keyboard: UIKeyboardType = .default,
         autocapitalize: TextInputAutocapitalization = .never,
         error: String? = nil, accessibilityID: String? = nil) {
        self.init(palette: palette, label: label, placeholder: placeholder, text: text,
                  icon: icon, isSecure: isSecure, keyboard: keyboard,
                  autocapitalize: autocapitalize, error: error,
                  accessibilityID: accessibilityID,
                  trailing: { EmptyView() })
    }
}
