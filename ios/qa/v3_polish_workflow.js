export const meta = {
  name: 'v3-polish-fanout',
  description: 'Fan out P1/P2 ForgetMeNote v3 polish fixes across disjoint file owners',
  phases: [
    { title: 'Fix', detail: 'one agent per disjoint file-group' },
    { title: 'Verify', detail: 'adversarial read-back of each landed change' },
  ],
}

// Each agent OWNS a disjoint set of files. NO TWO AGENTS TOUCH THE SAME FILE
// (this tree is NOT a git repo, so there is no worktree isolation — overlapping
// edits would clobber). Shared rules injected into every prompt:
const RULES = `
HARD RULES (violating any is a failure):
- This is iOS Swift (SwiftUI, iOS 17 target). Work ONLY in the files explicitly assigned to you below. Do NOT touch any other file.
- Do NOT edit anything under ForgetMeNote/Views/*, ForgetMeNote/ML/*, or ForgetMeNote/V4/* — they are shared/legacy/Codex and read-only. You may CALL their public APIs.
- Do NOT run xcodebuild, xcodegen, pod, or maestro. Do NOT build. The orchestrator does one central integration build afterward. Your job is source edits only.
- Several earlier P0 edits already exist in some files — PRESERVE them. Never remove an existing .accessibilityIdentifier, the delete-pop (onDeleted) logic, onOpenSearch wiring, or the v3-home-greeting id. Build ON TOP of current file contents (read the file first).
- VERIFY each claimed bug against the CURRENT source before editing — some spec items are already done (e.g. deleteRecursive already unions childIds+parentId; V3SettingsScreen is already native; New Room is already wired; room color already applied via hue(for:item)). If already done, do NOT churn it; report it as "already-correct".
- Match the surrounding code style exactly (naming, spacing, comment density). Keep diffs minimal and focused.
- Available shared primitives you SHOULD use (already created, in V3/):
  * V3Haptics.impact(_:)/selection()/success()/warning()  (UIKit feedback, main-thread safe)
  * V3Thumbnail.load(path:maxPixelSize:) async -> UIImage?  and  V3Thumbnail.cached(path:maxPixelSize:)  (NSCache, off-main decode)
  * V3Spacing / V3Radius tokens; V3PressableButtonStyle (.buttonStyle(.v3Pressable))
  * V3Greeting.period(at:) / V3Greeting.phrase(at:)  (time-of-day greeting)
  * V3ImageDownsampler.downsample(path:maxPixelSize:)  (off-main ImageIO)
- Maestro accessibility ids must be prefixed "v3-".
Return a STRUCTURED report (per the schema): the files you changed, a one-line-per-change summary, anything you found already-correct, and any compile risks you are unsure about.`

const REPORT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['filesChanged', 'changes', 'alreadyCorrect', 'risks'],
  properties: {
    filesChanged: { type: 'array', items: { type: 'string' }, description: 'absolute paths you edited' },
    changes: { type: 'array', items: { type: 'string' }, description: 'one concise line per change made' },
    alreadyCorrect: { type: 'array', items: { type: 'string' }, description: 'spec items found already done, not churned' },
    risks: { type: 'array', items: { type: 'string' }, description: 'compile/behaviour risks you are unsure about' },
  },
}

const ROOT = '/Users/matthewcromaz/Documents/forgetmenotev3/ios/ForgetMeNote/V3'

