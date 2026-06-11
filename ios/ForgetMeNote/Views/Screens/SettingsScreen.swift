import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Phase-6 implementation. Sliders, color pickers, toggles. Mutations are made
/// directly on the queried `AppSettings` instance (SwiftData persists modifs
/// on the main `ModelContext` automatically).
///
/// Replaces the read-only Phase-1 stub.
struct SettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRows: [AppSettings]
    @Environment(WalkthroughViewModel.self) private var walkthrough
    @Environment(\.dismiss) private var dismiss

    private var s: AppSettings? { settingsRows.first }
    @State private var showPaywall: Bool = false
    @State private var showImporter: Bool = false
    @State private var shareURL: URL?
    @State private var importSummary: String?
    @State private var orphanResult: String?
    @State private var busy: Bool = false

    var body: some View {
        Form {
            Section {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow, .orange)
                            .symbolRenderingMode(.palette)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Forget Me Note Pro").font(.body.weight(.semibold))
                            Text("Unlimited Spaces, cloud sync, smarter ML")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityIdentifier("settings-upgrade")
            }
            Section("Walkthrough") {
                Button {
                    walkthrough.restart()
                    dismiss()
                } label: {
                    Label("Show walkthrough", systemImage: "info.bubble")
                }
                .accessibilityIdentifier("settings-show-walkthrough")
            }

            if let s {
                subspaceRectangleSection(s)
                updatedItemsSection(s)
                photosSection(s)
                dataSection
                miscSection(s)
            } else {
                Section { Text("Loading settings…").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton()
        .sheet(isPresented: $showPaywall) {
            StubPaywallView()
        }
        .sheet(item: $shareItem) { wrapper in
            ShareSheet(activityItems: [wrapper.url])
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.zip],
                      allowsMultipleSelection: false) { result in
            handleImport(result: result)
        }
        .alert("Import complete",
               isPresented: Binding(get: { importSummary != nil },
                                    set: { if !$0 { importSummary = nil } })) {
            Button("OK") { importSummary = nil }
        } message: {
            Text(importSummary ?? "")
        }
        .alert("Orphan scan",
               isPresented: Binding(get: { orphanResult != nil },
                                    set: { if !$0 { orphanResult = nil } })) {
            Button("OK") { orphanResult = nil }
        } message: {
            Text(orphanResult ?? "")
        }
    }

    // The share sheet needs an Identifiable; wrap the URL.
    private struct URLWrapper: Identifiable {
        let id = UUID()
        let url: URL
    }
    @State private var shareItem: URLWrapper?

    // MARK: - Data (export/import/orphans)

    @ViewBuilder
    private var dataSection: some View {
        Section("Data") {
            Button {
                Task { await exportNow() }
            } label: {
                Label(busy ? "Working…" : "Export to .zip",
                      systemImage: "square.and.arrow.up")
            }
            .disabled(busy)
            .accessibilityIdentifier("settings-export")

            Button {
                showImporter = true
            } label: {
                Label("Import from .zip", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("settings-import")

            Button {
                Task { await scanOrphans(remove: false) }
            } label: {
                Label("Scan for orphan images", systemImage: "magnifyingglass.circle")
            }
            .accessibilityIdentifier("settings-scan-orphans")

            Button(role: .destructive) {
                Task { await scanOrphans(remove: true) }
            } label: {
                Label("Delete orphan images", systemImage: "trash")
            }
            .accessibilityIdentifier("settings-delete-orphans")
        }
    }

    @MainActor
    private func exportNow() async {
        busy = true
        defer { busy = false }
        do {
            let url = try await ExportImportService.exportToTempFile(modelContext: modelContext)
            shareItem = URLWrapper(url: url)
        } catch {
            importSummary = "Export failed: \(error.localizedDescription)"
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await runImport(url: url) }
        case .failure(let err):
            importSummary = "Import failed: \(err.localizedDescription)"
        }
    }

    @MainActor
    private func runImport(url: URL) async {
        busy = true
        defer { busy = false }
        // fileImporter delivers a security-scoped URL — start access.
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        do {
            let summary = try await ExportImportService.importFromZip(url, modelContext: modelContext)
            importSummary = "Added \(summary.added) item(s), updated \(summary.updated), copied \(summary.imagesCopied) image(s)."
            AppIconBadge.refreshFromCurrentSettings(modelContext: modelContext)
        } catch {
            importSummary = "Import failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func scanOrphans(remove: Bool) async {
        busy = true
        defer { busy = false }
        let repo = ImageRepository(modelContainer: modelContext.container)
        if remove {
            let removed = (try? await repo.removeOrphanedImages()) ?? 0
            orphanResult = "Removed \(removed) orphan image file(s)."
        } else {
            let orphans = await repo.checkOrphanedImages()
            orphanResult = orphans.isEmpty
                ? "No orphan images found."
                : "Found \(orphans.count) orphan item(s) in DB (file missing)."
        }
    }

    // MARK: - Sub-space rectangle

    @ViewBuilder
    private func subspaceRectangleSection(_ s: AppSettings) -> some View {
        Section("Sub-space rectangle") {
            HStack {
                Text("Fill transparency")
                Spacer()
                Text(String(format: "%.0f%%", s.childRectangleTransparency * 100))
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(s.childRectangleTransparency) },
                    set: { newValue in
                        s.childRectangleTransparency = Float(newValue)
                        try? modelContext.save()
                    }),
                in: 0...1
            )
            .accessibilityIdentifier("settings-rect-fill")

            HStack {
                Text("Border width")
                Spacer()
                Text("\(Int(s.childRectangleBorderWidth)) px")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(s.childRectangleBorderWidth) },
                    set: { newValue in
                        s.childRectangleBorderWidth = Float(newValue)
                        try? modelContext.save()
                    }),
                in: 1...10, step: 1
            )
            .accessibilityIdentifier("settings-rect-border")

            HStack {
                Text("Border transparency")
                Spacer()
                Text(String(format: "%.0f%%", s.childRectangleBorderTransparency * 100))
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(s.childRectangleBorderTransparency) },
                    set: { newValue in
                        s.childRectangleBorderTransparency = Float(newValue)
                        try? modelContext.save()
                    }),
                in: 0...1
            )
            .accessibilityIdentifier("settings-rect-border-alpha")
        }
    }

    // MARK: - Updated items

    @ViewBuilder
    private func updatedItemsSection(_ s: AppSettings) -> some View {
        Section("Updated items") {
            ColorPicker(
                "Highlight color",
                selection: Binding(
                    get: { Color(argb: s.updatedHighlightColor) },
                    set: { newColor in
                        s.updatedHighlightColor = newColor.argbInt64
                        try? modelContext.save()
                    }
                ),
                supportsOpacity: false
            )
            .accessibilityIdentifier("settings-highlight-color")

            HStack {
                Text("Highlight opacity")
                Spacer()
                Text(String(format: "%.0f%%", s.updatedHighlightPercentage * 100))
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(s.updatedHighlightPercentage) },
                    set: { newValue in
                        s.updatedHighlightPercentage = Float(newValue)
                        try? modelContext.save()
                    }),
                in: 0...0.6
            )
            .accessibilityIdentifier("settings-highlight-alpha")

            Toggle("Show badge on app icon",
                   isOn: Binding(
                    get: { s.showUpdatedBadge },
                    set: { newValue in
                        s.showUpdatedBadge = newValue
                        try? modelContext.save()
                        Task { @MainActor in
                            AppIconBadge.refresh(
                                modelContext: modelContext,
                                showBadge: newValue
                            )
                        }
                    }))
                .accessibilityIdentifier("settings-show-badge")

            Toggle("Periodic reminders",
                   isOn: Binding(
                    get: { s.updatedRemindersEnabled },
                    set: { newValue in
                        s.updatedRemindersEnabled = newValue
                        try? modelContext.save()
                        UpdatedItemsReminder.reschedule(modelContainer: modelContext.container)
                    }))
                .accessibilityIdentifier("settings-reminders-enabled")

            if s.updatedRemindersEnabled {
                Picker("Frequency", selection: Binding(
                    get: { s.updatedRemindersFrequency },
                    set: { newValue in
                        s.updatedRemindersFrequency = newValue
                        try? modelContext.save()
                        UpdatedItemsReminder.reschedule(modelContainer: modelContext.container)
                    })) {
                    Text("Weekly").tag("weekly")
                    Text("Monthly").tag("monthly")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings-reminders-frequency")
                Text("Reminders fire opportunistically — iOS chooses the exact moment within the cadence window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Photos

    @ViewBuilder
    private func photosSection(_ s: AppSettings) -> some View {
        Section("Photos") {
            Toggle("Scale down on capture",
                   isOn: Binding(
                    get: { s.scaleDownPhotos },
                    set: { newValue in
                        s.scaleDownPhotos = newValue
                        try? modelContext.save()
                    }))
                .accessibilityIdentifier("settings-scale-down")

            if s.scaleDownPhotos {
                HStack {
                    Text("Min width")
                    Spacer()
                    Text("\(s.scaleDownMinWidth) px")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(s.scaleDownMinWidth) },
                        set: { newValue in
                            s.scaleDownMinWidth = Int(newValue)
                            try? modelContext.save()
                        }),
                    in: 480...2160, step: 20
                )
                .accessibilityIdentifier("settings-min-width")
            }
        }
    }

    // MARK: - Misc

    @ViewBuilder
    private func miscSection(_ s: AppSettings) -> some View {
        Section("Misc") {
            Toggle("Search through collapsed items",
                   isOn: Binding(
                    get: { s.searchThroughCollapsedImages },
                    set: { newValue in
                        s.searchThroughCollapsedImages = newValue
                        try? modelContext.save()
                    }))
                .accessibilityIdentifier("settings-search-collapsed")

            Toggle("Auto-check for orphaned images",
                   isOn: Binding(
                    get: { s.checkOrphanedImages },
                    set: { newValue in
                        s.checkOrphanedImages = newValue
                        try? modelContext.save()
                    }))
                .accessibilityIdentifier("settings-check-orphans")
        }
    }
}
