# Hallways

A journaling iOS app where users create "pieces" (text or media) and organize them into titled "collections." Think of it as a visual, scrapbook-style journal.

## MVP Scope

- **Private-only** -- no accounts, no sharing, no public profiles
- Two view modes: **minimalist** (vertical scroll with overlapping tilted cards) and **file** (2-column grid with stacked previews)
- Sample data seeds on first launch
- Navigation into collections (expanded views)
- No editing/creation flows yet (add button is non-functional)

## Future Scope

- Piece creation and editing (text + photo)
- Collection management (reorder, rename, delete)
- Public profiles and sharing

## Design System

- **Font:** Special Elite (monospace typewriter style), registered programmatically via `CTFontManager`
- **Colors:**
  - Background: `#FCFCFC`
  - Text: `#121212`
  - Overlay: `#7A7A7A` at 55% opacity + `.ultraThinMaterial` blur (file expanded background)
  - Card: `#EFEFEF` at 80% opacity (file expanded card)
  - Text card: `#F5F0E8` (parchment-like)
  - File expanded text (title, date, reorder): black (`HallwaysTheme.text`), not white
- **Images:** No corner radius. Aspect ratio preserved (`.fit`). `PieceCardView` supports three sizing modes via optional `cardWidth: CGFloat?` / `cardHeight: CGFloat?`:
  - Height-only (collection rows, file expanded): image uses `.frame(height:)` with natural width.
  - Width-only (minimalist expanded list): image uses `.frame(width:)` with aspect-ratio-derived height; text cards use a 3:4 portrait ratio.
  - Width + height (file grid, file expanded grid): image uses `.frame(maxWidth:, maxHeight:)`.
- **Layout:**
  - Minimalist view shows **collections only** (no standalone pieces). Standalone pieces appear in the file view.
  - Collection row height: 150pt (`HallwaysTheme.collectionRowHeight`); spacing between rows: 72pt.
  - Minimalist view outer leading padding: 16pt; collection row internal horizontal padding: 16pt.
  - Collection row tilt pattern: cycles `[-6°, 0°, +5°]` per index (`HallwaysTheme.collectionTiltPattern`).
  - Collection row vertical scatter: alternating ±10pt offset (`HallwaysTheme.collectionVerticalScatter`), even index = up, odd = down.
  - Collection row z-order: rightmost piece on top (`zIndex(Double(index))`).
  - Collection row overlap: -20pt spacing between items.
  - Collection rows: no title label displayed.
  - Minimalist expanded view: width-based sizing. Content width = screen width − 48pt (24pt × 2). Landscape images (`UIImage.size.width ≥ .size.height`) use full content width; portrait images and text pieces use 80% of content width. Pieces are centered via `.frame(maxWidth: .infinity)`.
  - File grid: 2-column grid, collections have rounded-rect bounding box border (`#E0E0E0`).
- **Toggle:** Black rounded rectangle (80x44) with white square indicator (30x30, 3pt padding). Left = minimalist, right = file mode. Animated slide on toggle.

## Architecture

- **SwiftUI** for the UI layer
- **SwiftData** for persistence (on-disk SQLite via `ModelContainer`)
- `NavigationStack` with `navigationDestination` for drill-down into collections (minimalist expanded view)
- File expanded view: ZStack overlay in `FeedView` with `.transition(.opacity)` fade-in (not `.fullScreenCover`). Overlay renders above the bottom bar (plus button + toggle). `selectedCollection` state lives in `FeedView`, passed as `@Binding` to `FileView`.
- `FileExpandedView` takes an `onDismiss` closure (not `@Environment(\.dismiss)`)
- Full-screen image viewer: ZStack overlay in `MinimalistExpandedView` with `.transition(.opacity)`. Tap a piece → `selectedPiece` state set → `ImageViewerView` overlays. Hero zoom via `matchedGeometryEffect` (shared `@Namespace heroNamespace`); source flips with `isSource: selectedPiece?.id != piece.id`. Works for both media and text pieces.
- **Overlay z-index:** Both `FileExpandedView` (in `FeedView`) and `ImageViewerView` (in `MinimalistExpandedView`) have explicit `.zIndex(1)`. Without it, SwiftUI drops conditionally-rendered overlays behind their ZStack siblings during the exit half of `.transition(.opacity)`. Always pin overlays with `.zIndex` when using transitions.
- `ImageViewerView` interactions: black bg (opacity fades with drag distance / 300); pinch-to-zoom via `UIPinchGestureRecognizer` wrapped in `UIGestureRecognizerRepresentable` (iOS 18+) — anchor is **pinned at `.began`** (gesture-start midpoint) and finger drift translates the image via a separate `pinchOffset`, mimicking Photos. Pinch snaps back to scale 1 / anchor center / offset zero on release via `withAnimation(.spring)`. Drag-to-dismiss accepts only positive `dx`/`dy` (down or right), threshold `hypot > 100`.

