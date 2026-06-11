import SwiftUI

/// Modal sheet for viewing and editing an item's notes.
///
/// Mirrors Android's `NotesDialog`. Multi-line text input, clear-all action,
/// save/cancel. Voice input button is reserved for Phase 5 (SFSpeechRecognizer).
struct NotesDialog: View {
    let initialNotes: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(initialNotes: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.initialNotes = initialNotes
        self.onSave = onSave
        self.onCancel = onCancel
        self._text = State(initialValue: initialNotes)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                TextEditor(text: $text)
                    .frame(minHeight: 200, maxHeight: .infinity)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("notes-text-editor")

                HStack {
                    Text("\(text.count) chars")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(role: .destructive) {
                        text = ""
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .font(.footnote)
                    }
                    .disabled(text.isEmpty)
                    .accessibilityIdentifier("notes-clear-button")
                }
            }
            .padding()
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .accessibilityIdentifier("notes-save-button")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
