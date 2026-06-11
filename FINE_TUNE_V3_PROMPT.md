# Fine-tune & polish ForgetMeNote v3 (iOS) — end-to-end, zero-lag, QA-green

## 1. Mission

Fully fine-tune and polish **ForgetMeNote v3** so everything works correctly, nothing is perceptibly laggy, and the whole app is QA-tested repeatedly until green. **Before touching anything, read `/Users/matthewcromaz/Documents/forgetmenotev3/CLAUDE.md` end-to-end** — it tells you which of the three apps in this repo is yours, the exact build/install/QA commands, and the regression history. This is a large, multi-front job — do **not** run it as one linear pass. Drive it with **dynamic Workflows and agent teams at ultracode effort**: decompose the work into independent fixable units, fan them out to worktree-isolated agents, then run an adversarial verify + build + Maestro loop. Loop until the Definition of Done in section 6 is met **with evidence**.

## 2. Ground rules / guardrails (do NOT violate)

- **Work ONLY in `ios/ForgetMeNote/V3/*`** (plus additive `ForgetMeNoteTests/*`, `qa/maestro/flows/*`, and `project.yml`/`Podfile` when a config change is genuinely required). You may *reuse* the shared `Views/Screens/SettingsScreen` by calling it, but do **NOT** edit legacy `Views/*` or `ML/*` — they are shared with v2 and v4, and edits ripple into other apps. Almost every fix below is achievable inside `V3/*`; if you think you truly must edit shared code, stop and reconsider, then keep it strictly additive (new method, or enum case with defaulted associated values) and confirm v2 still compiles.
- **NEVER touch `ForgetMeNote/V4/*`** — that is Codex's separate app. Read-only, for inspiration at most.
- **This tree is NOT a git repo.** There are no commits. `git log` will not work. Verify your work **by building**, not by git. Use `ls -lt` to see recent activity.
- **The v3 target/scheme is `ForgetMeNote`**, bundle id `com.matthewcromaz.forgetmenote.v3.dev`, root view `V3RootView`. The `ForgetMeNoteV4` scheme is Codex's — never build or modify it.
- **Toggle binding rule:** any `Toggle`/switch bound to a SwiftData `@Model` property MUST use the **@State mirror pattern** (local `@State` mirror, write through on change). There is a documented snap-back regression. `V3Switch` is the v3 control; verify the on→off→on cycle **on hardware**.
- **All Maestro accessibility ids must be prefixed `v3-`** and follow the existing convention (`v3-nav-back`, `v3-search-input`, `v3-newroom-create`, etc.).
- **Project config:** new Info.plist keys go in `project.yml` under `info.properties` — do NOT hand-edit `Info.plist` (xcodegen regenerates it). New pods go in `Podfile`; wrap device-only pods (ML Kit) in the `unless ENV['SKIP_MLKIT']` block.
- **ML guard:** ML Kit code paths must be guarded `#if !targetEnvironment(simulator)`. Apple Vision and CoreML work in the Simulator.
- **Build order matters:** `xcodegen generate` → `pod install` → `xcodebuild` for device. For Simulator builds you MUST run `SKIP_MLKIT=1 pod install` first (ML Kit has no arm64-Simulator slice), then restore with a plain `pod install` afterward.

## 3. The #1 bug — fix this FIRST

**Deleting a space/place strands the user on a dead detail screen.**

