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
- **Writing flow: complete.** Tap + → `writing` CTA → green-paper editor with `tell me my love` placeholder → typewriter input with smart bullets → publish curtain → standalone text piece appears in File view → tap to re-open editor in `.edit` mode.
- **Combined collections (media + text): complete.** From the create/edit media carousel, tapping the trailing `+` opens an `upload media` / `writing` chooser; choosing writing attaches one text piece to the in-progress collection. A combined collection (`isCombined = mediaPieces > 0 && textPiece != nil`) routes to `CombinedExpandedView` (split layout: top-trailing title+date header, 40/60 horizontal media row + parchment text region). All expanded views (combined + minimalist) now expose edit via a pull-down half-moon CTA on the header (the old three-dots toolbar is gone). Combined edit opens `CollectionEditOverviewView` (X + two big "edit media" / "edit text" tap targets + a `save` dome), which branches into `CreateEditView(.branch)` / `WritingEditorView(.branch)` — both branches use a chevron-left back arrow that auto-commits in-memory; only the overview's `save` persists to SwiftData.

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
- Writing editor background: `green-paper-bg` imageset (light olive paper texture)
- Quarter-circle X backdrop (writing editor): `#FCFCFC` at 60% opacity
- File expanded text: black (`HallwaysTheme.text`), not white
- **Delete state (red footer):** `#9B1515` (dragging, not yet hovering delete zone) / `#A11111` (hovering delete zone — "activated")
- **Date stamp (gray):** `#9F9F9F`

### Image rendering — `PieceCardView`
No corner radius, aspect ratio preserved (`.fit`), three sizing modes via optional `cardWidth`/`cardHeight`:
- Height-only (collection rows, file expanded) → `.frame(height:)`, natural width
- Width-only (minimalist expanded) → `.frame(width:)`, aspect-derived height; text uses 3:4 portrait
- Both (file grid) → `.frame(maxWidth:, maxHeight:)`
Loads via `ImageStorage.loadImage(named:)` — tries asset catalog first, falls back to `Documents/<filename>` (downsampled via ImageIO at load time). Both code paths hit an `NSCache<NSString, UIImage>` keyed by filename so subsequent renders are cache hits (SwiftUI re-runs `body` constantly). Companion `ImageStorage.imageSize(named:)` reads pixel dimensions from the JPEG header without decoding (used by `MinimalistExpandedView.width(for:)` to pick portrait vs landscape sizing without paying the decode cost on every layout pass). `CollectionRowView` uses `LazyHStack` so off-screen cards in long collections aren't decoded up front.

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
- 2: `CreateOverlay` (when `showCreateOverlay`)
- 3: `CreateEditView` (when `editingPhotos != nil`) **or** `WritingEditorView` (when `showWritingCreate` for create / `editingTextPiece != nil` for edit)
- 4: `PublishCurtainView` (media — when `publishingPayload != nil`; writing — when `publishingText != nil`, label `"publish"` for create / `"save"` for edit)

### Overlays in `MinimalistExpandedView`
ZStack:
- 0: vertical piece list (`ScrollViewReader` + `LazyVStack`, each card with `.id(piece.id)` for proxy scrolling)
- 1: `ImageViewerView` (when `selectedPiece != nil`)
- 2: `CreateEditView` in edit mode (when `showEditor`)
- 3: `PublishCurtainView` label "update" (when `updatePayload != nil`)
- 50: invisible 20pt left-edge strip with DragGesture for edge-swipe-back (only mounted when no overlay is up)
- Toolbar visibility: `chromeVisibility` hides the nav bar when viewer or editor is open.
- Tracks `lastInteractedID` to keep the exiting hero card layered above siblings during the matchedGeometry return.

