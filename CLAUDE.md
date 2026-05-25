# Hallways

A journaling iOS app where users create "pieces" (text or media) and organize them into titled "collections." Visual, scrapbook-style.

## Current State

- **Private-only** — no accounts, sharing, or public profiles.
- Two feed view modes: **minimalist** (vertical scroll, overlapping tilted cards, collections only) and **file** (2-column grid with standalones + collection stacks).
- **Create flow (upload media): complete.** Tap + on the feed → overlay with `upload media` / `writing` → PhotosPicker (multi-select, ordered, max 10) → editor screen → publish.
- **Edit flow: complete.** Three-dots in `MinimalistExpandedView` → editor (prefilled) → update / delete.
- **Drag-and-drop reorder + drag-to-delete:** Instagram-style real-time reorder in the editor carousel, drag-to-bottom for delete.
- **Image viewer:** TabView paging between pieces, pinch-zoom, swipe-down to dismiss, edge-swipe-back gesture in `MinimalistExpandedView`.
- **Splash:** OS launch screen + matching SwiftUI splash (both show the same cluster image + "means a lot you're here" tagline), then simple fade to feed.
- **Writing flow:** still a no-op button. Future work.

## Design System

### Fonts
- **Special Elite** (typewriter, `SpecialElite-Regular`) — primary UI text. Registered via `UIAppFonts` in `Info.plist` (not programmatically — that was removed because it's redundant and skips the launch storyboard).
- **Printvetica** (`PrintveticaRegular`) — used for CTA buttons in `CreateOverlay` and the date stamp in `MinimalistExpandedView`. Same registration mechanism.
- Helpers: `Font.specialElite(size:)` and `Font.printvetica(size:)` in `HallwaysTheme.swift`.

### Colors
- Background: `#FCFCFC`
- Text: `#121212`
- Overlay (file expanded bg): `#7A7A7A` at 55% + `.ultraThinMaterial`
- Card (file expanded): `#EFEFEF` at 80%
- Text-piece card: `#F5F0E8` (parchment)
- File expanded text: black (`HallwaysTheme.text`), not white
- **Delete state (red footer):** `#9B1515` (dragging, not yet hovering delete zone) / `#A11111` (hovering delete zone — "activated")
- **Date stamp (gray):** `#9F9F9F`

### Image rendering — `PieceCardView`
No corner radius, aspect ratio preserved (`.fit`), three sizing modes via optional `cardWidth`/`cardHeight`:
- Height-only (collection rows, file expanded) → `.frame(height:)`, natural width
- Width-only (minimalist expanded) → `.frame(width:)`, aspect-derived height; text uses 3:4 portrait
- Both (file grid) → `.frame(maxWidth:, maxHeight:)`
Loads via `ImageStorage.loadImage(named:)` — tries asset catalog first, falls back to `Documents/<filename>` for user-published photos.

### Layout constants (`HallwaysTheme.swift`)
- Minimalist view: collections only, leading 16pt, row spacing 72pt, collection row height 150pt
- Collection row tilt cycles `[-6°, 0°, +5°]` per index; vertical scatter ±10pt (even up, odd down)
- Collection row overlap: -20pt spacing; rightmost piece on top (`zIndex(Double(index))`)
- Minimalist expanded: content width = screen − 48pt. Landscape uses full width; portrait + text use 80%. Pieces centered via `.frame(maxWidth: .infinity)`.
- File grid: 2-column, collection stacks have rounded-rect border (`#E0E0E0`)

### Toggle (`ViewModeToggle`)
Black rounded rect (80×44), white square indicator (30×30, 3pt padding). Left = minimalist, right = file.

### Date stamp (`MinimalistExpandedView`)
Below the last photo in the expanded scroll. Printvetica 14pt, color `#9F9F9F`. Format: `yyyy.MM.dd   |   EEE HH:mm` (24h, locale pinned to `en_US_POSIX`, weekday uppercased). 8pt extra top padding (total 32pt from last photo via LazyVStack spacing).

## Architecture

### Data
- **SwiftData** via `ModelContainer` in `hallwaysApp.swift` (on-disk SQLite).
- `@Query` + `@Environment(\.modelContext)` for view-side access.
- `Piece` and `Collection` `@Model` classes (see below).

### Navigation
- `NavigationStack` in `FeedView`. `navigationDestination(for: Collection.self)` → `MinimalistExpandedView`.
- Overlays use ZStack + `.transition(.opacity)` + explicit `.zIndex` (always pin overlays with zIndex when using transitions, otherwise SwiftUI drops them mid-exit).

### Overlays in `FeedView` (root)
ZStack zIndex layers:
- 0: feed content (MinimalistView or FileView)
- (bottom bar HStack: plus + ViewModeToggle, padded)
- 1: `FileExpandedView` (when `selectedCollection` set)
- 2: `CreateOverlay` (when `showCreateOverlay && editingPhotos == nil`)
- 3: `CreateEditView` (when `editingPhotos != nil`)
- 4: `PublishCurtainView` (when `publishingPayload != nil`)

### Overlays in `MinimalistExpandedView`
ZStack:
- 0: vertical piece list (`ScrollViewReader` + `LazyVStack`, each card with `.id(piece.id)` for proxy scrolling)
- 1: `ImageViewerView` (when `selectedPiece != nil`)
- 2: `CreateEditView` in edit mode (when `showEditor`)
- 3: `PublishCurtainView` label "update" (when `updatePayload != nil`)
- 50: invisible 20pt left-edge strip with DragGesture for edge-swipe-back (only mounted when no overlay is up)
- Toolbar visibility: `chromeVisibility` hides the nav bar when viewer or editor is open.
- Tracks `lastInteractedID` to keep the exiting hero card layered above siblings during the matchedGeometry return.

### Create / edit flow
- `CreateOverlay` — white blur over feed, two CTAs (`upload media` / `writing`), chevron-down dismiss. Printvetica buttons.
- `CreateEditView` — shared by both modes via `EditorMode` enum (`.create` / `.edit(Collection)`):
  - Top bar: X (cancel, with "are you sure?" prompt) + title TextField (placeholder `[untitled collection]`, empty title is saved as empty) + trash (edit only, "delete this collection?" prompt).
  - Horizontal `LazyHStack` carousel with `.scrollPosition(id:)` for programmatic edge auto-scroll. Cards sized by aspect: landscape ≤ 300pt wide, portrait ≤ 360pt tall.
  - Trailing `+` button to add more (re-opens PhotosPicker, capped at 10 total).
  - Bottom publish footer using `PublishSemicircleShape` (curve facing up), pinned via `safeAreaInset(.bottom)` + `.ignoresSafeArea(.keyboard, edges: .bottom)` so keyboard doesn't collapse it.
  - `PhotoDraft` struct carries the in-flight image plus optional `existingPieceID`/`existingFilename` so edit-mode diffs can tell new from existing.
- `PublishCurtainView` — rise / hold / exit-up animation. Parameterized `label: String` ("publish" or "update"). Uses `max(geo.size.height, UIScreen.main.bounds.height)` for the curtain so a keyboard-shrunk safe area doesn't undersize it. Calls `onRiseComplete` mid-animation (parent persists + dismisses editor) and `onComplete` at end (parent drops the curtain overlay).
- `PublishSemicircleShape` — `Shape` with `topCurveHeight` + `bottomCurveHeight` animatable via `AnimatablePair`. Control points sit *outside* the rect so curves bulge outward (upward dome on top, downward dome on bottom).

### Persistence on save (FeedView / MinimalistExpandedView)
- **Create:** each `UIImage` → `ImageStorage.saveJPEG` → new `Piece` with that filename → new `Collection(title, pieces, sortOrder: minExistingSortOrder - 1)` → insert + save. New collection appears at top because `@Query(sort: \Collection.sortOrder)` ascends.
- **Update (edit):** diff `drafts` against `collection.pieces` by `existingPieceID`. Removed → `modelContext.delete(piece)` + `ImageStorage.deleteImage(named:)`. New → save JPEG + append `Piece`. Existing → just update `sortOrder = index`. Update `title` + `lastEditedAt`.
- **Delete collection:** delete every piece's JPEG, `modelContext.delete(collection)` (cascade), save, `dismiss()` to pop the nav back to the feed.

### Drag-and-drop in the editor carousel (Instagram-style)
**Use the UIKit gesture bridge — do not go back to SwiftUI's `LongPressGesture.sequenced(before:)`.** The SwiftUI version conflicts with `ScrollView` pan in ways that can't be reconciled (`simultaneousGesture` leaves stuck `draggingID`, `.gesture` blocks scroll entirely).

- `CardLongPressGesture: UIGestureRecognizerRepresentable` wraps `UILongPressGestureRecognizer` (`minimumPressDuration: 0.2`, `allowableMovement: 15`). UIKit natively handles "stillness for X seconds wins, movement wins for the scroll" — no manual coordination needed.
- On `.began` → lift card immediately (ghost appears at 85% scale, shadow). On `.changed` → real-time reorder via `reorderIfHovering`: find the *other* card whose frame contains the finger's X, swap dragged item into that slot with a spring. Cards slide aside to make room. Track `editorGlobalFrame` and convert `recognizer.location(in: nil)` (window coords) → editor coords with `toEditor(_:)`.
- Edge auto-scroll: only when finger is within 30pt of the carousel edge, advance `scrollAnchorID` to the dragged item's neighbor every 700ms (after 250ms warm-up). Real-time hover-reorder then targets the newly-revealed off-screen card.
- Delete zone: finger Y > `editorSize.height * 0.75` (bottom 25%). On drag start the footer turns `#9B1515` with label "delete". When the finger enters the delete zone ("activated"), the footer's colored shape (`fillColor` rect + `PublishSemicircleShape`) scales 1.6× with anchor `.bottom` AND the color shifts to `#A11111`. The "delete" `Text` lives outside the scaled ZStack so it stays at the original 16pt size and bottom-anchored position — only the dome grows around it. Use `easeOut(0.22)` for the scale animation — `spring` overshoots below 1.0 and reveals a gap on the screen sides.
- Header fades to opacity 0 while `draggingID != nil`.

### Image viewer (`ImageViewerView`)
- Takes `pieces: [Piece]` + `@Binding selectedPiece: Piece?`. Uses `TabView { ForEach } .tabViewStyle(.page(indexDisplayMode: .never))` for swipe-between pages.
- **`matchedGeometryEffect` only on the current page** (`if isCurrent { ... } else { content }`). Off-screen pages with the modifier try to match their LazyVStack source-card geometry and cause "scatter" glitches during paging.
- `MinimalistExpandedView` wraps `selectedPiece` in a binding that also updates `lastInteractedID` on swipe, so the hero exit always lands on whatever the user swiped to.
- `ScrollViewReader` in `MinimalistExpandedView` auto-scrolls the LazyVStack to keep the swiped piece on-screen, so the hero animation has a real target.
- Pinch via `UIPinchGestureRecognizer` (UIGestureRecognizerRepresentable) — anchor pinned at `.began`, finger drift offsets, springs back to 1.0 on release. Zoom state resets on page change.
- Dismiss: tap, or vertical swipe-down. The swipe-down uses `.simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { ... })` with strict `dy > 80 && dy > abs(dx) * 2` check so it doesn't fight TabView's horizontal swipe.

### Edge-swipe-back (`MinimalistExpandedView`)
20pt invisible strip on the left edge with `DragGesture(minimumDistance: 10).onEnded { ... }` calling `dismiss()` on `translation.width > 60 && horizontal-dominant`. Mounted only when no overlay is active.

### Splash + launch screen
**The OS launch screen and the SwiftUI splash MUST stay visually identical.** They are two separate files (`LaunchScreen.storyboard` and `SplashView.swift`) that the user sees back-to-back during launch — any divergence (different image, different layout, different background) is jarring. Treat them as one design with two implementations.

- **Single source of truth:** both reference the same `splash-screen-img` imageset in `Assets.xcassets`. To change the splash artwork, update that one imageset (1x/2x/3x). Never let the two files point at different assets.
- **Any layout change to one MUST be mirrored in the other** — width, centering, background color, padding. If you edit `SplashView.swift`, open `LaunchScreen.storyboard` in the same change (and vice versa) and update both.
- **OS launch screen:** `LaunchScreen.storyboard` (in `hallways/Resources/`). Background `#FCFCFC`, cluster image (`splash-screen-img`) centered, full width (equal-width constraint to the root view).
- **SwiftUI splash:** `SplashView` — same `#FCFCFC` background, same `splash-screen-img` at full width. `ContentView` shows it for 0.3s after launch, then fades it out with `easeOut(0.35)`. No curtain reveal animation (was removed for snappy launch).
- **Safe-area trap:** `.ignoresSafeArea()` must be on the **outermost container** of `SplashView`, not just the background. The storyboard centers on the root view (true screen midpoint); a SwiftUI image that respects the safe area centers on the asymmetric safe-area rect and ends up ~12pt below the storyboard image on Dynamic Island devices — a visible jump during the splash crossfade.
- **Full-width parity:** the storyboard imageView needs both a width-equal-to-root constraint AND an aspect-ratio constraint (`width:height = 1125:1227`, matching the @3x image pixels). Without the aspect constraint, autolayout keeps the imageView at intrinsic height (~409pt) and `scaleAspectFit` letterboxes the image to ~375pt wide. SwiftUI's `.resizable().aspectRatio(.fit).frame(maxWidth: .infinity)` renders true full-width by default, so without the storyboard constraint the two screens disagree on image size.
- **Simulator caches launch storyboards per bundle ID** — changes to `LaunchScreen.storyboard` require `xcrun simctl shutdown booted && xcrun simctl boot ...` to see; `uninstall` alone is not enough. **If the two screens look different after a change, suspect this cache first** before assuming the assets are wrong.
- **Custom fonts in launch storyboards don't work reliably** — `UIAppFonts` registration races the launch storyboard's first paint, so UILabels fall back to system font. If you ever need text on the launch screen, rasterize it to PNG (Python+Pillow + the `.ttf`) and add it as an `imageView`. The current splash has no text precisely to avoid this trap.

### Data Models

- **`Piece`** (`@Model`): id, type (`.text`/`.media`), textContent, imageFileName, imageData, sortOrder, createdAt, collection (inverse). Computed `tilt: Double` from UUID hash (-3...3).
- **`Collection`** (`@Model`): id, title, pieces (`@Relationship(deleteRule: .cascade, inverse: \Piece.collection)`), lastEditedAt, sortOrder. Computed `orderedPieces` sorted by `sortOrder`.

## Build & Run

Open `hallways.xcodeproj` in Xcode 16+. Run on iOS 18+ simulator/device.

If `xcode-select` points to CommandLineTools, prefix with:
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

### Info.plist
**`Info.plist` lives at the project root**, not inside `hallways/`. It's a real plist file (not auto-generated):
- `GENERATE_INFOPLIST_FILE = NO`
- `INFOPLIST_FILE = Info.plist`
- Contains `UIAppFonts`, `UILaunchStoryboardName = LaunchScreen`, scene manifest, supported orientations, etc.

It's outside the `hallways/` synchronized group because `PBXFileSystemSynchronizedRootGroup` would otherwise auto-include it as a bundle resource AND set it as the app's Info.plist — causing a "Multiple commands produce Info.plist" build error.

## Test

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project hallways.xcodeproj -scheme hallways -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Project Structure

```
Info.plist                                - Custom Info.plist (not in hallways/ — see Gotchas)
hallways/
  hallwaysApp.swift                       - App entry: ModelContainer, sample data seed onAppear (fonts via UIAppFonts now, not programmatic)
  ContentView.swift                       - Splash fade gate → FeedView
  Models/
    Piece.swift                           - @Model: text/media, imageFileName, sortOrder, inverse to Collection
    Collection.swift                      - @Model: title, pieces (cascade), lastEditedAt, sortOrder, orderedPieces
  Theme/
    HallwaysTheme.swift                   - Colors, layout constants, Font.specialElite/printvetica, Color(hex:)
  Utilities/
    ImageStorage.swift                    - saveJPEG(_:quality:) to Documents/<uuid>.jpg; loadImage(named:) asset → Documents fallback; deleteImage(named:)
  Views/
    FeedView.swift                        - NavigationStack root; bottom bar (plus + toggle); all create-flow overlays; publishCollection persists
    MinimalistView.swift                  - Vertical scroll of collections (collection rows only)
    MinimalistExpandedView.swift          - Per-collection scroll list with hero tap-to-view, date stamp, three-dots → editor, edge-swipe-back, ScrollViewReader for hero alignment, toolbar hide
    ImageViewerView.swift                 - TabView paging viewer; matchedGeometry on current page only; vertical drag-down dismiss; pinch zoom
    FileView.swift                        - 2-column grid: standalones + collection stacks
    FileExpandedView.swift                - Blurred overlay with piece grid + title + date
    SplashView.swift                      - Cluster image + Special Elite tagline (matches launch storyboard)
    Components/
      PieceCardView.swift                 - Renders piece as image (ImageStorage-backed) or text card
      CollectionRowView.swift             - Overlapping horizontal scroll of cards with tilt + scatter
      CollectionStackView.swift           - Mini 3-card stack preview for file grid
      ViewModeToggle.swift                - Animated toggle
    Create/
      CreateOverlay.swift                 - White blur overlay; upload-media + writing CTAs (Printvetica); chevron-down dismiss
      CreateEditView.swift                - Editor (create + edit modes); custom drag via CardLongPressGesture; Instagram-style reorder; delete zone; PhotoDraft struct; EditorMode enum
      PublishSemicircleShape.swift        - Shape with topCurveHeight + bottomCurveHeight; control points outside rect for outward bulges; AnimatablePair
      PublishCurtainView.swift            - Rise / hold / exit-up animation; parameterized label ("publish" / "update")
  SampleData/
    SampleDataProvider.swift              - Seeds 2 standalone pieces + 2 collections on first launch
  Resources/
    LaunchScreen.storyboard               - OS launch screen: cluster image + rasterized tagline
    SpecialElite-Regular.ttf
    Printvetica.otf
  Assets.xcassets/
    AppIcon, AccentColor, 9 sample images
    splash-screen-img.imageset            - Cluster image (1x/2x/3x)
    splash-tagline.imageset               - Unused. Was rasterized "means a lot you're here" tagline; both splash screens dropped the text. Safe to delete.
    LaunchBackground.colorset             - #FCFCFC color for launch screen
  Preview Content/
hallwaysTests/
hallwaysUITests/
```

## Asset Locations

- **Design references:** `my-design-assets/references/`
- **Source images:** `my-design-assets/images/`
- **Fonts:** `my-design-assets/fonts/SpecialElite-Regular.ttf`, `Printvetica.otf`
- **Splash branding:** `my-design-assets/branding/splash-screen-img.png`

## Code Style

- Swift, SwiftUI declarative.
- `@Model` SwiftData classes; `@Query` + `@Environment(\.modelContext)` for data access.
- Special Elite for all visible text by default; Printvetica for CTAs and date stamp.
- Xcode 16 project format with `PBXFileSystemSynchronizedRootGroup` (`.swift` files under `hallways/` are auto-discovered).
- **Custom drag-and-drop in carousel uses UIKit gesture bridge** — see `CardLongPressGesture` in `CreateEditView.swift`. Don't replace with SwiftUI gestures.

## Gotchas

### SwiftUI / iOS quirks
- **`.offset` API:** `.offset(x:y:)` or `.offset(CGSize)`. There is **no** `.offset(width:height:)`.
- **ZStack + transitions:** always pin conditionally-rendered overlays with `.zIndex(1)` (or higher) when they use `.transition(...)`. Otherwise SwiftUI drops them behind siblings during the exit half of the animation.
- **`matchedGeometryEffect` source flip:** the source view (`isSource: true`) defines geometry; ghosts animate to it. For tap-to-expand overlays, flip the source on the list-side card via `isSource: selectedPiece?.id != piece.id`. **Inside a TabView, only apply `matchedGeometryEffect` to the *currently visible* page** — off-screen pages with the modifier try to match their source's geometry and cause scatter glitches during paging.
- **`scrollPosition(id:)` triggers layout passes** when mutated. If you set it inside a `withAnimation` block during an active SwiftUI gesture, the gesture can be silently cancelled (`@GestureState` resets). Defer such updates in a `Task` with a small `try? await Task.sleep(for: .milliseconds(60))`.
- **UIScrollView vs SwiftUI gestures:** `.simultaneousGesture` with a long-press-then-drag combo often leaves stuck state (gesture cancellation by ScrollView's pan doesn't fire `onEnded`). Use `UIGestureRecognizerRepresentable` wrapping `UILongPressGestureRecognizer` — UIKit handles the coordination correctly.
- **Footer scale springs:** if you scale a full-width footer via `scaleEffect(_:anchor: .bottom)` with a bouncy spring, the spring overshoots below 1.0 and reveals a gap between the footer and the screen edges. Use `easeOut` (monotonic) instead.
- **Keyboard collapsing safeAreaInset content:** publish/update footer needs `.ignoresSafeArea(.keyboard, edges: .bottom)` or the keyboard pushes it out of view. Curtain animation should use `max(geo.size.height, UIScreen.main.bounds.height)` so a keyboard-shrunk reader doesn't undersize it.

### Info.plist / build
- **`INFOPLIST_KEY_*` build settings only support top-level keys.** They cannot populate sub-keys of `UILaunchScreen` (e.g., `UIImageName`). To customize the launch screen, use a real `Info.plist` (or `LaunchScreen.storyboard` via `INFOPLIST_KEY_UILaunchStoryboardName`).
- **`Info.plist` placement with `PBXFileSystemSynchronizedRootGroup`:** keep it OUTSIDE the synchronized group (project root works). Otherwise Xcode both copies it as a bundle resource AND uses it as the app's Info.plist, causing a "Multiple commands produce Info.plist" build error.
- **Custom fonts in launch storyboards:** `UIAppFonts` registers fonts before `application:didFinishLaunchingWithOptions:` but often loses the race against the launch storyboard's first render. Labels in `LaunchScreen.storyboard` will silently fall back to system font even with the correct PostScript name. **Rasterize text to PNG** (via Python+Pillow + the `.ttf` file) and use a `UIImageView` instead.
- **Simulator launch-storyboard cache:** the simulator caches the rendered launch storyboard per bundle ID. Changes won't appear after a normal `xcrun simctl install`. Do `xcrun simctl shutdown booted && xcrun simctl boot ...` to clear it.

### Data
- **Sample data seed gating:** `SampleDataProvider.seed` is guarded by `fetchCount(Piece) == 0`. Changes to seed data require deleting the app from the simulator (long-press → Remove App, or `xcrun simctl uninstall`) — the existing SwiftData store persists otherwise.
- **Newest-collection-at-top:** new collections are inserted with `sortOrder = minExistingSortOrder - 1`. The `@Query(sort: \Collection.sortOrder)` is ascending, so smaller sortOrder = appears first.
- **PieceCardView + ImageViewerView both need `ImageStorage.loadImage`:** user-published photos live in `Documents/`. Asset catalog only contains the seed images. Both views must try the catalog first, then the Documents fallback.
- **Sticky LSP "No such module 'UIKit'" warning:** common false positive from SourceKit when reading files outside Xcode's iOS toolchain context. The actual iOS build resolves UIKit fine. Trust `xcodebuild` over LSP diagnostics for cross-platform module errors.
</content>
</invoke>