- **Where:** `ios/ForgetMeNote/V3/Sheets/V3DetailSheet.swift` `confirmDeleteAction()` (lines ~270–276) — presented from `V3SpaceScreen.swift` (~118–121) and `V3RoomScreen.swift` (~56–59).
- **Root cause (verified):** `confirmDeleteAction()` runs `try? await repo.delete(itemId: id, strategy: .deleteAllChildren)` then `await MainActor.run { dismiss() }` — `dismiss()` dismisses only the **sheet**, not the underlying `NavigationStack` entry. After the model row is gone, the parent screen's `@Query` (`matches.first`) becomes `nil`, so `V3SpaceScreen` collapses to its bare `"Item not found"` fallback (~line 110) and `V3RoomScreen` to `"Room not found"` (~line 47). Those fallbacks live in the `else` branch with **no `V3NavHeader` and no back button** (and `.toolbar(.hidden, for: .navigationBar)` suppresses the system back), so the user is stranded and must tap the Home tab to escape.
- **Expected behavior:** keep the existing destructive confirmation alert. After the user confirms and the delete succeeds, the app must **automatically pop back to the parent room/grid** — the deleted item's detail screen must never remain on the stack.
- **Fix direction (all inside `V3/*`):** give `V3DetailSheet` an `onDeleted: () -> Void` closure; call it on the MainActor after `repo.delete` succeeds. In `V3SpaceScreen`/`V3RoomScreen`, pass an `onDeleted` that pops: `if !path.isEmpty { path.removeLast() } else { dismiss() }`. Because dismissing the sheet and popping in the same runloop can race in SwiftUI, dispatch the `path.removeLast()` one runloop after `dismiss()` (`DispatchQueue.main.async`) or drive it from the parent via a `@State` flag the sheet sets. **Belt-and-suspenders:** also add `.onChange(of: matches.isEmpty) { if $0 && !path.isEmpty { path.removeLast() } }` so any stale path entry pointing at a removed id self-heals. And give the not-found `else` branch a real `V3NavHeader` (working back) + `V3EmptyState(.generic)` so it is never a dead end even if a pop is missed.

## 4. Prioritized work plan

Every item below cites a real `file:line`. Lines are approximate and may have drifted — **confirm in-file before editing.** Do not drop any item.

### P0 — Critical / broken (do these first, verify green before P1/P2 start)

1. **Delete → strand bug** (section 3). `V3DetailSheet.swift:270–276`, `V3SpaceScreen.swift:109–121`, `V3RoomScreen.swift:46–59`. Auto-pop on delete + give not-found branches a back affordance.
2. **Maestro suite is RED at sign-up — keyboard occludes submit.** `ios/qa/maestro/flows/v3_full_qa.yaml:47–51` (inputText into `v3-signup-password` at line 48, then `tapOn id: "v3-signup-submit"` at line 51). On the iOS 26.5 Sim the keyboard covers the submit button (`V3SignUpScreen` is a long ScrollView: name→email→password→strength bars→error slot→Create account→terms→divider→2 social buttons→footer). Maestro auto-scroll cannot reveal an element behind the keyboard, and `hideKeyboard` is unreliable on this beta. **Fix:** in the flow, after the password `inputText`, dismiss the keyboard by tapping a neutral non-input element (e.g. `tapOn point: "50%,30%"` or the headline), then `assertVisible id: "v3-signup-submit"` before `tapOn`. Belt-and-suspenders in app code: wrap `V3SignUpScreen` (`V3/Screens/V3SignUpScreen.swift:37–167`) form in a `ScrollViewReader` and `scrollTo` the submit button on field submit, and/or add a keyboard toolbar Done item with id `v3-keyboard-done`. (`V3SignUpScreen` is in `V3/*` — editable.)
3. **Maestro stale `Back` id — second guaranteed failure.** `v3_full_qa.yaml:100–101` does `tapOn id: "Back"` after Settings, but `V3SettingsScreen`'s back button (via `V3NavHeader.swift:24–25`) has identifier `v3-nav-back` (the *label* is "Back" but Maestro `tapOn id` matches the **id**, not the label). **Fix:** change the flow step to `tapOn id: "v3-nav-back"`. No app change.

### P1 — Performance/lag (high) + remaining high-severity correctness

**Performance — the lag is in the view layer (downsampler, `@ModelActor` repo, and Vision pipeline themselves are correct):**