### Data Models

- **Piece** (`@Model`): id, type (.text/.media), textContent, imageFileName, imageData, sortOrder, createdAt, collection (inverse relationship). Computed `tilt` from UUID hash.
- **Collection** (`@Model`): id, title, pieces (cascade delete), lastEditedAt, sortOrder. Computed `orderedPieces` sorted by sortOrder.

## Build & Run

Open `hallways.xcodeproj` in Xcode 16+ and run on a simulator or device (iOS 18+).

If `xcode-select` points to CommandLineTools instead of Xcode.app, prefix commands with:
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## Test

- Unit tests: `hallwaysTests` target (Swift Testing framework)
- UI tests: `hallwaysUITests` target (XCTest)

Run via Xcode (Cmd+U) or:
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project hallways.xcodeproj -scheme hallways -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Project Structure

```
hallways/
  hallwaysApp.swift                    - App entry point; ModelContainer, font registration, sample data seeding
  ContentView.swift                    - Thin wrapper rendering FeedView with background color
  Models/
    Piece.swift                        - Piece data model (text or media)
    Collection.swift                   - Collection data model (group of pieces)
  Theme/
    HallwaysTheme.swift                - Colors, opacity, layout constants, Font.specialElite(), Color(hex:)
  Views/
    FeedView.swift                     - Root view: NavigationStack, view mode state, bottom bar, file expanded overlay (zIndex 1)
    MinimalistView.swift               - Vertical scroll of collection rows only (no standalones); leading 16pt, row spacing 72pt
    MinimalistExpandedView.swift       - Width-sized piece list; tap-to-view full-screen with matchedGeometryEffect hero
    ImageViewerView.swift              - Full-screen viewer: black bg, hero zoom, Photos-style pinch (UIPinchGestureRecognizer via UIGestureRecognizerRepresentable), drag-down/right to dismiss
    FileView.swift                     - 2-column grid of standalone pieces + collection stacks
    FileExpandedView.swift             - Fade-in overlay with blurred bg, piece grid, title, date
    Components/
      PieceCardView.swift              - Renders a single piece as image or styled text card. Supports width-only, height-only, or both (cardWidth/cardHeight both optional)
      CollectionRowView.swift          - Horizontal scroll of overlapping pieces; tilt cycles [-6°,0°,+5°], vertical scatter ±10pt, rightmost on top
      CollectionStackView.swift        - Mini stacked preview with bounding box border (for file grid)
      ViewModeToggle.swift             - Black rectangle toggle with sliding white square indicator
  SampleData/
    SampleDataProvider.swift           - Seeds 2 standalone pieces + 2 collections on first launch. `selfie-retro-cam` appears as standalone + in both collections (separate Piece instances sharing one asset)
  Resources/
    SpecialElite-Regular.ttf           - Custom typewriter font
  Assets.xcassets/                     - App icon + 9 sample images as imagesets
  Preview Content/
    Preview Assets.xcassets/
hallwaysTests/
  hallwaysTests.swift
hallwaysUITests/
  hallwaysUITests.swift
  hallwaysUITestsLaunchTests.swift
```

## Asset Locations

- **Design references:** `my-design-assets/references/` (4 Figma mockup PNGs)
- **Source images:** `my-design-assets/images/` (9 hi-res image files + 1 text piece example)
- **App icon source:** `my-design-assets/` or `~/Downloads/app cover.png`
- **Font source:** `my-design-assets/fonts/SpecialElite-Regular.ttf`

## Code Style

- Swift, SwiftUI declarative syntax
- `@Model` classes for SwiftData entities
- `@Query` and `@Environment(\.modelContext)` for data access in views
- Special Elite font for all visible text
- Xcode 16 project format with `PBXFileSystemSynchronizedRootGroup` (auto-discovers files — new `.swift` files under `hallways/` need no project edit)

## Gotchas

- **Sample data seed gating:** `SampleDataProvider.seed` is guarded by `fetchCount(Piece) == 0`. Changes to seed data (e.g., adding a piece to a collection) require deleting the app from the simulator (long-press → Remove App) to take effect — the existing SwiftData store persists otherwise.
- **`.offset` API:** SwiftUI `View.offset` is `offset(x:y:)` or `offset(CGSize)`. There is **no** `offset(width:height:)` initializer.
- **ZStack + transitions:** always pin conditionally-rendered overlays with `.zIndex(1)` (or higher) when they use `.transition(...)`. Otherwise they fall behind siblings during the exit half of the animation.
- **`matchedGeometryEffect` source flip:** the source view (`isSource: true`) defines the geometry; ghosts animate to it. For tap-to-expand overlays, flip the source on the list-side card via `isSource: selectedPiece?.id != piece.id` so the overlay owns geometry while presented.