### Create / edit flow (media)
- `CreateOverlay` — white blur over feed, two CTAs (`upload media` / `writing`), chevron-down dismiss. Printvetica buttons.
- `CreateEditView` — shared by three modes via `EditorMode` enum (`.create` / `.edit(Collection)` / `.branch(initialDrafts:, onCommit:)`):
  - Top bar: X (cancel, with "are you sure?" prompt) + title TextField (placeholder `[untitled collection]`, empty title is saved as empty) + trash (`.edit` only, "delete this collection?" prompt — one-tap delete; the hold-to-delete progress bar was removed). In `.branch` mode, X becomes chevron-left that auto-commits via `mode.branchCommit?(drafts); onCancel()`; title field and trash are hidden.
  - Horizontal `LazyHStack` carousel with `.scrollPosition(id:)` for programmatic edge auto-scroll. Cards sized by aspect: landscape ≤ 300pt wide, portrait ≤ 360pt tall.
  - **Trailing `+` button** opens a chooser overlay (reuses `CreateOverlay` with `upload media` / `writing` CTAs). `upload media` → PhotosPicker (capped at 10 total). `writing` → presents `WritingEditorView(.branch)` whose `onCommit` writes to a local `@State draftText: String?`. In `.branch` mode (sub-screen of the combined edit overview), the chooser is skipped and `+` opens PhotosPicker directly.
  - On publish, `onSave(title, drafts, textContent: String?)` carries the draftText through. In `.create`, FeedView attaches a text piece to the new collection if non-empty; in `.edit`, MinimalistExpandedView upserts/deletes the text piece on the existing collection. `.branch` mode never fires `onSave` — the dome is a permanent red `delete` zone (drag-to-delete-a-piece is unchanged) instead of a publish target.
  - Bottom publish footer using `HalfMoonCTA` (curve facing up), pinned via `safeAreaInset(.bottom)` + `.ignoresSafeArea(.keyboard, edges: .bottom)` so keyboard doesn't collapse it. In `.branch` mode, the same dome is permanently red (`#9B1515` / `#A11111` on drag) with label `delete` — the publish tap is gated by `guard !mode.isBranch`.
  - `PhotoDraft` struct carries the in-flight image plus optional `existingPieceID`/`existingFilename` so edit-mode diffs can tell new from existing.