4. **`V3SpaceScreen` re-decodes the full-res hero JPEG every body pass and once per sub-card.** `V3/Screens/V3SpaceScreen.swift:42` (computed `image: UIImage? { v3LoadImage(filePath:) }`), consumed at `:129` (heroPhoto) and `:377` (per `V3SubScanCard`). An N-sub-space view does N+1 synchronous full-res decodes per render, on every `@State` change. **Fix:** replace the computed property with `@State private var image: UIImage?` populated in `.task(id: item?.filePath)` via `await Task.detached { V3ImageDownsampler.downsample(path:) }` (exists, off-main). Pass that one cached image to heroPhoto and to every `V3SubScanCard` via its existing `parentImage:` param so sub-cards never decode.
5. **Grid/carousel/list cells decode full-res JPEGs synchronously in body.** `V3/Components/V3PlaceCard.swift:23–25,83`; `V3/Screens/V3HomeScreen.swift:143`; `V3/Screens/V3FindScreen.swift:175`; `V3/Components/V3RoomTile.swift:65` (RoomTile decodes 3 full images for 26pt avatars; Find re-decodes every result row on every keystroke). **Fix:** add a small shared v3 thumbnail cache (NSCache keyed by `filePath + targetPixelSize`) and a helper `V3Thumbnail.load(path:maxPixelSize:) async -> UIImage?` going through `V3ImageDownsampler` off-main; cards hold `@State var thumb` filled in `.task(id: filePath)`. Optionally generate a real thumbnail file at save time — `ImageItem.thumbnail` is currently just a copy of `filePath` (`ImageRepository.saveImage:172`); **`ImageRepository` is shared** — keep any save-path change additive/behavioral and confirm v2 compiles, otherwise keep the thumbnail work entirely in `V3/*`.
6. **Crop box re-lays-out the entire full-image GeometryReader every drag tick; no rasterization.** `V3/Screens/V3CreateSubScreen.swift:119–157`; `V3/Components/V3CropBox.swift:37–89`. CLAUDE.md claims `.drawingGroup()` is applied for no-lag cropping, but **`grep -rn drawingGroup V3/` returns ZERO hits — it was never added.** The bound `rect` mutates 60×/sec and `photoArea` (image + four dimming Rectangles) re-lays-out each tick. **Fix:** apply `.drawingGroup()` to the static image layer so it rasterizes once; keep only the crop box + dimming in the live layer; ensure `displayImage` is the already-downsampled image (it is, via `loadDisplayImage`). Optionally throttle rect writes.
7. **Detection overlay decodes mask PNGs in body and renders glow/shadow without rasterization.** `V3/Components/V3DetectionOverlay.swift:23,68–71` (consumed `V3SpaceScreen.swift:211–223`). `maskImage(det.maskPNGData)` calls `UIImage(data:)` inside the `ForEach` body every render/frame; each mask is drawn full-photo-size with `.shadow` (offscreen blur). **Fix:** decode masks once when detections arrive (store a `[UUID: UIImage]` `@State` map built in `runDetection`), and wrap each silhouette in `.drawingGroup()`. Cap simultaneously-shadowed masks if needed.
8. **O(n²) ancestry/child scans inside body.** `V3/Screens/V3FindScreen.swift:224–232` (ancestry per result row); `V3SpaceScreen.swift:52–62,402`; `V3RoomScreen.swift:218`; `V3HomeScreen.swift:197–200,208–209`. Each calls `allItems.first(where:)` / `allItems.filter(parentId==)` per visible row → O(rows × allItems), ×depth for ancestry. **Fix:** build lookup dicts once per render — `let byId = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id,$0) })` and `let childCounts = Dictionary(grouping: allItems, by: \.parentId).mapValues(\.count)` — and compute from O(1) maps.
9. **Synchronous full-res decode at the start of every detect/identify call.** `V3/Vision/V3VisionService.swift:20,67`; `V3/Vision/V3CoreMLDetector.swift:25–49`. `identifyAt` fires on **every** SpatialTap and re-loads/decodes the full bitmap each time. **Fix:** cache the loaded original (or a 1024px working copy) for the active space and reuse across detect + repeated identify taps; CoreML can run downsampled (request is `.scaleFill`), keep full res only when actually generating masks.

**Data integrity (high):**

10. **Recursive cascade trusts `childIds`, leaving `parentId`-only children dangling + leaking photo files.** `Repository/ImageRepository.swift:360–377` (`deleteRecursive`). UI finds children by `parentId` (`V3RoomScreen.places`, `V3SpaceScreen.subs`) but delete walks `childIds` — any child reachable by `parentId` but missing from `childIds` is skipped and its on-disk `.jpg` leaks. **Fix:** make `deleteRecursive` authoritative on `parentId` — fetch `children(of: item.id)` (existing repo method querying `parentId`) and recurse over those. **`ImageRepository` is shared with v2** — keep the change additive/behavioral on the v3 delete path and verify v2 still compiles; if you cannot safely touch it, route v3 delete through a v3-owned wrapper. Add a unit test for both root and non-root cascade.

**UX/feature (high) — all inside `V3/*`:**

