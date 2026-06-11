import SwiftUI
import SwiftData

/// Pure, testable item filter shared by `V3FindScreen.results`.
/// Matches `query` (case-insensitive) against name, notes, or any tag.
/// Returns the input order for an empty/whitespace query → no matches.
func v3FilterItems(_ items: [ImageItem], query: String) -> [ImageItem] {
    let q = query.trimmingCharacters(in: .whitespaces).lowercased()
    guard !q.isEmpty else { return [] }
    return items.filter { item in
        item.name.lowercased().contains(q) ||
        item.notes.lowercased().contains(q) ||
        item.tags.contains(where: { $0.lowercased().contains(q) })
    }
}

/// Pure, testable route picker for a tapped search result — mirrors the
/// browse screens' `openItem`: anything with a photo or a traced region opens
/// its picture directly (`v3Space`); rooms and empty boxes open the browse
/// centered + expanded on them (`v3Room`).
func v3SearchDestination(for item: ImageItem) -> Route {
    item.v3HasRegion ? .v3Space(spaceId: item.id) : .v3Room(roomId: item.id)
}

/// V3 Find — port of screens-home.jsx FindScreen.
///
/// Big serif "Find a *thing*" title, pill search input, popular tags chip
/// cloud, recent searches list. Real-time filter on name / tag / note.
struct V3FindScreen: View {
    let palette: V3Palette
    @Binding var path: NavigationPath

    @Query(sort: \ImageItem.createdAt) private var allItems: [ImageItem]
    @State private var query: String = ""
    @FocusState private var searchFocused: Bool

    /// Persisted recent searches as a JSON-encoded [String] (most-recent-first,
    /// capped + deduped). Brand-new users start empty — no fake seed.
    @AppStorage("v3_recent_searches") private var recentSearchesData: Data = Data()

    private var recents: [String] {
        (try? JSONDecoder().decode([String].self, from: recentSearchesData)) ?? []
    }

    private var allTags: [String] {
        var set = Set<String>()
        for item in allItems { for t in item.tags { set.insert(t) } }
        return Array(set).sorted()
    }

    private var results: [ImageItem] {
        v3FilterItems(allItems, query: query)
    }

    /// Record `q` as the newest recent search: trim, dedupe, cap at 6.
    private func recordSearch(_ q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var list = recents.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        list.insert(trimmed, at: 0)
        if list.count > 6 { list = Array(list.prefix(6)) }
        if let data = try? JSONEncoder().encode(list) { recentSearchesData = data }
    }

