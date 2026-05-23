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
- **Images:** No corner radius. Aspect ratio preserved (`.fit`). In collection rows and standalone minimalist pieces, images use fixed height with natural width (no `cardWidth`). In file grid and expanded grid, images use `maxWidth`/`maxHeight` constraints.
- **Layout:**
  - Uniform row height in minimalist view: 210pt for both standalone pieces and collection rows
  - Collection row tilt: alternating positive/negative angles per item (even index = positive, odd = negative), magnitude from UUID hash (min 1.5°)
  - Standalone piece tilt: from UUID hash (-3 to +3 degrees)
  - Collection row overlap: -20pt spacing between items
  - Collection rows: no title label displayed
  - File grid: 2-column grid, collections have rounded-rect bounding box border (`#E0E0E0`)
- **Toggle:** Black rounded rectangle (80x44) with white square indicator (30x30, 3pt padding). Left = minimalist, right = file mode. Animated slide on toggle.

## Architecture

- **SwiftUI** for the UI layer
- **SwiftData** for persistence (on-disk SQLite via `ModelContainer`)
- `NavigationStack` with `navigationDestination` for drill-down into collections (minimalist expanded view)
- File expanded view: ZStack overlay in `FeedView` with `.transition(.opacity)` fade-in (not `.fullScreenCover`). Overlay renders above the bottom bar (plus button + toggle). `selectedCollection` state lives in `FeedView`, passed as `@Binding` to `FileView`.
- `FileExpandedView` takes an `onDismiss` closure (not `@Environment(\.dismiss)`)

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
    FeedView.swift                     - Root view: NavigationStack, view mode state, bottom bar, file expanded overlay
    MinimalistView.swift               - Vertical scroll of standalone pieces + collection rows (uniform row height)
    MinimalistExpandedView.swift       - Single-column piece list for a collection (nav push)
    FileView.swift                     - 2-column grid of standalone pieces + collection stacks
    FileExpandedView.swift             - Fade-in overlay with blurred bg, piece grid, title, date
    Components/
      PieceCardView.swift              - Renders a single piece as image or styled text card (no corner radius)
      CollectionRowView.swift          - Horizontal scroll of overlapping pieces (alternating tilt, no title)
      CollectionStackView.swift        - Mini stacked preview with bounding box border (for file grid)
      ViewModeToggle.swift             - Black rectangle toggle with sliding white square indicator
  SampleData/
    SampleDataProvider.swift           - Seeds 2 standalone pieces + 2 collections on first launch
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
- Xcode 16 project format with `PBXFileSystemSynchronizedRootGroup` (auto-discovers files)