// ---- The disjoint work units -------------------------------------------------
const UNITS = [
  {
    label: 'perf-space',
    files: [`${ROOT}/Screens/V3SpaceScreen.swift`],
    task: `PERFORMANCE + correctness in V3SpaceScreen.swift ONLY.
1. The computed \`private var image: UIImage? { v3LoadImage(filePath: item?.filePath) }\` re-decodes the full-res hero JPEG on every body pass AND once per sub-card (N+1 synchronous full-res decodes). Replace it with \`@State private var heroImage: UIImage?\` populated in a \`.task(id: item?.filePath)\` via \`await V3ImageDownsampler.downsample(path:)\` off-main. Use \`heroImage\` for the hero (heroPhoto) AND pass it to every V3SubScanCard's existing \`parentImage:\` param so sub-cards never decode. Keep the letter fallback when nil.
2. O(n^2) scans in body: \`ancestry\` does \`allItems.first(where:{ $0.id == pid })\` per hop and \`subs\`/grid do \`allItems.filter{ $0.parentId == ... }\`. Build lookup dicts once per render near the top of body or as computed helpers: \`byId = Dictionary(uniqueKeysWithValues: allItems.map{ ($0.id,$0) })\` and a childCounts dict \`Dictionary(grouping: allItems, by: \\.parentId).mapValues(\\.count)\`. Use O(1) lookups for ancestry, the grid's \`kids.count\`, etc.
3. runDetection() has no generation token (unlike identifyAt which uses identifyToken). Add \`@State private var detectToken = 0\`; increment + capture locally at the start of runDetection; in the completion bail if the captured token != current. Keep \`.disabled(isDetecting)\` behavior.
PRESERVE the existing onDeleted closure on the V3DetailSheet sheet, the \`.onChange(of: matches.isEmpty)\` self-heal, and the not-found V3NavHeader+V3EmptyState branch (all added earlier). Add a \`.selection\` haptic when the view-mode switcher toggles and \`.impact(.light)\` when a detection is selected.`,
  },
  {
    label: 'perf-createsub-autolabel',
    files: [`${ROOT}/Screens/V3CreateSubScreen.swift`],
    task: `PERFORMANCE + the AUTO-LABEL feature in V3CreateSubScreen.swift ONLY.
1. CROP LAG: in \`photoArea\`, the static image layer re-lays-out every drag tick because the crop rect mutates 60x/sec inside the same GeometryReader. Apply \`.drawingGroup()\` to the static image \`Group { Image/letter }.frame(...).clipped()\` so it rasterizes once; keep the crop box + 4 dimming Rectangles in the live (non-rasterized) layer. (CLAUDE.md falsely claimed drawingGroup already exists — grep proved it never did. Actually add it.)
2. AUTO-LABEL (NEW FEATURE the user explicitly asked for — "places should be autolabeled after a picture is taken, like v4, via on-device ML"): in the existing \`.task(id: parent?.id)\` (or a new \`.task\`), AFTER loadDisplayImage(), if \`name\` is still empty AND a fresh capture exists (\`tempPhotoPath != nil\`) AND suggestedTitle was nil, call \`await V3VisionService.suggestName(imagePath: tempPhotoPath!)\` and, if it returns a non-empty string and the user hasn't typed anything yet, set \`name\` to it. Add \`@State private var autoLabeling = false\` and show a subtle inline hint (e.g. a small "Naming…"/sparkles indicator near the NAME field) while running. NOTE: V3VisionService.suggestName(imagePath:) async -> String? is being added by the vision agent with EXACTLY that signature — call it as such.
3. SAVE polish: the Save button shows only "Saving…" text. Replace with an inline ProgressView while \`saving\`, keep \`.disabled(saving)\`, and fire \`V3Haptics.success()\` right before the dismiss/pop on a successful save. Fire \`V3Haptics.impact(.medium)\` when the crop toggle is enabled.`,
  },
  {
    label: 'perf-overlay',
    files: [`${ROOT}/Components/V3DetectionOverlay.swift`],
    task: `PERFORMANCE + alignment in V3DetectionOverlay.swift ONLY.
1. It calls \`maskImage(det.maskPNGData)\` = \`UIImage(data:)\` INSIDE the ForEach body, decoding every mask PNG on every render/frame, and draws each full-photo-size with \`.shadow\` (offscreen blur). Decode masks ONCE: accept a pre-decoded \`[UUID: UIImage]\` map (add an initializer param) OR build an internal cache keyed by detection id that decodes lazily and stores the result so re-renders reuse it. Wrap each glowing silhouette in \`.drawingGroup()\` so the shadow/glow rasterizes once. Cap simultaneously-shadowed masks if needed for perf.
2. MASK/BOX MISALIGNMENT: the mask uses \`scaledToFill\`/\`.aspectRatio\` while boxes use displayRect math → misaligns on non-4:5 photos. Make the mask use the IDENTICAL transform as the detection box (same normalized-rect → pixel mapping against \`size\`). Read V3DetectionGeometry for the displayRect helper if present and reuse it so mask, box, and label share one coordinate mapping. Validate the math against a square and a 3:4 ratio mentally.
If the overlay's public init signature changes, note it in risks (V3SpaceScreen constructs it — but that's the space agent's file; keep your change BACKWARD-COMPATIBLE by giving any new param a default value so the existing call site still compiles).`,
  },
  {
    label: 'perf-cards',
    files: [`${ROOT}/Components/V3PlaceCard.swift`, `${ROOT}/Components/V3RoomTile.swift`, `${ROOT}/Components/V3SubScanCard.swift`],
    task: `PERFORMANCE in the three card components ONLY (V3PlaceCard, V3RoomTile, V3SubScanCard).
All three decode full-res JPEGs synchronously in body (V3PlaceCard via v3LoadImage; V3RoomTile decodes up to 3 full images for tiny avatars; V3SubScanCard likely crops/decodes the parent image). For each:
- Hold an \`@State private var thumb: UIImage?\` (or an array for V3RoomTile's up-to-3 previews) and fill it in a \`.task(id: <filePath(s)>)\` via \`await V3Thumbnail.load(path:maxPixelSize:)\` with a pixel size matched to the displayed size (e.g. ~320 for place cards, ~120 for room-tile avatars). Show the existing letter/color fallback until loaded; optionally seed from \`V3Thumbnail.cached(...)\` synchronously to avoid a flash.
- Do NOT decode in body anymore.
- V3SubScanCard already receives a \`parentImage:\` UIImage param from the space screen — prefer cropping from THAT in-memory image (off main if heavy) rather than re-loading from disk; only fall back to V3Thumbnail if parentImage is nil.
- Apply \`.buttonStyle(.v3Pressable)\` to the card's Button for press feedback (replace \`.buttonStyle(.plain)\` where the whole card is the button). Keep all existing accessibility ids and badges intact.
KEEP the free functions \`v3TimeAgo\` and \`v3LoadImage\` in V3PlaceCard.swift (other files call them) — do not delete them.`,
  },
  {
    label: 'perf-home',
    files: [`${ROOT}/Screens/V3HomeScreen.swift`],
    task: `PERFORMANCE in V3HomeScreen.swift ONLY. PRESERVE the existing onOpenSearch param + its use, the v3-home-search id, the v3-home-greeting combined-a11y id, and the room-count pluralization fix (all added earlier — do NOT revert).
1. \`recentCard(item:)\` decodes \`UIImage(contentsOfFile:)\` synchronously for each 168x210 carousel card. Convert to an \`@State\`-backed thumbnail via \`V3Thumbnail.load(path:maxPixelSize: 420)\` in a \`.task(id: item.filePath)\` (extract a small subview struct if needed so each card owns its @State). Keep the letter fallback.
2. O(n^2): \`parentItem(of:)\` does \`allItems.first{ $0.id == pid }\` per recent card, and \`roomGrid\` does \`allItems.filter{ $0.parentId == room.id }\` per room. Build \`byId\` and \`childCounts\` dictionaries once (computed vars) and use O(1) lookups. V3RoomTile is owned by another agent — just pass it the same \`previewImagePaths\` you already compute (now via the dict) and \`childCount\`.
Do NOT change V3RoomTile itself.`,
  },
  {
    label: 'feat-find',
    files: [`${ROOT}/Screens/V3FindScreen.swift`],
    task: `FEATURES + perf in V3FindScreen.swift ONLY.
1. REAL recent searches: \`recentSearches\` currently iterates a hardcoded literal ["lightning cable","#christmas","bay leaves"] — every brand-new user sees fake searches. Persist real queries via \`@AppStorage("v3_recent_searches")\` holding a JSON-encoded [String] (cap ~6, dedupe, most-recent-first). Append the trimmed query on submit (.onSubmit of the search field). Show the "Recent searches" section ONLY when the stored list is non-empty; add a small "Clear" affordance. Give each recent row an \`.accessibilityIdentifier("v3-recent-\\(index)")\`. IMPORTANT: the main QA flow asserts "Recent searches" is visible after navigating to Find as a brand-new user — so ALSO seed nothing by default. (The orchestrator will update that flow to perform a search first; just make the section conditional and note it in risks.)
2. Result rows: add \`.accessibilityIdentifier("v3-search-result-\\(item.id)")\` to each result Button (resultRow call site).
3. \`ancestryString(for:)\` is O(n^2) (allItems.first per hop, per row). Build a \`byId\` dict once and walk parents via O(1) lookups.
4. \`resultRow\` decodes a full image synchronously — convert to \`V3Thumbnail.load(path:maxPixelSize: 140)\` with @State (extract a row subview so each owns its @State). Keep the letter fallback.
5. Extract the pure filter into a testable free function, e.g. \`func v3FilterItems(_ items: [ImageItem], query: String) -> [ImageItem]\` at file scope, and have \`results\` call it. (A unit test will import it.)`,
  },
  {
    label: 'feat-room',
    files: [`${ROOT}/Screens/V3RoomScreen.swift`],
    task: `FEATURES + perf in V3RoomScreen.swift ONLY. PRESERVE the earlier delete-pop edits: the onDeleted closure on the V3DetailSheet sheet, the \`.onChange(of: matches.isEmpty)\` self-heal, and the not-found V3NavHeader+V3EmptyState branch. Do NOT revert them.
1. "Add a place" routes into the LEGACY v2 CreateChildScreen via \`Route.createChild(...)\` at TWO sites (the addPlaceBand button AND the empty-state V3EmptyState onAdd). Replace BOTH with \`path.append(Route.v3CreateSub(parentId: roomId, tempPhotoPath: nil, suggestedRect: nil, suggestedTitle: nil))\` so v3 owns its stack. Do NOT edit CreateChildScreen.
2. O(n^2): \`places\` filters allItems by parentId, and the grid does \`allItems.filter{ $0.parentId == place.id }\` per place. Build a \`childCounts\` dict once (\`Dictionary(grouping: allItems, by: \\.parentId).mapValues(\\.count)\`) and use it for each card's childCount.
3. Add \`V3Haptics.impact(.light)\` when "Add a place" is tapped.`,
  },
  {
    label: 'vision-autolabel',
    files: [`${ROOT}/Vision/V3VisionService.swift`, `${ROOT}/Vision/V3CoreMLDetector.swift`],
    task: `VISION in V3VisionService.swift + V3CoreMLDetector.swift ONLY.
1. ADD the auto-label entry point with EXACTLY this signature (the create-sub screen calls it):
   \`static func suggestName(imagePath: String) async -> String?\`
   It should pick the single most prominent object label for the photo: run the existing detector/classifier pipeline (reuse \`detect(imagePath:)\` or the internal fusedLabels/classifyRegion helpers), choose the highest-confidence non-generic label, prettify it (VisionClassificationService.prettifyIdentifier) and Capitalize it for use as a place name. Return nil if nothing confident. Keep it cheap (you may classify the whole downsampled image rather than full detection if that is materially faster). Must run on-device, work in the Simulator (Apple Vision path; ML Kit stays behind \`#if !targetEnvironment(simulator)\`).
2. PERF: \`detect\`/\`classifyRegion\`/identify re-load + full-decode the original bitmap on EVERY call (every SpatialTap re-decodes). Add a tiny in-service cache of the last loaded working image keyed by imagePath (e.g. a static holding the path + a downsampled ~1024px UIImage) so repeated identify taps on the same photo reuse it instead of decoding each time. Keep correctness (invalidate when path changes).
Do NOT break the existing public API (detect, classifyRegion) — only ADD suggestName and the internal cache.`,
  },
  {
    label: 'feat-settings-paywall',
    files: [`${ROOT}/Screens/V3SettingsScreen.swift`],
    task: `FEATURES in V3SettingsScreen.swift ONLY.
1. The Pro "Try free for 7 days" button (id v3-settings-upgrade) has an empty action \`{}\`. Wire it to present the NEW \`V3PaywallSheet\` (already created at V3/Sheets/V3PaywallSheet.swift; init is \`V3PaywallSheet(palette: palette, onStartTrial: {...})\`). Add \`@State private var showPaywall = false\`, set it true on tap, and add a \`.sheet(isPresented: $showPaywall) { V3PaywallSheet(palette: palette).environment(\\.v3Palette, palette) }\`. Fire \`V3Haptics.impact(.light)\` on tap.
2. Add \`V3Haptics.selection()\` when the search toggle (v3-settings-search-toggle) flips, and \`V3Haptics.warning()\`/sign-out feedback is optional. Do NOT change the @State-mirror commit pattern (snapshot/onChange) — it is required to avoid toggle snap-back.
Everything else in this file is already correct (it is the native v3 settings screen) — do not churn it.`,
  },
  {
    label: 'feat-rootview',
    files: [`${ROOT}/V3RootView.swift`],
    task: `FEATURES in V3RootView.swift ONLY (this file also contains struct V3YouScreen). PRESERVE the existing onOpenSearch: { tab = .find } wiring on V3HomeScreen — do NOT remove it.
1. \`routeToCreateSub\` does \`tab = .home; homePath.append(...)\` onto a possibly-stale stack. Change to reset first: \`tab = .home; homePath = NavigationPath(); homePath.append(Route.v3CreateSub(...))\`.
2. Tab re-tap-to-root: intercept tab selection so tapping the already-selected tab clears that tab's NavigationPath (use a custom Binding wrapping \`tab\` that, when set to the current value, empties the matching path). Keep it simple and safe.
3. V3YouScreen hardcodes \`Text("Good evening")\` — replace with \`Text(V3Greeting.phrase())\` (new shared helper).
4. Capture FAB padding (\`.padding(.bottom, 6)\` over the TabView in a bottomTrailing ZStack) overlaps the tab bar/home indicator on some devices. Make it robust: read the bottom safe-area inset and offset the FAB above the ~49pt tab bar + indicator (e.g. via safeAreaInset semantics or a GeometryReader inset). Keep it beside the tab bar.
5. Wire the on-disk orphan sweep that currently has NO call site: in the root \`.task\` (after seeding), call \`try? await repo.removeOrphanedImages()\` once. (removeOrphanedImages is an existing ImageRepository method — just CALL it; do not edit the repository.)
Add \`V3Haptics.impact(.medium)\` on the capture FAB tap if not already present.`,
  },
  {
    label: 'feat-sheets',
    files: [`${ROOT}/Sheets/V3NewRoomSheet.swift`, `${ROOT}/Sheets/V3DetailSheet.swift`],
    task: `POLISH in V3NewRoomSheet.swift + V3DetailSheet.swift ONLY. In V3DetailSheet PRESERVE the existing onDeleted closure/param, the V3Haptics.warning() on delete, and the DispatchQueue.main.async pop — do NOT remove them.
V3NewRoomSheet:
1. Keyboard can occlude the name field; bind \`@FocusState private var nameFocused: Bool\` to the name TextField and, when it focuses, ensure the field is reachable (the sheet already allows [.medium,.large] — bump to .large on focus, or wrap the ScrollView content in a ScrollViewReader and scrollTo the name field on focus).
2. Fire \`V3Haptics.success()\` right before dismiss in \`create()\` on success.
3. Fix the stale comment (lines ~191-194) that claims the chosen color "isn't applied" — it IS applied via V3Theme.hue(for: item). Correct the comment to reflect reality.
V3DetailSheet:
4. The Save button is text-only; show an inline ProgressView while \`saving\` and fire \`V3Haptics.success()\` before dismiss on save success. The notes TextEditor has no placeholder — overlay a faint placeholder Text when notes is empty. Add \`V3Haptics.selection()\` when the updated-toggle row is tapped.`,
  },
  {
    label: 'polish-typo-switch',
    files: [`${ROOT}/Theme/V3Typography.swift`, `${ROOT}/Components/V3Switch.swift`],
    task: `POLISH in V3Typography.swift + V3Switch.swift ONLY.
V3Switch:
1. Add \`.accessibilityValue(isOn ? "on" : "off")\` (and an \`.accessibilityIdentifier\` is set by callers) so Maestro can assert the boolean state. Keep the visual unchanged.
V3Typography (V3Font):
2. Fixed \`.font(.system(size: N))\` everywhere ignores Dynamic Type. Make V3Font's headline/display/body helpers route through \`Font.system(size:..., relativeTo: <a text style>)\` (e.g. headline→.title2/.title, body→.body) so they scale with Dynamic Type, OR provide a \`.dynamicTypeSize(...DynamicTypeSize.accessibility1)\` clamp helper. Keep the serif (Instrument Serif fallback) behavior.
3. Delete the dead no-op \`func fallback(_:) -> Font { self }\` that discards its argument (or make it actually apply the argument).
Be conservative: keep the public function names/signatures used across many screens stable (other agents' files call V3Font.headline(_:italic:), V3Font.display(_:italic:), etc.) — change the IMPLEMENTATION, not the call signatures.`,
  },
  {
    label: 'qa-flows',
    files: ['/Users/matthewcromaz/Documents/forgetmenotev3/ios/qa/maestro/flows/ (new files only)'],
    task: `Create NEW Maestro flow files under /Users/matthewcromaz/Documents/forgetmenotev3/ios/qa/maestro/flows/ ONLY. Do NOT edit the existing v3_full_qa.yaml. appId is com.matthewcromaz.forgetmenote.v3.dev. All flows must sign in first via the demo account fast-path: launch, tap id v3-signin-demo (autofills demo@fmn.app/forget), tap id v3-signin-submit — OR sign up like v3_full_qa does (reveal password via v3-signup-toggle-password, type, tap v3-keyboard-done, submit). Prefer the demo path for brevity. Known ids: v3-home-new-room, v3-newroom-name, v3-newroom-create, v3-newroom-hue-2, v3-capture-fab, v3-create-sub-crop-toggle, v3-cropbox-handle-0..3, v3-create-sub-name, v3-create-sub-save, v3-space-menu, v3-detail-delete, v3-space-detect, v3-search-input, v3-settings-search-toggle, v3-detail-updated-toggle, v3-nav-back. Create these files:
- v3_create_room.yaml: home → tap v3-home-new-room → tap v3-newroom-hue-2 → tap v3-newroom-name, inputText "Garage" → dismiss keyboard (tap a neutral point near top) → tap v3-newroom-create → assertVisible "Garage".
- v3_delete_return.yaml: open a seeded room/space (tap a room tile, then a place) → tap v3-space-menu → tap v3-detail-delete → on the alert tap "Delete" → assert you are back on the parent (assertVisible the parent grid marker, e.g. "Places in this room" or the room name) and NOT "Not found"/"Item not found". This guards the #1 delete-strand fix.
- v3_search.yaml: tap Find tab (point 50%,96%) → tap v3-search-input, inputText a likely-seeded name (e.g. "My home" or a default room name) → assert a match row appears.
- v3_settings_toggle.yaml: You tab (point 70%,96%) → tap "Settings" → tap v3-settings-search-toggle twice → assert it remains usable (and if V3Switch exposes accessibilityValue, assert on/off).
Each flow must start with: clearState, launchApp { clearKeychain: true }. Add extendedWaitUntil for the first element with a 6000ms timeout. Use waitForAnimationToEnd between navigations. Keep flows SHORT (they run on a slow sim). These are config files only — they do not affect the app build.`,
  },
  {
    label: 'unit-tests',
    files: ['/Users/matthewcromaz/Documents/forgetmenotev3/ios/ForgetMeNoteTests/ (new files only)'],
    task: `Create NEW XCTest files under /Users/matthewcromaz/Documents/forgetmenotev3/ios/ForgetMeNoteTests/ ONLY (additive; do not edit existing tests unless needed to compile). The test target is ForgetMeNoteTests, host app ForgetMeNote. Use \`@testable import ForgetMeNote\`. Write:
1. AuthStoreTests: exercise V3/Auth/AuthStore (read it first — it is at ForgetMeNote/V3/Auth/AuthStore.swift). Use SwiftData \`ModelConfiguration(isStoredInMemoryOnly: true)\` to build an in-memory ModelContainer for User. Cases: signUp inserts a user + sets currentUser; duplicate email signUp fails; signIn wrong password → the documented "Wrong password" error; signIn unknown email → "No account" style error; signOut clears currentUser. Match AuthStore's ACTUAL method names/return shape (read the file — do not assume).
2. SearchFilterTests: test the pure \`v3FilterItems(_:query:)\` free function (being added to V3FindScreen.swift by another agent — function: \`func v3FilterItems(_ items: [ImageItem], query: String) -> [ImageItem]\`). If that symbol does not yet exist when you write, still write the test referencing it (it will compile after integration) and note the dependency in risks. Cases: empty query → empty; match by name (case-insensitive substring); match by tag; match by notes; no-match → empty.
3. CascadeDeleteTests: build an in-memory ImageRepository (ForgetMeNote/Repository/ImageRepository.swift — read its init + public delete/create API) and verify delete(itemId:strategy:.deleteAllChildren) removes a ROOT with nested children AND a NON-root subtree, leaving no dangling rows (query parentId). Use the repo's real public methods only.
Read each referenced source file before writing so the API matches exactly. Note any uncertain APIs in risks rather than guessing.`,
  },
]

