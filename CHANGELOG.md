# Changelog

All notable Y-Dock release changes are tracked here.

## v0.5.0 - 2026-06-22

- Renamed the user-facing app from DockWindowPreview to Y-Dock.
- Updated the app bundle display name, settings UI, menus, permission prompts, logs, README, and release packaging name.
- Kept the existing bundle identifier and GitHub repository name to preserve permissions, update checks, and project continuity.

## v0.4.8 - 2026-06-22

- Adjusted the app icon artwork scale so it no longer appears oversized in Launchpad.
- Regenerated the bundled `.icns` and README logo assets from the inset icon source.
- Documented the icon inset requirement for future maintainers.

## v0.4.7 - 2026-06-22

- Replaced the app icon with the new supplied logo and regenerated the bundled `.icns`.
- Updated the GitHub README logo asset and release/download links.
- Added `AI_MAINTENANCE.me` for future AI maintainers, including project architecture, build verification, packaging, and GitHub release flow.
- Added this changelog and linked it from the README.

## v0.4.6 - 2026-06-22

- Made DockWindowPreview a true menu bar/background utility by hiding it from Dock and Cmd-Tab.
- Added cancellable preview prewarming while hovering Dock candidates.
- Increased short-term thumbnail cache lifetime and capacity for smoother repeated Dock sweeps.
- Invalidated preview caches when target apps terminate.
- Redesigned the menu bar template icon with a taller stacked-window silhouette.