    private func clearRecents() {
        recentSearchesData = (try? JSONEncoder().encode([String]())) ?? Data()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleBlock
                searchBar
                if query.isEmpty {
                    if !allTags.isEmpty { tagCloud }
                    if !recents.isEmpty { recentSearches }
                } else {
                    resultList
                }
                Spacer(minLength: 110)
            }
            // Tap anywhere off the field (empty space, tags, results area) to
            // dismiss the keyboard — buttons inside still get their taps first.
            .frame(maxWidth: .infinity, minHeight: 600, alignment: .topLeading)
            .contentShape(SwiftUI.Rectangle())
            .onTapGesture { searchFocused = false }
        }
        // Dragging/scrolling anywhere also dismisses the keyboard.
        .scrollDismissesKeyboard(.immediately)
        .background(paperBackground)
        // Guaranteed escape hatch: a keyboard-accessory Done button so the
        // keyboard can never trap the user above the tab bar.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { searchFocused = false }
                    .font(.system(size: 15, weight: .semibold))
                    .accessibilityIdentifier("v3-keyboard-done")
            }
        }
    }

    @ViewBuilder private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            (Text("Find a ")
                .font(V3Font.headline(36)).foregroundStyle(palette.ink) +
             Text("thing")
                .font(V3Font.headline(36, italic: true)).italic()
                .foregroundStyle(palette.accent) +
             Text(".")
                .font(V3Font.headline(36)).foregroundStyle(palette.ink))
            .tracking(-0.7)

            Text("Search by name, tag, or anything you wrote in the notes.")
                .font(.system(size: 14))
                .foregroundStyle(palette.ink2)
        }
        .padding(.horizontal, 22)
        .padding(.top, 64)
    }

    @ViewBuilder private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.ink3)
            TextField("bay leaves, #cables, charger…", text: $query)
                .font(.system(size: 16))
                .foregroundStyle(palette.ink)
                .tracking(-0.15)
                .submitLabel(.search)
                .focused($searchFocused)
                .accessibilityIdentifier("v3-search-input")
                .onSubmit { recordSearch(query) }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(palette.ink3)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(palette.surface, in: Capsule())
        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
        .padding(.horizontal, 22)
        .padding(.top, 20)
    }

    @ViewBuilder private var tagCloud: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Popular tags")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(allTags.prefix(16), id: \.self) { tag in
                        Button { query = tag } label: {
                            Text(tag)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(palette.ink)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(palette.accentBg, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
            }
        }
        .padding(.top, 28)
    }

    @ViewBuilder private var recentSearches: some View {
        let list = recents
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("Recent searches")
                Spacer()
                Button { clearRecents() } label: {
                    Text("Clear")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.ink3)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("v3-recent-clear")
                .padding(.trailing, 22)
            }
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element) { index, s in
                    Button { query = s } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock")
                                .foregroundStyle(palette.ink3)
                            Text(s)
                                .font(.system(size: 15))
                                .foregroundStyle(palette.ink)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .foregroundStyle(palette.ink3)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("v3-recent-\(index)")
                    if index != list.count - 1 {
                        Divider().background(palette.line).padding(.leading, 44)
                    }
                }
            }
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
            .padding(.horizontal, 22)
        }
        .padding(.top, 28)
    }

    @ViewBuilder private var resultList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(results.count) \(results.count == 1 ? "match" : "matches")")
                .font(.system(size: 12))
                .foregroundStyle(palette.ink3)
                .padding(.top, 20)
            if results.isEmpty {
                emptyState
            } else {
                let byId = Dictionary(allItems.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
                ForEach(results, id: \.id) { item in
                    Button {
                        // Jump straight to the thing itself: its photo /
                        // sub-picture when it has one, else the browse
                        // centered on it. Keep the query in recents.
                        recordSearch(query)
                        searchFocused = false
                        path.append(v3SearchDestination(for: item))
                    } label: {
                        V3SearchResultRow(palette: palette,
                                          item: item,
                                          ancestry: ancestryString(for: item, byId: byId))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("v3-search-result-\(item.id)")
                }
            }
        }
        .padding(.horizontal, 22)
    }

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 12) {
            FlowerMark(size: 28, color: palette.ink3, pollen: palette.ink3)
                .opacity(0.5)
            Text("Nothing here for ")
                .foregroundStyle(palette.ink2)
            + Text("\"\(query)\"")
                .foregroundStyle(palette.ink2).italic()
            + Text(" yet.")
                .foregroundStyle(palette.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    /// Walk parents via an O(1) `byId` lookup (built once per result list)
    /// instead of `allItems.first(where:)` per hop per row.
    private func ancestryString(for item: ImageItem, byId: [String: ImageItem]) -> String {
        var crumbs: [String] = []
        var cur: ImageItem? = item
        while let c = cur, let pid = c.parentId, let parent = byId[pid] {
            crumbs.insert(parent.name, at: 0)
            cur = parent
        }
        return crumbs.isEmpty ? "Root" : crumbs.joined(separator: " › ")
    }

    @ViewBuilder
    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(V3Font.headline(22))
            .foregroundStyle(palette.ink)
            .tracking(-0.3)
            .padding(.horizontal, 22)
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

/// One search-result row. Extracted so each row owns its `@State` thumbnail and
/// loads a downsampled image off-main via `V3Thumbnail` instead of decoding a
/// full-resolution `UIImage(contentsOfFile:)` synchronously inside `body`.
private struct V3SearchResultRow: View {
    let palette: V3Palette
    let item: ImageItem
    let ancestry: String

    /// Downsampled thumbnail filled off-main in `.task`; nil shows the letter.
    @State private var thumb: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            if let img = thumb {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.accentBg)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(item.name.prefix(1).uppercased())
                            .font(V3Font.headline(22))
                            .foregroundStyle(palette.accent)
                    )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.ink)
                    .tracking(-0.15)
                Text(ancestry)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.ink3)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.ink3)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .task(id: item.filePath) {
            // Seed synchronously from cache to avoid a flash, then load off-main.
            if let path = item.filePath, !path.isEmpty {
                if thumb == nil { thumb = V3Thumbnail.cached(path: path, maxPixelSize: 140) }
                thumb = await V3Thumbnail.load(path: path, maxPixelSize: 140)
            } else {
                thumb = nil
            }
        }
    }
}