11. **No haptics anywhere in V3** (grep for `sensoryFeedback`/`UIImpactFeedback` → zero hits). **Fix:** add a tiny `V3Haptics` helper under `V3/` and wire iOS 17 `.sensoryFeedback`: `.impact` on `V3CaptureFAB` tap and crop-handle drag-start (`V3CropBox` dragStart latch); `.success` after a successful save in `V3CreateSubScreen.save` / `V3DetailSheet.save` / `V3NewRoomSheet.create`; `.warning`/`.impact(.heavy)` on delete confirm; `.selection` on the detail updated-toggle and `V3SpaceScreen` view-mode switcher; `.impact(.light)` on detection select.
12. **`V3RoomScreen` "Add a place" routes into the LEGACY v2 `CreateChildScreen`.** `V3/Screens/V3RoomScreen.swift:152` and `:203` push `Route.createChild` → v2 Material-3 screen (no `v3-` ids, jarring style, violates "v3 owns its stack"). `V3SpaceScreen` correctly uses `Route.v3CreateSub`. **Fix:** replace both call sites with `path.append(Route.v3CreateSub(parentId: roomId, tempPhotoPath: nil, suggestedRect: nil, suggestedTitle: nil))`. Do NOT edit `CreateChildScreen`.
13. **Home header search button is a dead no-op.** `V3/Screens/V3HomeScreen.swift:68–80` — action body is just `// Search route handled by parent tab switch`; `V3HomeScreen` has no access to the parent `tab` binding. **Fix:** add `var onOpenSearch: () -> Void`, invoke it from the button, and in `V3RootView`'s signed-in body pass `onOpenSearch: { tab = .find }`. Add `.accessibilityIdentifier("v3-home-search")`.
14. **Find "Recent searches" is hardcoded fake data.** `V3/Screens/V3FindScreen.swift:120–138` iterates literal `["lightning cable", "#christmas", "bay leaves"]`. Every user (even brand-new) sees searches they never made. **Fix:** persist real recent queries via `@AppStorage("v3_recent_searches")` JSON array (cap ~5–6, dedupe, append on submit); show the section only when non-empty; add a clear affordance and `accessibilityIdentifier` on the rows so they are driveable.

### P2 — Polish + feature gaps + remaining QA coverage

**Navigation/data (medium/low):**

