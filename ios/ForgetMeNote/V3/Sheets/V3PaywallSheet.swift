import SwiftUI

/// V3-native paywall shell. A prototype-quality presentation so the Pro CTAs
/// (`V3SettingsScreen` "Try free for 7 days" + upsell card) have real feedback
/// instead of an empty closure. Does NOT reuse the legacy `StubPaywallView`
/// (that lives in read-only `Views/*`). Real RevenueCat wiring is deferred until
/// the App Store Connect product exists; `onStartTrial` is where it hooks in.
struct V3PaywallSheet: View {
    let palette: V3Palette
    var onStartTrial: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    private let perks: [(icon: String, title: String, body: String)] = [
        ("infinity", "Unlimited places", "Remember as many rooms, shelves and spots as you like."),
        ("icloud.fill", "Cloud sync", "Your map follows you across every device, backed up safely."),
        ("sparkles", "Smarter labels", "Better on-device suggestions when you snap a new place."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(palette.ink3)
                            .frame(width: 34, height: 34)
                            .background(palette.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("v3-paywall-close")
                }
                .padding(.top, 14)

                FlowerMark(size: 56, color: palette.accent, pollen: palette.pollen)
                    .padding(.top, 8)

                (Text("ForgetMeNote ").font(V3Font.headline(30)).foregroundStyle(palette.ink) +
                 Text("Pro").font(V3Font.headline(30, italic: true)).italic().foregroundStyle(palette.accent))
                    .tracking(-0.5)
                    .padding(.top, 16)

                Text("Everything you need to never lose track of your things.")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                    .padding(.top, 6)

                VStack(spacing: 12) {
                    ForEach(perks, id: \.title) { perk in
                        HStack(spacing: 14) {
                            Image(systemName: perk.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(palette.accent)
                                .frame(width: 40, height: 40)
                                .background(palette.accentBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(perk.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(palette.ink)
                                Text(perk.body)
                                    .font(.system(size: 12))
                                    .foregroundStyle(palette.ink3)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.top, 26)
                .padding(.horizontal, 4)

                Button {
                    V3Haptics.success()
                    onStartTrial()
                } label: {
                    Text("Try free for 7 days")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: 0x3D2A0E))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(palette.pollen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 28)
                .accessibilityIdentifier("v3-paywall-start-trial")

                Text("Then $2.99/month. Cancel anytime.")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.ink3)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 22)
        }
        .background(palette.paper.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(palette.paper)
        .presentationCornerRadius(24)
    }
}