### Create / edit flow (writing)
- `WritingEditorView` ([Views/Create/WritingEditorView.swift](hallways/Views/Create/WritingEditorView.swift)) — owns its own `Mode` enum (`.create` / `.edit(Piece)` / `.branch(initialText:, onCommit:)`); does NOT share `EditorMode` with `CreateEditView` because the surface area diverges too much. `.branch` is the sub-screen used inside `CollectionEditOverviewView`: no publish/save footer, chevron-left back arrow that calls `onCommit(text); onCancel()`, trash hidden, `bottomClearance` reset to default 24 (no dome to clip under).
  - **Background:** `Image("green-paper-bg")` rendered via `.background(...)` on the root ZStack (NOT as a ZStack child — see Gotcha). `.ignoresSafeArea()` extends the paint to screen edges without pushing the ZStack's layout frame past safe area.
  - **Top widgets** (each in its own overlay): `QuarterCircleShape` backdrop (130pt) anchored top-left with the X button inside (`.padding(.top, 60, .leading, 12)`); paper-bg picker placeholder (32pt circle, FCFCFC stroke, currently non-interactive) anchored top-right at the same y. Both overlays use `.ignoresSafeArea(edges: .top)` so they sit at the literal screen top regardless of safe area, and `.ignoresSafeArea(.keyboard)` so SwiftUI's auto-keyboard-avoidance doesn't push them off the top of the screen when the keyboard rises.
  - **Body:** `BulletTextView` (UITextView bridge) filling the area between top widgets and the dome footer. `.padding(.top, 80)`, NO bottom padding — the UITextView's frame extends all the way to the safe-area bottom and the dome sits on top of it so text visually scrolls *under* the save button (clipped behind it). Special Elite **18pt**, 40pt horizontal text-container insets. `bottomClearance` is passed as `footerHeight + footerTopCurve + 8` (≈96pt) in non-branch modes so the user can scroll the last line above the dome; in `.branch` mode it's the default 24 because there's no dome. Placeholder `tell me my love` is a SwiftUI Text overlay with `.allowsHitTesting(false)` shown when `text.isEmpty && !isFocused`.
  - **Footer:** same `HalfMoonCTA` dome as media; positioned as a direct ZStack child anchored `.bottom` (NOT `safeAreaInset` — see Gotcha). Label `"publish"` for create, `"save"` for edit. No-op when text trimmed empty. Footer stays pinned at safe-area bottom even when keyboard rises (keyboard simply covers it; user dismisses keyboard first to tap publish).
  - **Top-left X (`.create` / `.edit` only):** if text is empty, X exits immediately. If text exists, X shows the same `"are you sure?"` prompt as media flow. In `.branch` mode, X is replaced by a chevron-left that auto-commits via `onCommit(text)` — no confirm.
  - **Top-right (`.edit` only):** trash icon to the left of the paper-picker circle (`HStack { trash; paperPickerPlaceholder }`). Tap shows `"delete this piece?"` confirm; on confirm, FeedView calls `modelContext.delete(piece); try? modelContext.save()` and dismisses the editor. Hidden in `.create` and `.branch`.
  - **Persistence in `FeedView`:**
    - `publishingText: PublishingText` payload carries `content` + optional `editingPieceID`.
    - `persistText(payload:)` — for create: insert a standalone `Piece(type: .text, textContent:, sortOrder: min(collection.sortOrder, standalonePiece.sortOrder) - 1)` then `viewMode = .file`. For edit: fetch the Piece by ID and update `textContent`.
    - **Delete standalone text piece** (edit mode trash → confirm → `onDelete`): `modelContext.delete(piece); try? modelContext.save()`, then dismiss the editor. No JPEG cleanup needed because text pieces don't have an `imageFileName`.
    - Auto-switches to File view after create so the new text card is visible (standalone text pieces don't show in Minimalist mode, which is collection-only).
- `BulletTextView` ([Views/Create/BulletTextView.swift](hallways/Views/Create/BulletTextView.swift)) — `UIViewRepresentable` wrapping `UITextView`:
  - Bullet rules implemented in `textView(_:shouldChangeTextIn:replacementText:)`: `- ` at start of line → `• `; Enter on bulleted line → continues with `\n• `; Enter on empty `• ` line → strips the bullet; backspace inside empty `• ` line → strips the whole `• `.
  - `tv.smartDashesType = .no` so iOS doesn't convert `--` to em-dash before our rule fires.
  - `keyboardDismissMode = .interactive` so users can swipe the keyboard down.
  - **`bottomClearance: CGFloat` parameter** (default 24) — when the UITextView's frame extends down past where a dome footer sits (so text scrolls visually *behind* the dome), the keyboard observer uses `bottomClearance` as `baseBottom`. With clearance = `footerHeight + footerTopCurve + 8 ≈ 96`, the user can scroll the last line up to ~96pt above the bottom — i.e., above the dome. WritingEditorView passes 96 in `.create`/`.edit`, 24 in `.branch` (no dome there). Applied to `contentInset.bottom` in `makeUIView` and re-applied in `updateUIView` if the value changes mid-session.
  - Internal keyboard observer in the Coordinator sets `contentInset.bottom = overlap + 40` while keyboard is up (cursor ≥40pt above keyboard), and back to `bottomClearance` on keyboard hide.
  - **Dismiss-on-empty-tap recognizer:** custom `UITapGestureRecognizer` added to the UITextView with a delegate that gates `shouldReceive(touch:)` on **(a)** `textView.isFirstResponder` (so tapping an unfocused empty text view reliably focuses it instead of racing UITextView's built-in focus tap), and **(b)** the touch landing outside the rendered text bounds (`layoutManager.usedRect(for: textContainer)` + `textContainerInset`, with a 20pt "right next to" padding). When the gate passes, the handler calls `resignFirstResponder`. Net behavior: tap on / near text → cursor moves (UITextView default); tap anywhere else in the text view's frame → dismiss.
- `QuarterCircleShape` ([Views/Create/QuarterCircleShape.swift](hallways/Views/Create/QuarterCircleShape.swift)) — tiny `Shape` drawing a pie slice anchored at the top-left corner.
- `green-paper-bg.imageset` in `Assets.xcassets` — single universal scale; source PNG in `~/Downloads/green paper bg.png` (also tracked under design assets if needed).
- `PublishCurtainView` — rise / hold / exit-up animation. Parameterized `label: String` ("publish" or "update"). Uses `max(geo.size.height, UIScreen.main.bounds.height)` for the curtain so a keyboard-shrunk safe area doesn't undersize it. Calls `onRiseComplete` mid-animation (parent persists + dismisses editor) and `onComplete` at end (parent drops the curtain overlay).
- `HalfMoonCTA` — `Shape` with `topCurveHeight` + `bottomCurveHeight` animatable via `AnimatablePair`. Control points sit *outside* the rect so curves bulge outward (upward dome on top, downward dome on bottom).

### Persistence on save (FeedView / MinimalistExpandedView)
- **Create (media):** each `UIImage` → `ImageStorage.saveJPEG` → new `Piece` with that filename → new `Collection(title, pieces, sortOrder: minExistingSortOrder - 1)` → insert + save. New collection appears at top because `@Query(sort: \Collection.sortOrder)` ascends.
- **Update (media edit):** diff `drafts` against `collection.pieces` by `existingPieceID`. Removed → `modelContext.delete(piece)` + `ImageStorage.deleteImage(named:)`. New → save JPEG + append `Piece`. Existing → just update `sortOrder = index`. Update `title` + `lastEditedAt`.
- **Delete collection:** delete every piece's JPEG, `modelContext.delete(collection)` (cascade), save, `dismiss()` to pop the nav back to the feed.
- **Create (text):** insert standalone `Piece(type: .text, textContent:, sortOrder: min(collection.sortOrder, standalonePiece.sortOrder) - 1)` (no Collection). `viewMode = .file` so the new card is visible.
- **Update (text edit):** find piece by ID, set `textContent` to trimmed content, save.
- **Standalone text pieces** are queried via `@Query(filter: #Predicate<Piece> { $0.collection == nil }, sort: \Piece.sortOrder)` and rendered in `FileView.standaloneItem` via `PieceCardView`. The tile is a `Button` that calls a callback (`onEditTextPiece`) wired up by FeedView to set `editingTextPiece = piece`.

### Drag-and-drop in the editor carousel (Instagram-style)
**Use the UIKit gesture bridge — do not go back to SwiftUI's `LongPressGesture.sequenced(before:)`.** The SwiftUI version conflicts with `ScrollView` pan in ways that can't be reconciled (`simultaneousGesture` leaves stuck `draggingID`, `.gesture` blocks scroll entirely).

- `CardLongPressGesture: UIGestureRecognizerRepresentable` wraps `UILongPressGestureRecognizer` (`minimumPressDuration: 0.2`, `allowableMovement: 15`). UIKit natively handles "stillness for X seconds wins, movement wins for the scroll" — no manual coordination needed.
- On `.began` → lift card immediately (ghost appears at 85% scale, shadow). On `.changed` → real-time reorder via `reorderIfHovering`: find the *other* card whose frame contains the finger's X, swap dragged item into that slot with a spring. Cards slide aside to make room. Track `editorGlobalFrame` and convert `recognizer.location(in: nil)` (window coords) → editor coords with `toEditor(_:)`.
- Edge auto-scroll: only when finger is within 30pt of the carousel edge, advance `scrollAnchorID` to the dragged item's neighbor every 700ms (after 250ms warm-up). Real-time hover-reorder then targets the newly-revealed off-screen card.
- Delete zone: finger Y > `editorSize.height * 0.75` (bottom 25%). On drag start the footer turns `#9B1515` with label "delete". When the finger enters the delete zone ("activated"), the footer's colored shape (`fillColor` rect + `HalfMoonCTA`) scales 1.6× with anchor `.bottom` AND the color shifts to `#A11111`. The "delete" `Text` lives outside the scaled ZStack so it stays at the original 16pt size and bottom-anchored position — only the dome grows around it. Use `easeOut(0.22)` for the scale animation — `spring` overshoots below 1.0 and reveals a gap on the screen sides.
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
    Collection.swift                      - @Model: title, pieces (cascade), lastEditedAt, sortOrder, orderedPieces, mediaPieces, textPiece, isCombined
  Theme/
    HallwaysTheme.swift                   - Colors, layout constants, Font.specialElite/printvetica, Color(hex:)
  Utilities/
    ImageStorage.swift                    - saveJPEG(_:quality:); loadImage(named:) asset → Documents fallback w/ NSCache; imageSize(named:) JPEG-header-only dimensions w/ NSCache; deleteImage(named:) (invalidates both caches)
  Views/
    FeedView.swift                        - NavigationStack root; bottom bar (plus + toggle); all create-flow overlays; publishCollection persists
    MinimalistView.swift                  - Vertical scroll of collections (collection rows only)
    MinimalistExpandedView.swift          - Per-collection scroll list for media-only; top-trailing title+date header w/ chevron-left back arrow; pull-down half-moon edit CTA (replaces old three-dots); hero tap-to-view; ScrollViewReader for hero alignment; toolbar hidden
    CombinedExpandedView.swift            - Split layout for combined (media+text) collections: 40/60 horizontal mediaRow + parchment textRegion, top-trailing title+date header w/ chevron-left back arrow; pull-down half-moon edit CTA; mounts CollectionEditOverviewView as ZStack overlay
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
      CreateOverlay.swift                 - White blur overlay; upload-media + writing CTAs (Printvetica); chevron-down dismiss. Reused as the carousel-end chooser inside CreateEditView
      CreateEditView.swift                - Media editor; EditorMode (.create / .edit(Collection) / .branch(initialDrafts:, onCommit:)); custom drag via CardLongPressGesture; Instagram-style reorder; delete zone; carousel-end chooser opens writing sub-editor; draftText state attaches text piece on publish; PhotoDraft struct
      WritingEditorView.swift             - Text editor; Mode (.create / .edit(Piece) / .branch(initialText:, onCommit:)); green-paper bg; quarter-circle X (or chevron-left in branch); paper-picker placeholder w/ trash icon in edit mode; 18pt body; publish/save footer (hidden in branch); cancel + delete confirms
      CollectionEditOverviewView.swift    - Edit overview for combined collections; X top-left + edit media / edit text tiles + save dome via safeAreaInset; owns in-memory drafts/textContent; branches into CreateEditView(.branch) / WritingEditorView(.branch); on save fires PublishCurtainView and applyChanges() commits to SwiftData
      BulletTextView.swift                - UITextView bridge: bullet rules, bottomClearance parameter (lets text scroll behind the publish dome), keyboard inset tracking, custom empty-area tap recognizer
      QuarterCircleShape.swift            - Pie slice anchored top-left, used behind the writing-editor X button
      HalfMoonCTA.swift        - Shape with topCurveHeight + bottomCurveHeight; control points outside rect for outward bulges; AnimatablePair
      PublishCurtainView.swift            - Rise / hold / exit-up animation; parameterized label ("publish" / "save" / "update")
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
    green-paper-bg.imageset               - Writing editor background (single universal scale)
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
- **`.ignoresSafeArea()` on a ZStack child vs `.background()`:** putting a full-screen `.ignoresSafeArea()` view as a *ZStack child* pushes the ZStack's own layout frame out to the screen edge — any sibling positioned via `alignment: .bottom` then anchors at the screen bottom (under the home indicator) instead of the safe-area boundary. This is why an early `WritingEditorView` had its publish dome hidden by the rounded corners. **Fix:** put the bg image inside `.background(...)` instead. `.background` paints behind the view's bounds without altering the layout frame, so the ZStack stays inside safe area and `.bottom` aligns where you'd expect. The bg `.ignoresSafeArea()` still extends the paint visually to the screen edges. Same trap applies to `safeAreaInset` — a child that escapes safe area collapses the inset region.
- **Keyboard avoidance shifts overlays off-screen:** SwiftUI's default auto-keyboard-avoidance lifts the entire view to make room for the keyboard. Anything pinned to the top (X button, paper-picker) gets pushed off the visible area. **Fix:** add `.ignoresSafeArea(.keyboard)` to each top overlay so it doesn't move when the keyboard rises (or put it on the root if you want to manage keyboard offset yourself). `WritingEditorView` uses both — root ignores keyboard so layout stays stable; `BulletTextView`'s UITextView handles its own `contentInset.bottom` to keep the cursor above the keyboard.
- **UITextView empty-area-tap dismiss pattern:** to dismiss the keyboard by tapping inside the text view but outside the actual text, add a `UITapGestureRecognizer` to the UITextView with a delegate. In `gestureRecognizer(_:shouldReceive:)`, gate on both `tv.isFirstResponder` (otherwise it races UITextView's built-in focus-tap when keyboard is down, sometimes blocking the keyboard from coming up at all) AND `!textRect.insetBy(dx: -20, dy: -20).contains(touchLocation)` where `textRect` is `layoutManager.usedRect(for: textContainer)` offset by `textContainerInset`. Net behavior: tap on / near text → cursor moves (UITextView default); tap elsewhere → recognizer fires → `resignFirstResponder`.
- **`.ignoresSafeArea` propagates into ZStack-child overlays (CRITICAL).** If a parent view applies `.ignoresSafeArea(edges: .bottom)` (or any direction) on its body, SwiftUI propagates that into any child views — including views you mount as ZStack-child overlays. So if the child overlay tries to use `.safeAreaInset(.bottom) { someFooter }`, SwiftUI tells it "the bottom inset is zero" and the footer anchors at the *screen* bottom (inside the home indicator). This bit `CollectionEditOverviewView` HARD: it was mounted as an overlay inside `CombinedExpandedView`, whose body had `.ignoresSafeArea(.bottom)` so the parchment textRegion could paint to the screen edge. The overlay's `saveFooter` ended up with the `save` label sitting under the home indicator. **Rule:** if a view will host overlays that need safe-area-respecting bottom bars, do NOT ignore bottom safe area on the body. Achieve any "paint to screen edge" effect with a **scoped `.background(SomeColor.ignoresSafeArea(.bottom))`** on the specific sub-view that needs it — `.background()` is layout-neutral and doesn't propagate to siblings/children. See `CombinedExpandedView.textRegion` for the working pattern.
- **VStack ideal-size starvation with `.frame(maxHeight: .infinity)` siblings.** When two children both ask for `maxHeight: .infinity`, SwiftUI does NOT split evenly — it hands each its *ideal* size first, then distributes leftover. A `GeometryReader` has ideal=0; a resizable `Image` with `.aspectRatio(.fill)` reports a huge ideal (its natural pixel size). Result: the Image-rooted child eats all the height; the GeometryReader-rooted child collapses to ~0. **Two-pronged fix used in `CombinedExpandedView`:** (a) drive an *outer* GeometryReader and pass each region an EXPLICIT `.frame(height:)` (e.g. `mediaHeight = avail*0.4`, `textHeight = avail*0.6`); (b) make the resizable Image an `.overlay` of a `Color` root, not a ZStack child — `Color` has zero intrinsic and the overlay is paint-only so the frame is honored. **Pattern to remember:** when a view contains a `.resizable().aspectRatio(.fill)` Image, the view's intrinsic size is dictated by the asset's natural pixel size unless the Image is in `.background` / `.overlay`.
- **`safeAreaInset(edge: .bottom)` only reserves the *frame* size of the inset view.** Any visual extent ABOVE that frame (e.g., a `HalfMoonCTA(topCurveHeight: 48)` curve bulging UP) renders into the main content area. If the main content runs flush to the bottom, the curve overlaps it. **Fix:** add `.padding(.bottom, footerTopCurve + 16)` to the main content (or the scrollable container). This is what `CreateEditView.carousel` does (`.padding(.bottom, footerTopCurve + 16)`) and what `CollectionEditOverviewView.mainContent` does — without it the save dome looks clipped from above by the editTextTile preview.

### Info.plist / build
- **`INFOPLIST_KEY_*` build settings only support top-level keys.** They cannot populate sub-keys of `UILaunchScreen` (e.g., `UIImageName`). To customize the launch screen, use a real `Info.plist` (or `LaunchScreen.storyboard` via `INFOPLIST_KEY_UILaunchStoryboardName`).
- **`Info.plist` placement with `PBXFileSystemSynchronizedRootGroup`:** keep it OUTSIDE the synchronized group (project root works). Otherwise Xcode both copies it as a bundle resource AND uses it as the app's Info.plist, causing a "Multiple commands produce Info.plist" build error.
- **Custom fonts in launch storyboards:** `UIAppFonts` registers fonts before `application:didFinishLaunchingWithOptions:` but often loses the race against the launch storyboard's first render. Labels in `LaunchScreen.storyboard` will silently fall back to system font even with the correct PostScript name. **Rasterize text to PNG** (via Python+Pillow + the `.ttf` file) and use a `UIImageView` instead.
- **Simulator launch-storyboard cache:** the simulator caches the rendered launch storyboard per bundle ID. Changes won't appear after a normal `xcrun simctl install`. Do `xcrun simctl shutdown booted && xcrun simctl boot ...` to clear it.

### Data
- **Sample data seed gating:** `SampleDataProvider.seed` is guarded by `fetchCount(Piece) == 0`. Changes to seed data require deleting the app from the simulator (long-press → Remove App, or `xcrun simctl uninstall`) — the existing SwiftData store persists otherwise.
- **Newest-collection-at-top:** new collections are inserted with `sortOrder = minExistingSortOrder - 1`. The `@Query(sort: \Collection.sortOrder)` is ascending, so smaller sortOrder = appears first.
- **PieceCardView + ImageViewerView both need `ImageStorage.loadImage`:** user-published photos live in `Documents/`. Asset catalog only contains the seed images. Both views must try the catalog first, then the Documents fallback.
- **Don't do image I/O inside SwiftUI `body`:** `ImageStorage.loadImage` is memoized via `NSCache`, so calling it from inside `body` is now safe-ish, but you still want the *first* render of an image to not be on the main thread if you can help it. Anywhere you only need width/height (e.g., `MinimalistExpandedView.width(for:)` picking portrait vs landscape sizing), use `ImageStorage.imageSize(named:)` — it reads JPEG headers via `CGImageSourceCopyPropertiesAtIndex` without decoding the bitmap.
- **Sticky LSP "No such module 'UIKit'" warning:** common false positive from SourceKit when reading files outside Xcode's iOS toolchain context. The actual iOS build resolves UIKit fine. Trust `xcodebuild` over LSP diagnostics for cross-platform module errors.
</content>
</invoke>