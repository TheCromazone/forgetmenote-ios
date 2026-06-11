import SwiftUI
import SwiftData

struct V3SettingsScreen: View {
    @Environment(\.v3Palette) private var paletteKey
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var auth
    @Environment(WalkthroughViewModel.self) private var walkthrough

    @Query private var settingsRows: [AppSettings]
    @Query(sort: \ImageItem.createdAt) private var allItems: [ImageItem]

    private var palette: V3Palette { paletteKey }
    private var settings: AppSettings? { settingsRows.first }

    // @State mirrors for slider/toggle values — write through to AppSettings on commit.
    @State private var fillTransparency: Double = 25
    @State private var borderWidth: Double = 3
    @State private var borderTransparency: Double = 40
    @State private var highlightStrength: Double = 20
    @State private var searchCollapsed: Bool = true
    @State private var loaded = false
    @State private var showPaywall = false

    /// Gemini enhanced-scan key — read by `V3GeminiVision.apiKey`. Stored in
    /// UserDefaults (dev/demo scope; a shipped build should proxy through a
    /// cloud function instead of holding a key on-device at all).
    @AppStorage("v3_gemini_api_key") private var geminiKey: String = ""
    @AppStorage("v3_gemini_enabled") private var geminiEnabled: Bool = true
    @State private var showGeminiSheet = false

    private var snapshot: V3SettingsSnapshot {
        V3SettingsSnapshot(
            fillTransparency: fillTransparency,
            borderWidth: borderWidth,
            borderTransparency: borderTransparency,
            highlightStrength: highlightStrength,
            searchCollapsed: searchCollapsed
        )
    }