15. **Capture flow appends onto a possibly-stale `homePath`.** `V3/V3RootView.swift:211–216` (`routeToCreateSub`) does `tab = .home; homePath.append(...)` without resetting. **Fix:** `tab = .home; homePath = NavigationPath(); homePath.append(Route.v3CreateSub(...))` (or verify the post-save pop target is right for the deep-stack case).
16. **Tab switches never reset per-tab stacks.** `V3/V3RootView.swift:76–102`. Optional polish: add re-tap-to-root by intercepting tab selection (same tag tapped → clear that tab's path). At minimum, the delete/auto-pop fixes must prevent stale routes surviving tab switches.
17. **Reparent strategy orphans children when the deleted node is a root.** `Repository/ImageRepository.swift:379–401` (`deleteAndReparent`). Currently unused by v3 (only `.deleteAllChildren` is called) — latent. If you wire a "keep contents" option, handle the root case and add unit tests; otherwise leave an explicit code note.
18. **On-disk photo-file leak sweep is never called.** `ImageRepository.swift:298–314` (`removeOrphanedImages`), `:319–327` (`orphanFilesOnDisk`) exist but have no call site in `V3/*`. **Fix:** call `removeOrphanedImages()` once on `V3RootView.task` after seeding, or add a "Free up space" row in `V3SettingsScreen`. (Calling an existing shared method is fine; don't edit it.)
19. **Room color saved but a stale comment claims otherwise.** `V3/Sheets/V3NewRoomSheet.swift:191–194` comment says the chosen color isn't applied, but `V3Theme.hue(for item:)` does read `roomBackgroundColor/roomTextColor`. Verify `V3RoomTile`/`V3HomeScreen` call the `hue(for item:)` overload (not `hue(for: id)`); fix the comment.

**UI/UX polish (medium/low):**

20. **No spacing/radius design tokens.** `V3/Theme/V3Theme.swift` ships colors only; gutters vary 22 vs 16, radii sprawl 8–32. **Fix:** add `enum V3Spacing` and `enum V3Radius` under `V3/Theme`, migrate hardcoded values screen-by-screen, and pick one canonical gutter for the Space/CreateSub photo containers so hero photos align with their headers.
21. **`V3Font` ignores Dynamic Type; fixed sizes + fixed frame heights clip at large text.** `V3/Theme/V3Typography.swift:10–27` (and pervasive `.font(.system(size: N))`). Also `func fallback(_:) -> Font { self }` is dead code that discards its argument. **Fix:** route sizes through `relativeTo:` text styles or clamp via `.dynamicTypeSize(...DynamicTypeSize.accessibility1)`, switch fixed `.frame(height:)` controls to `.frame(minHeight:)`, and either delete the no-op `fallback` extension or actually bundle Instrument Serif (drop `InstrumentSerif-Regular.otf`/`-Italic.otf` into `ForgetMeNote/Fonts/` and add `UIAppFonts` to `project.yml` `info.properties` — do NOT hand-edit Info.plist).
22. **Capture FAB bottom-padding overlaps the tab bar / home indicator.** `V3/V3RootView.swift:108–118` uses `.padding(.bottom, 6)` over a TabView in a bottomTrailing ZStack. **Fix:** anchor via `.safeAreaInset` semantics or read the bottom safe-area inset and offset above the ~49pt tab bar + indicator. Confirm on a home-indicator device.
23. **Detection "Scan again" can re-fire / apply stale runs.** `V3/Screens/V3SpaceScreen.swift:528–543` (`runDetection`) has no generation token, unlike `identifyAt` (`identifyToken` at `:573,584`). **Fix:** add a `detectToken` Int, increment per run, capture locally, bail in the completion if it changed; keep `.disabled(isDetecting)` on the "Scan again" branch.
24. **Detection mask uses `scaledToFill` while boxes use `displayRect` — misalignment on non-4:5 photos.** `V3/Components/V3DetectionOverlay.swift:23–36` vs `:19,46–47`. **Fix:** make the mask use the identical transform as the photo (same `displayRect` math) so mask, box, and label share one coordinate mapping; validate against a square and a 3:4 photo and extend the geometry unit tests.
25. **No pressed/hover feedback on tab items, switcher, most cards.** `V3/V3RootView.swift:84–101`, `V3SpaceScreen.swift:455–465`, and most `.buttonStyle(.plain)` usages. **Fix:** add a shared `V3PressableButtonStyle` (scale ~0.97 + opacity 0.9 on press, quick spring) and apply to cards/switcher/circle buttons; pair with the `.selection` haptic.
26. **Save/create buttons show "Saving…" text only — no spinner, possible nav race.** `V3/Screens/V3CreateSubScreen.swift:57–64`; `V3/Sheets/V3DetailSheet.swift:91–95`. **Fix:** show an inline `ProgressView` (or reuse `V3PrimaryButton`'s `loading` state at `V3PrimaryButton.swift:14–23`), keep `.disabled(saving)`, fire `.success` haptic before dismiss.
27. **New Room name field occluded by keyboard; TextEditor has no placeholder.** `V3/Sheets/V3NewRoomSheet.swift:31–48,159–179`; `V3DetailSheet.swift:159`. **Fix:** present at `.large` when the field focuses (bind `@FocusState`, bump detent) or move the field above the hue grid + `ScrollViewReader` scroll-to-focus; overlay a placeholder `Text` when notes are empty.
28. **Item/Room-not-found and Home zero-rooms states are bare/unstyled.** `V3SpaceScreen.swift:110–112`, `V3RoomScreen.swift:47–49`, `V3HomeScreen.swift:42–51,204–235`. Render `V3NavHeader` + `V3EmptyState` recovery in not-found branches (overlaps the section-3 fix); add a real "Create your first room" empty state when `rooms.isEmpty`; fix the dead `rooms.count` pluralization ternary at `V3HomeScreen.swift:106` (both branches emit ".").

**Feature completeness (medium/low):**

29. **Pro "Try free for 7 days" is an empty closure.** `V3/Screens/V3SettingsScreen.swift:137`. **Fix:** at minimum present a placeholder `V3/Sheets/V3PaywallSheet` so the tap has feedback. Do NOT reuse the legacy `StubPaywallView` (it's in read-only `Views/*`) — build a v3-native shell.
30. **Apple/Google social sign-in are demo stubs.** `V3/Screens/V3SignInScreen.swift:149–157`, `V3SignUpScreen.swift:190–195` (`stubSocial()`). Acceptable for the demo, but label/gate them clearly or hide Google until a provider is integrated. (Email/password `AuthStore` is real — leave it.) Changes stay in `V3/Auth/*` and `V3/Screens/*`.
31. **You-tab greeting hardcoded "Good evening".** `V3/V3RootView.swift:278`. **Fix:** extract `V3HomeScreen`'s time-of-day greeting into a shared `V3/` helper and use it in both `V3YouScreen` and `V3HomeScreen`.
32. **Stale CLAUDE.md deferred-gaps table.** New-room button, YOLO CoreML detector (`YOLOv3Tiny.mlmodel` is present and wired via `V3CoreMLDetector`→`V3VisionService`), and room-color persistence are all **DONE**. After your work lands, update CLAUDE.md so only genuinely-open items remain (Instrument Serif bundling if you don't do it, RevenueCat IAP, drag-to-reorder, Android import).

**QA coverage (add these flows + unit tests):**

33. **Create-room flow.** New `qa/maestro/flows/v3_create_room.yaml` (or extend `v3_full_qa`): `tapOn id v3-home-new-room` → `v3-newroom-hue-2` → `v3-newroom-name` inputText "Garage" → dismiss keyboard → `v3-newroom-create` → assert "Garage" in grid. All ids already exist.
34. **Create-sub-space / crop-box flow.** Seed a room, `tapOn id v3-capture-fab`, use the no-camera Sim fallback (Snap on Sim routes straight to `V3CreateSubScreen` per `V3RootView.swift:146–152`), `tapOn id v3-create-sub-crop-toggle`, drag a `v3-cropbox-handle-N`, `v3-create-sub-name` inputText, `v3-create-sub-save`, assert the new sub. Consider exposing the crop rect via `accessibilityValue` so the drag can be asserted.
35. **Delete + return navigation flow.** Open a space → `tapOn id v3-space-menu` → `v3-detail-delete` → `tapOn "Delete"` (alert) → **assert the parent room/grid shows, NOT "Item not found"** (this guards the section-3 fix).
36. **On-device detection flow.** Open a Space backed by the bundled DemoImage → `tapOn id v3-space-detect` → `extendedWaitUntil` that EITHER a `v3-detection-*` overlay appears OR "No objects found" shows; assert the button toggled to "Scan again" rather than a specific label (Vision-only on Sim is non-deterministic).
37. **Settings/detail toggle cycle.** Tap `v3-settings-search-toggle` and the `v3-detail-updated-toggle`, save/reopen, assert persistence. Add `accessibilityValue("on"/"off")` to `V3Switch` (`V3/Components/V3Switch.swift`) so Maestro can assert the boolean.
38. **Search-results flow.** Seed an item → `tapOn id v3-search-input` inputText a known name → assert the match → tap the result → assert the Space opens. Add `accessibilityIdentifier("v3-search-result-\(item.id)")` to the result button (`V3FindScreen.swift:157–166`).
39. **Unit tests (additive in `ForgetMeNoteTests/`, allowed).** `AuthStore` (`V3/Auth/AuthStore.swift:24–58`): signUp inserts user + sets `currentUser`; duplicate email fails; wrong password → "Wrong password"; unknown email → "No account"; signOut clears session — use `ModelConfiguration(isStoredInMemoryOnly: true)`. Also extract `V3FindScreen`'s filter into a pure testable function under `V3/*` and test it; add the cascade-delete + ancestry tests referenced in item 10.

## 5. How to orchestrate it (dynamic Workflows + agent teams + ultracode + worktree isolation)

Run at **ultracode effort** and author **dynamic Workflows**, not a single linear edit pass:

- **Phase A — Audit & plan (fan-out, read-only).** Spin up read-only agents per dimension (Navigation, Performance, Data/CRUD, UI/UX, QA, Feature-completeness) to re-confirm every `file:line` above against the actual current source (lines may have drifted). Produce a dependency graph: which fixes are independent vs. which share files.
- **Phase B — Fix (worktree-isolated agents).** Give **one agent per independent fix unit, each in its own isolated worktree/workspace**, so concurrent edits don't collide. Group edits that touch the *same* file (e.g. all `V3SpaceScreen` changes; all `V3RootView` changes; all `V3DetailSheet`/delete-path changes) into a single agent to avoid merge conflicts. Sequence: **P0 first and verified green before P1/P2 start** — the Maestro fixes (P0 #2/#3) gate every downstream flow assertion, and the delete-pop fix (P0 #1) is asserted by QA flow #35.
- **Phase C — Adversarial verify.** For each landed fix, run a separate verifier agent that tries to break it: rebuild, re-read the changed code, and confirm the *symptom* is actually gone (not just "code looks right"). For perf fixes, confirm `.drawingGroup()` / async-decode / cache actually exist where claimed — CLAUDE.md previously *claimed* a `.drawingGroup()` that grep proves never existed; do not repeat that.
- **Phase D — Integrate & build.** Merge worktrees, then **build for device** (real iPhone) AND **run the full Maestro suite on the Simulator**. Reconcile pods correctly between device (full `pod install`) and Sim (`SKIP_MLKIT=1 pod install`).
- **Phase E — QA loop until green.** Run the suite, fix the next failure, rebuild, repeat. Then run it **2–3× more** to catch flakiness on the iOS 26.5 Sim. Prefer accessibility ids / point taps over text taps (text taps miss on this beta; tab-bar tap zones ~28% / 50% / 70% x at y≈96%). **Do not declare victory on a single green run.**

## 6. Definition of done / QA gate (strict — each with evidence)

Do not claim "done" until ALL of these hold:

- **Device build is clean** for the iPhone, app reinstalls and launches:
  ```bash
  cd ~/Documents/forgetmenotev3/ios
  xcodegen generate && pod install
  JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
    xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote -configuration Debug \
      -destination "id=E7A0CD3B-A97A-5548-A204-E046CA2ACAFD" -allowProvisioningUpdates build
  APP=~/Library/Developer/Xcode/DerivedData/ForgetMeNote-*/Build/Products/Debug-iphoneos/ForgetMeNote.app
  xcrun devicectl device install app --device E7A0CD3B-A97A-5548-A204-E046CA2ACAFD "$APP"
  xcrun devicectl device process launch --device E7A0CD3B-A97A-5548-A204-E046CA2ACAFD com.matthewcromaz.forgetmenote.v3.dev
  ```
- **The delete → back flow works on hardware:** delete a space/place from `V3DetailSheet`, confirm the alert, and you are automatically returned to the parent room/grid — never stranded on "Item not found."
- **No perceptible lag** opening a space, scrolling Home/Find/Room grids, dragging crop handles, or running/toggling detection — verified on the device with real photos (Sim-only verification has missed bugs before, e.g. the Toggle snap-back).
- **Toggles do not snap back** (verify the on→off→on cycle for `v3-detail-updated-toggle` and `v3-settings-search-toggle` on hardware).
- **The Maestro v3 suite passes 100%, run MULTIPLE times** (the sign-up/keyboard step AND the Settings back-id step are fixed; the new create-room / create-sub / delete-return / detection / search / toggle flows pass):
  ```bash
  cd ~/Documents/forgetmenotev3/ios
  SKIP_MLKIT=1 LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install
  JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
    xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote -configuration Debug \
      -destination "generic/platform=iOS Simulator" -allowProvisioningUpdates ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
  SIM_APP=~/Library/Developer/Xcode/DerivedData/ForgetMeNote-*/Build/Products/Debug-iphonesimulator/ForgetMeNote.app
  xcrun simctl install booted "$SIM_APP"
  JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
    maestro test qa/maestro/flows/v3_full_qa.yaml
  # then run each new flow, then re-run the whole set 2–3× to confirm no flakiness
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install   # restore ML Kit when done
  ```
- **Unit tests pass** (`ForgetMeNoteTests`, including the new AuthStore / search-filter / cascade-delete tests).
- **No legacy/V4 files were modified** — confirm all edits are under `ios/ForgetMeNote/V3/*` (plus additive `ForgetMeNoteTests/*`, `qa/maestro/flows/*`, and `project.yml`/`Podfile` if needed). `Views/*`, `ML/*`, `V4/*` untouched (read-only).

## 7. Reporting (never claim done without evidence)

- A bullet list of **every file you changed and what changed in it**, grouped by the P0/P1/P2 task it addresses, with absolute paths.
- The **tail of the device `xcodebuild` output** showing `** BUILD SUCCEEDED **`.
- The **Maestro run summary for each flow**, showing all steps passed, plus an explicit note of how many times you re-ran the suite and the per-run results.
- The **unit-test result** summary.
- An explicit **confirmation that no `Views/*`, `ML/*`, or `V4/*` files were touched**.
- Any item intentionally deferred (e.g. real RevenueCat IAP, real Sign in with Apple) and why, plus the updated CLAUDE.md deferred-gaps table.
- If anything is still red after your loop, say so plainly with the exact failing step and your hypothesis — do not paper over it.
