# Changelog

All notable changes to iKhalacy are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
While the major version is `0`, minor bumps may include breaking changes.

## [Unreleased]

### Added
- Nothing yet.

## [0.2.0] - 2026-09-01

The explorer works: open a folder, browse it, click a file and read it.

### Added
- Open a project folder via `File ▸ Open Folder…` (⌘O), with `Close Folder`
  (⇧⌘W) alongside it.
- File tree in the explorer — nested folders, folders sorted before files,
  natural ordering, and a per-file-type SF Symbol.
- Read-only file viewing in the editor pane, with monospaced text and clear
  refusals for binary files and files over 4 MB.
- The open folder and selected file are restored on next launch.
- `Examples/SampleProject/` — a mixed-language fixture for browsing.

### Changed
- The terminal pane no longer expands greedily, so the editor/terminal split
  honours its intended ~200pt terminal height instead of dividing evenly.

### Known limitations
- The tree loads eagerly, capped at 20,000 entries; `.git`, `node_modules`,
  `.build`, `DerivedData` and `__pycache__` are skipped. Other dotfiles show.
- The editor is read-only. Editing and saving arrive in 0.3.

## [0.1.0] - 2026-09-01

Initial scaffold. The app launches and shows the three-pane layout; the panes
themselves are placeholders.

### Added
- XcodeGen-based build configuration: `project.yml` is the source of truth and
  `iKhalacy.xcodeproj` is generated and gitignored.
- `Scripts/bootstrap.sh` to regenerate the Xcode project.
- Three-pane window shell — explorer, editor, terminal — with native resizable
  splitters.
- `Workspace` observable model holding the open folder and the active file.
- Swift Testing target with coverage enabled in the shared scheme.
- README documenting architecture decisions, layout, and roadmap.
- MIT license.

### Notes
- Targets macOS 15.0 and later; Swift 6 language mode with complete strict
  concurrency checking; warnings are treated as errors.
- The app is intentionally unsandboxed so it can spawn a shell and open
  arbitrary folders. Hardened Runtime is enabled.

[Unreleased]: https://github.com/ayush27prasad/iKhalacy/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/ayush27prasad/iKhalacy/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ayush27prasad/iKhalacy/releases/tag/v0.1.0
