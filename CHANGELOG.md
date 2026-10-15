# Changelog

All notable changes to iKhalacy are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
While the major version is `0`, minor bumps may include breaking changes.

## [Unreleased]

### Fixed
- Selecting a file that can't be opened — binary, over 4 MB, or unreadable —
  explains why in the editor pane again. 0.3 dropped the explanation 0.2 showed,
  so the click appeared to do nothing.
- Files that aren't UTF-8 are refused instead of corrupted. A UTF-16 fallback
  accepted almost any bytes, so a Latin-1 or Windows-1252 file opened as
  mojibake, and ⌘S — enabled even with no edits — overwrote the original with
  it. UTF-16 files are refused too; they only opened when they happened to
  contain no zero bytes, and were silently saved back as UTF-8.
- Saving keeps a UTF-8 byte-order mark if the file had one, rather than
  stripping it.
- A failed save is reported in an alert. ⌘S used to discard the error, so a save
  into a deleted folder or a read-only location looked like it had worked.
- A shell that exits — `exit`, ⌃D — closes its terminal tab, as Terminal.app
  does, instead of leaving a dead tab behind. One that exits with an error
  keeps its tab and output, marked `[Process completed]`, so the error can
  still be read.

## [0.3.0] - 2026-09-01

All three panes are live: browse, edit in tabs, run a shell.

### Added
- Tabbed editing with VS Code's preview model. A single click in the explorer
  opens the file in an italic preview tab that the next single click reuses; a
  double click pins it as a regular tab. A preview with unsaved edits is kept
  rather than replaced. Reopening an already-open file focuses its tab rather
  than duplicating it, and closing the active tab focuses the one to its left.
- A real editor — [CodeEditSourceEditor](https://github.com/CodeEditApp/CodeEditSourceEditor)
  replaces the read-only `TextEditor`, bringing a gutter, indentation rules and
  bracket handling.
- Syntax highlighting via tree-sitter, with the grammar chosen per file by
  `CodeLanguage.detectLanguageFrom(url:)` and falling back to shebang or
  modeline detection for extensionless files.
- Editing and saving. ⌘S writes the file; tabs show a dot while dirty and a
  close button on hover. ⌘W closes the active tab.
- A working terminal — [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
  running your login shell on a PTY, started in the open project folder (or your
  home directory when no folder is open). Opening a different folder starts a
  fresh shell rooted there.
- Open tabs and the active tab are restored on next launch, alongside the folder.
- An app icon, generated from `Design/logo.ai` by `Scripts/make-icon.sh` as a
  full-bleed square that macOS 26 shapes itself (`ICON_ROUNDED=1` for a
  pre-masked one).
- `terminal.plainShell` default, to start the shell without user config when a
  prompt misbehaves.
- Multiple terminal sessions in tabs. ⌘T or the + button opens one, shells stay
  alive in the background across tab switches, and double-clicking a tab
  renames it. ⌘W closes the terminal tab when the terminal has focus and the
  editor tab otherwise.
- Opening projects from Finder: "Open With ▸ iKhalacy" on a folder, dragging a
  folder onto the icon, or `open -a iKhalacy <path>`. Passing a file opens its
  enclosing folder with the file in a tab. Registered as an `Alternate` handler
  for `public.folder`, so Finder stays the default.
- A light appearance the app is pinned to, and an accent colour taken from the
  logo. Editor syntax colours are Xcode's defaults.

### Changed
- The terminal spans the full window width beneath the explorer and editor,
  rather than being confined to the column right of the sidebar.
- Selecting a file in the explorer that is already open now switches to its
  tab, instead of leaving the editor on the previous file.
- `Workspace.activeFileURL` became `selectedFileURL`, the explorer's highlighted
  row; open documents live in a `DocumentStore` on `Workspace.editor`.

### Fixed
- Terminal resizes are coalesced before reaching the PTY. Animating the sidebar
  raised `SIGWINCH` once per intermediate width, so prompts that repaint on it
  (Powerlevel10k, Starship) left a stack of half-drawn prompts behind.
- Session restore ran from a task attached to the explorer's state-switching
  view, so loading the tree tore that view down and cancelled the restore before
  it reopened tabs. It now runs from the window shell, whose identity is stable.

### Known limitations
- Closing a tab or the app discards unsaved changes without prompting.
- Tabs cannot be reordered or dragged, and there is no find-in-file.
- The explorer doesn't notice files created, renamed or deleted outside the app
  until the folder is reopened, and open tabs aren't reloaded when their file
  changes on disk.
- The first build clones ~43 tree-sitter grammars and takes several minutes.

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

[Unreleased]: https://github.com/ayush27prasad/iKhalacy/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/ayush27prasad/iKhalacy/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/ayush27prasad/iKhalacy/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ayush27prasad/iKhalacy/releases/tag/v0.1.0
