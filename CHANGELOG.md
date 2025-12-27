# Changelog

All notable changes to this project will be documented in this file.

The format is based on "Keep a Changelog" and this project adheres to
Semantic Versioning.

## [0.1.0]

**New Features**
* **Desktop-Grade Interaction:**
    * **Keyboard Modifiers:** `Ctrl` / `Cmd` + Drag to invert selection; `Shift` + Drag to add to selection.
    * **Click Interaction:**
        * **Click:** Select single item (replaces previous selection).
        * **Ctrl + Click:** Toggle item selection.
        * **Shift + Click:** Range selection (selects all items between the last anchor and current item).
    * **Context Menu (Right-Click):** Added `onContextMenu` callback to `SelectableItem`. Smartly handles auto-selection (selects unselected items on right-click) before showing the menu.
* **Keyboard Shortcuts:** Built-in `Ctrl+A` (Select All) and `Esc` (Clear Selection).
* **Virtualization Support:** Added `allItemsGetter` to `SelectionController` to support 'Select All' in virtualized lists (like `ListView.builder`) where not all items are currently rendered.
* **New Parameters:** `enableKeyboardDrag` and `enableShortcuts` in `SelectionMarquee`.

**Bug Fixes**
* **Scroll Anchoring:** Fixed an issue where the selection marquee start point would "float" on the screen when the list scrolled. The selection box now correctly follows the content during auto-scrolling.

**Internal**
* Updated `SelectionController` to track registered items, enabling `selectAll()` functionality for visible items without manual list management.

## [0.0.1] - 2025-12-19
### Added
- Initial public release of `selection_marquee`.
- Marquee/drag-to-select widget with mouse and touch support (`SelectionMarquee`).
- `SelectionController` API and `SelectableItem` helper for wiring items.
- Edge auto-scroll with configurable speed, edge zone fraction, minimum factor, and two modes (`jump`, `animate`).
- `SelectionDecoration` to customize selection appearance: `solid`, `dashed`, `dotted`, `marchingAnts`, `borderWidth`, `dashLength`, `gapLength`, `borderRadius`, and `marchingSpeed`.
- Example app with live tuning controls for auto-scroll and selection decoration, plus a collapsible sidebar showing estimated velocity.
- README, LICENSE (MIT), and a GitHub Actions workflow to deploy the example web build to GitHub Pages.