phase('Fix')
const reports = await parallel(UNITS.map(u => () =>
  agent(`${u.task}\n\n${RULES}`, { label: u.label, phase: 'Fix', schema: REPORT_SCHEMA })
    .then(r => ({ unit: u.label, files: u.files, report: r }))
))

const landed = reports.filter(Boolean)
log(`Fix phase done: ${landed.length}/${UNITS.length} units reported.`)

// Adversarial verify: a fresh agent re-reads each unit's files and checks the
// claimed changes actually exist and look compilable (no build — static read).
phase('Verify')
const verdicts = await parallel(landed.map(u => () =>
  agent(`You are an adversarial reviewer. Unit "${u.unit}" claims these changes:\n${JSON.stringify(u.report.changes)}\nFiles: ${JSON.stringify(u.files)}.\nRead the CURRENT contents of those files and verify: (a) each claimed change is actually present, (b) it is syntactically plausible Swift that will compile (check for obvious issues: undeclared symbols, wrong arg labels, missing imports, removed accessibility ids, reverted P0 logic), (c) no other-agent file was touched. Report findings.`,
    { label: `verify:${u.unit}`, phase: 'Verify', schema: {
      type: 'object', additionalProperties: false,
      required: ['unit', 'present', 'compileConcerns', 'regressions'],
      properties: {
        unit: { type: 'string' },
        present: { type: 'boolean', description: 'all claimed changes actually present' },
        compileConcerns: { type: 'array', items: { type: 'string' } },
        regressions: { type: 'array', items: { type: 'string' }, description: 'removed ids / reverted P0 logic / cross-file edits' },
      },
    } })
))

return {
  units: landed.map(u => ({ unit: u.unit, files: u.files, report: u.report })),
  verdicts: verdicts.filter(Boolean),
}