    var body: some View {
        scrollContent
            .background(paperBackground)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: loadSettings)
            .onChange(of: snapshot) { _, v in commit(v) }
    }

    private func commit(_ snap: V3SettingsSnapshot) {
        guard let s = settings else { return }
        s.childRectangleTransparency = Float(snap.fillTransparency / 100.0)
        s.childRectangleBorderWidth = Float(snap.borderWidth)
        s.childRectangleBorderTransparency = Float(snap.borderTransparency / 100.0)
        s.updatedHighlightPercentage = Float(snap.highlightStrength / 100.0)
        s.searchThroughCollapsedImages = snap.searchCollapsed
        try? modelContext.save()
    }

    @ViewBuilder private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                V3NavHeader(palette: palette, title: "You",
                            onBack: { dismiss() })
                contentColumn
            }
        }
    }

    @ViewBuilder private var contentColumn: some View {
        VStack(spacing: 0) {
            profileCard
                .padding(.top, 4)
            proUpsellCard
                .padding(.top, 14)
            walkthroughSection
            aiScanSection
            subspaceSection
            refreshedSection
            searchSection
            accountSection
            footer
                .padding(.top, 32)
                .padding(.bottom, 80)
        }
        .padding(.horizontal, 22)
    }

    private func loadSettings() {
        guard !loaded, let s = settings else { return }
        loaded = true
        fillTransparency = Double(s.childRectangleTransparency * 100)
        borderWidth = Double(s.childRectangleBorderWidth)
        borderTransparency = Double(s.childRectangleBorderTransparency * 100)
        highlightStrength = Double(s.updatedHighlightPercentage * 100)
        searchCollapsed = s.searchThroughCollapsedImages
    }


    @ViewBuilder private var profileCard: some View {
        let user = auth.currentUser
        let initial = (user?.name ?? "G").trimmingCharacters(in: .whitespaces)
            .first.map(String.init)?.uppercased() ?? "?"
        HStack(spacing: 14) {
            Text(initial)
                .font(V3Font.headline(28))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(palette.accent, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(user?.name ?? "Guest")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(palette.ink)
                Text(user?.email ?? "\(allItems.count) places remembered")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.ink3)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(18)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }

    @ViewBuilder private var proUpsellCard: some View {
        ZStack(alignment: .topTrailing) {
            FlowerMark(size: 140, color: palette.accent, pollen: palette.pollen)
                .opacity(0.15)
                .offset(x: 30, y: -20)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.pollen)
                    Text("FORGETMENOTE PRO")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(palette.pollen)
                }
                Text("Unlimited places.\nCloud sync. Smarter labels.")
                    .font(V3Font.headline(22))
                    .foregroundStyle(.white)
                Button {
                    V3Haptics.impact(.light)
                    showPaywall = true
                } label: {
                    Text("Try free for 7 days")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: 0x3D2A0E))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(palette.pollen, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .accessibilityIdentifier("v3-settings-upgrade")
            }
            .padding(16)
        }
        .background(
            LinearGradient(colors: [palette.ink, Color(hex: 0x2A2D38)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .sheet(isPresented: $showPaywall) {
            V3PaywallSheet(palette: palette).environment(\.v3Palette, palette)
        }
    }

    @ViewBuilder private var walkthroughSection: some View {
        V3SettingsSection(palette: palette, title: "Walkthrough") {
            V3SettingsRow(palette: palette, icon: "sparkles", label: "Show me the tour",
                          accent: true,
                          accessibilityID: "v3-settings-show-walkthrough") {
                walkthrough.restart()
                dismiss()
            }
        }
    }

    @ViewBuilder private var aiScanSection: some View {
        let hasKey = !geminiKey.trimmingCharacters(in: .whitespaces).isEmpty
        V3SettingsSection(palette: palette, title: "AI scanning") {
            // The guided setup (get key → paste → verify) lives in the sheet;
            // this section is just status + the on/off choice. Apple Vision
            // on-device is always the fallback and needs no setup.
            Button {
                V3Haptics.selection()
                showGeminiSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: hasKey ? "checkmark.seal.fill" : "wand.and.stars")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 32, height: 32)
                        .background(palette.accentBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hasKey ? "Enhanced scans ✦" : "Set up enhanced scans ✦")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.ink)
                        Text(hasKey ? "Gemini key saved — tap to manage."
                                    : "Free Google AI key · better names, more objects.")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.ink3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.ink3)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(SwiftUI.Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v3-settings-gemini-setup")

            if hasKey {
                Divider().background(palette.line).padding(.leading, 16)
                Button {
                    V3Haptics.selection()
                    geminiEnabled.toggle()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use Gemini for “Find objects”")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(palette.ink)
                            Text(geminiEnabled
                                 ? "Photos are sent to Google for scanning."
                                 : "Scanning on-device with Apple Vision (private, offline).")
                                .font(.system(size: 12))
                                .foregroundStyle(palette.ink3)
                        }
                        Spacer()
                        V3Switch(palette: palette, isOn: geminiEnabled)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(SwiftUI.Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("v3-settings-gemini-toggle")
            }
        }
        .sheet(isPresented: $showGeminiSheet) {
            V3GeminiKeySheet().environment(\.v3Palette, palette)
        }
    }

    @ViewBuilder private var subspaceSection: some View {
        V3SettingsSection(palette: palette, title: "Sub-space rectangles") {
            V3SliderRow(palette: palette, label: "Fill transparency",
                        value: $fillTransparency, range: 5...60, unit: "%",
                        accessibilityID: "v3-slider-fill")
            Divider().background(palette.line).padding(.leading, 16)
            V3SliderRow(palette: palette, label: "Border width",
                        value: $borderWidth, range: 1...10, unit: "px",
                        accessibilityID: "v3-slider-border-width")
            Divider().background(palette.line).padding(.leading, 16)
            V3SliderRow(palette: palette, label: "Border transparency",
                        value: $borderTransparency, range: 5...60, unit: "%",
                        accessibilityID: "v3-slider-border-transparency")
        }
    }

    @ViewBuilder private var refreshedSection: some View {
        V3SettingsSection(palette: palette, title: "Refreshed items") {
            HStack {
                Text("Highlight color")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.ink)
                Spacer()
                Circle()
                    .fill(palette.pollen)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(palette.surface, lineWidth: 2))
                    .overlay(Circle().stroke(palette.line, lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            Divider().background(palette.line).padding(.leading, 16)
            V3SliderRow(palette: palette, label: "Highlight strength",
                        value: $highlightStrength, range: 0...100, unit: "%",
                        accessibilityID: "v3-slider-highlight")
        }
    }

    @ViewBuilder private var searchSection: some View {
        V3SettingsSection(palette: palette, title: "Search") {
            Button {
                V3Haptics.selection()
                searchCollapsed.toggle()
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Search hidden items")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.ink)
                        Text("Include collapsed places when searching.")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.ink3)
                    }
                    Spacer()
                    V3Switch(palette: palette, isOn: searchCollapsed)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(SwiftUI.Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v3-settings-search-toggle")
        }
    }

    @ViewBuilder private var accountSection: some View {
        V3SettingsSection(palette: palette, title: "Account") {
            V3SettingsRow(palette: palette, icon: "rectangle.portrait.and.arrow.right",
                          label: "Sign out", destructive: true,
                          showsChevron: false,
                          accessibilityID: "v3-settings-sign-out") {
                V3Haptics.warning()
                auth.signOut()
                dismiss()
            }
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: 8) {
            FlowerMark(size: 20, color: palette.accentSoft, pollen: palette.pollen)
                .opacity(0.7)
            Text("ForgetMeNote · v3.0")
                .font(.system(size: 12))
                .foregroundStyle(palette.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var paperBackground: some View {
        ZStack {
            palette.paper
            LinearGradient(colors: [palette.surface.opacity(0.6), .clear],
                           startPoint: .top, endPoint: .center)
        }
        .ignoresSafeArea()
    }
}

/// Snapshot of the 5 settings values we mirror as @State. Combining them
/// into a single Equatable lets us use one `.onChange(of:)` modifier
/// instead of five chained modifiers (which the Swift type-checker
/// struggles to resolve in reasonable time).
struct V3SettingsSnapshot: Equatable {
    let fillTransparency: Double
    let borderWidth: Double
    let borderTransparency: Double
    let highlightStrength: Double
    let searchCollapsed: Bool
}
