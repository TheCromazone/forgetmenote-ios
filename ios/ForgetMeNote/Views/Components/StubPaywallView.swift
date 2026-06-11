import SwiftUI

/// Stub paywall presented from Settings. The real implementation (Phase 8b)
/// uses `RevenueCatUI.PaywallView()` after products are registered in App
/// Store Connect and offerings are configured in the RevenueCat dashboard.
///
/// For the prototype demo this shows what Pro would unlock so the friend can
/// see the IAP surface area without needing to actually configure RevenueCat.
struct StubPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showStubAlert = false

    private let perks: [(String, String, String)] = [
        ("infinity", "Unlimited Spaces & Sub-Spaces",
         "Free tier caps at 50 items. Pro removes the cap."),
        ("icloud.and.arrow.up", "Cloud backup & cross-device sync",
         "Auto-sync your Spaces between iPhone, iPad, and Mac."),
        ("brain.head.profile", "Smarter ML detection",
         "Higher-precision custom Core ML model with on-device fine-tuning."),
        ("bell.badge.fill", "Custom reminder cadences",
         "Hourly / daily / custom-day reminders for marked-Updated items."),
        ("paintbrush.pointed.fill", "Themes",
         "Light/dark accents, custom Room background gradients."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.yellow, .orange)
                            .symbolRenderingMode(.palette)
                        Text("Forget Me Note Pro")
                            .font(.largeTitle.weight(.bold))
                        Text("Unlock the full visual-memory toolkit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)

                    // Perks list
                    VStack(spacing: 12) {
                        ForEach(perks, id: \.0) { perk in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: perk.0)
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(perk.1).font(.body.weight(.semibold))
                                    Text(perk.2).font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal)

                    // Pricing card
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Monthly").font(.body.weight(.semibold))
                                Text("Auto-renews · cancel anytime")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("$1.99 / mo")
                                .font(.body.weight(.bold))
                                .monospacedDigit()
                        }
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Annual").font(.body.weight(.semibold))
                                Text("Save 33% · billed yearly")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("$15.99 / yr")
                                .font(.body.weight(.bold))
                                .monospacedDigit()
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Button {
                        showStubAlert = true
                    } label: {
                        Text("Subscribe")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .accessibilityIdentifier("paywall-subscribe")

                    Text("Terms apply. By subscribing you agree to the in-app Terms of Use and Privacy Policy.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("paywall-close")
                }
            }
            .alert("Coming Soon", isPresented: $showStubAlert) {
                Button("OK") { showStubAlert = false }
            } message: {
                Text("Prototype build. Real subscription requires the RevenueCat SDK + App Store Connect IAP product registration. Wire this up after Phase 8.")
            }
        }
    }
}
