import SwiftUI

/// Phase-1 stub. Real implementation in Phase 5 alongside the walkthrough.
struct HelpScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Forget Me Note")
                    .font(.largeTitle.bold())
                Text("Hierarchical visual memory.")
                    .foregroundStyle(.secondary)
                Group {
                    helpItem(icon: "house",
                             title: "Rooms",
                             body: "Top-level containers without a photo. Create one to group spaces.")
                    helpItem(icon: "camera",
                             title: "Spaces",
                             body: "Photographed items. Tap inside a space to draw a rectangle and create a child sub-space.")
                    helpItem(icon: "magnifyingglass",
                             title: "Search",
                             body: "Search across names, tags, and notes from the search bar on the main screen.")
                    helpItem(icon: "exclamationmark.circle",
                             title: "Updated flag",
                             body: "Mark items that have changed in real life but haven't been re-photographed.")
                }
                Spacer(minLength: 40)
                Text("This is a Phase-1 placeholder. Real walkthrough lands in Phase 5.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton()
    }

    private func helpItem(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(body).foregroundStyle(.secondary)
            }
        }
    }
}
