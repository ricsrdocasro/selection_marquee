# Changelog

All notable changes to this project will be documented in this file.

The format is based on "Keep a Changelog" and this project adheres to
Semantic Versioning.

## [0.0.1] - 2025-12-19
### Added
- Initial public release of `selection_marquee`.
- Marquee/drag-to-select widget with mouse and touch support (`SelectionMarquee`).
- `SelectionController` API and `SelectableItem` helper for wiring items.
- Edge auto-scroll with configurable speed, edge zone fraction, minimum factor, and two modes (`jump`, `animate`).
- `SelectionDecoration` to customize selection appearance: `solid`, `dashed`, `dotted`, `marchingAnts`, `borderWidth`, `dashLength`, `gapLength`, `borderRadius`, and `marchingSpeed`.
- Example app with live tuning controls for auto-scroll and selection decoration, plus a collapsible sidebar showing estimated velocity.
- README, LICENSE (MIT), and a GitHub Actions workflow to deploy the example web build to GitHub Pages.
