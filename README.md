# iKhalacy

A lightweight, native macOS code editor: a file tree on the left, the active file
in the middle, and a real shell at the bottom — in one window.

Built with SwiftUI and AppKit, for macOS 15 and later.

> **Status: alpha.** All three panes work: browse a project, edit files in tabs
> with syntax highlighting, and run a real shell below. See [Roadmap](#roadmap)
> and [CHANGELOG.md](CHANGELOG.md).

## Why

The goal is not to reimplement VS Code. It is an aggregated view of three things
that are normally three apps: browse a project, read and edit a text file, and run
commands against it — without Electron, and without a plugin ecosystem.

Target file types are text and code: Markdown, Python, JavaScript, Java, Swift,
and similar. Binary formats are out of scope. Files must be UTF-8 — other
encodings are refused rather than risk being rewritten as UTF-8 on save.

## Requirements

| | |
|---|---|
| macOS | 15.0 (Sequoia) or later |
| Xcode | 26.0 or later |
| Swift | 6.0 language mode, strict concurrency |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | `brew install xcodegen` |

### Dependencies

Resolved by SwiftPM; declared in [`project.yml`](project.yml).

| Package | Licence | Why |
|---|---|---|
| [CodeEditSourceEditor](https://github.com/CodeEditApp/CodeEditSourceEditor) | MIT | Source editor: tree-sitter highlighting, gutter, indentation |
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | MIT | VT100/xterm emulator for the terminal pane |

The first build clones ~43 tree-sitter grammars via CodeEditLanguages and takes
several minutes. Later builds are incremental.

## Getting started

```sh
git clone git@github.com:ayush27prasad/iKhalacy.git
cd iKhalacy
./Scripts/bootstrap.sh
open iKhalacy.xcodeproj
```

`iKhalacy.xcodeproj` is **generated and gitignored**. Never edit it by hand and
never commit it — edit [`project.yml`](project.yml) and re-run the bootstrap
script. This keeps the repository free of `project.pbxproj` merge conflicts.

Command-line build and test:

```sh
xcodebuild -scheme iKhalacy -destination 'platform=macOS' build
xcodebuild -scheme iKhalacy -destination 'platform=macOS' test
```

## Artwork and appearance

The app icon is generated from `Design/logo.ai`. To change it, replace that file
and run:

```sh
./Scripts/make-icon.sh          # any .ai / .pdf / .png / .jpg
./Scripts/bootstrap.sh          # only needed the first time icons appear
```

The script rasterises a 1024 master and emits all ten macOS sizes and their
`Contents.json`. The master is a full-bleed opaque square: macOS 26 applies its
own icon shape, and an icon that brings its own rounded corners and transparency
gets a desaturated fallback rendering instead. `ICON_ROUNDED=1` restores the
continuous-corner mask for older systems. It crops to a centred square by
default so the art reaches every edge; `MODE=fit ./Scripts/make-icon.sh`
letterboxes instead, cropping nothing.

The asset catalogue's accent colour is taken from the artwork, so sidebar
selection and controls match the icon. The editor keeps Xcode's default syntax
palette. The app is pinned to light appearance (`NSApp.appearance = .aqua`); the
dark palette stays in the source for whenever an appearance preference lands.

> `Design/logo.ai` is third-party stock artwork. Confirm its licence permits
> redistribution before publishing binaries from this repository.

## Terminal

The pane runs your login shell (`$SHELL`, falling back to `/bin/zsh`) on a PTY,
started in the open project folder, so your profile, `PATH` and prompt all apply.

⌘T or the tab bar's + button opens another session. Every shell stays alive in
the background — switching tabs hides a view rather than respawning the process.
Double-click a tab to rename it. Opening a different project folder closes the
shells and starts a fresh one rooted there.

Resizes are coalesced before they reach the PTY. Every layout pass otherwise
raises `SIGWINCH`, and animating the sidebar open or closed walks through dozens
of widths — prompts that repaint on `SIGWINCH`, such as Powerlevel10k or
Starship, redraw once per width and leave a stack of half-drawn prompts. The
terminal is resized only once the width has held steady for 150 ms.

If a prompt still misbehaves, start the shell without your config:

```sh
defaults write in.ayush27prasad.iKhalacy terminal.plainShell -bool YES
```

That runs `$SHELL -f` — no `.zshrc`, no framework, a stock prompt. You lose the
aliases and `PATH` your profile sets, so it is a diagnostic rather than a
default. Undo with `defaults delete in.ayush27prasad.iKhalacy terminal.plainShell`.

## Troubleshooting the first build

Three things bite on a fresh machine. All are one-time.

**`CodeEditLanguages` clone fails with `RPC failed … Connection reset by peer`.**
That repository carries ~1.7 GB of history because it vendors every grammar, and
the full mirror clone SwiftPM attempts is fragile. Pre-seed SwiftPM's cache with
a partial clone instead — 31 MB rather than 1.7 GB:

```sh
CACHE=~/Library/Caches/org.swift.swiftpm/repositories/CodeEditLanguages-69361bcd
git clone --mirror --filter=blob:none \
    https://github.com/CodeEditApp/CodeEditLanguages.git "$CACHE"
git -C "$CACHE" archive --format=tar 0.1.20 > /dev/null   # backfill the tag's blobs
```

**`cannot execute tool 'metal' due to missing Metal Toolchain`.** A dependency
ships a shader. Run `xcodebuild -downloadComponent MetalToolchain` (≈688 MB).

**`Running SwiftLint for CodeEditSourceEditor` fails.** That is SwiftLint linting
CodeEdit's own sources via a build-tool plugin, not our code. It does not block
the build. Pass `-skipPackagePluginValidation` to quieten plugin validation.

## Layout

```
iKhalacy/
├── project.yml               # Single source of truth for the Xcode project
├── Scripts/
│   ├── bootstrap.sh          # Regenerates the .xcodeproj
│   └── make-icon.sh          # Regenerates the app icon from Design/logo.ai
├── Design/logo.ai            # Icon source artwork
├── Sources/iKhalacy/
│   ├── App/                  # Entry point and app-level scene wiring
│   ├── Workspace/            # Shared state + the three-pane window shell
│   ├── Features/
│   │   ├── Explorer/         # Left pane — file tree
│   │   ├── Editor/           # Middle pane — active file
│   │   └── Terminal/         # Bottom pane — shell session
│   └── Resources/            # Info.plist, asset catalog
├── Examples/SampleProject/   # Mixed-language fixture for manual browsing
└── Tests/iKhalacyTests/      # Swift Testing suites
```

Each pane is a self-contained feature folder. Panes never reach into each other;
they coordinate only through the shared `Workspace` model, which owns the open
folder and the active file. Adding a feature means adding a folder under
`Features/` — not threading state through the view hierarchy.

## Trying it

Press ⌘O and pick any folder — or point it at `Examples/SampleProject/`, a small
mixed-language tree kept in the repo for exactly this.

| | |
|---|---|
| Open a folder | ⌘O |
| Preview a file | click it in the explorer |
| Keep a file open in its own tab | double-click it in the explorer |
| Save | ⌘S |
| New terminal | ⌘T |
| Rename a terminal | double-click its tab |
| Close tab | ⌘W — closes the terminal tab if the terminal has focus, otherwise the editor tab |
| Close folder | ⇧⌘W |

You can also open a project from Finder — right-click a folder and pick
**Open With ▸ iKhalacy**, drag a folder onto the app icon, or run
`open -a iKhalacy <path>`. Handing it a *file* opens that file's enclosing
folder with the file already in a tab. The app registers as an `Alternate`
handler for `public.folder`, so it never displaces Finder as the default.

For Finder to keep listing it, the app has to live somewhere permanent —
`/Applications` — rather than in `DerivedData`, which Xcode discards.

Tabs follow VS Code's preview model. A single click opens the file in a
*preview* tab, shown in italics, which the next single click reuses — so
browsing a repository doesn't leave forty tabs behind. Double-clicking pins it
as a regular tab. A preview with unsaved edits is never replaced; it is kept as
a regular tab and the next file opens alongside it.

The terminal below starts a login shell in the project folder. Your open folder,
tabs, and active tab are all restored next launch.

## Architecture decisions

**Not sandboxed.** The app spawns a login shell and opens arbitrary user-chosen
folders. Neither is possible under App Sandbox in any meaningful form, so
`ENABLE_APP_SANDBOX` is `NO`. Consequence: iKhalacy cannot ship on the Mac App
Store. Distribution, if any, would be a notarized `.app` with Hardened Runtime,
which is already enabled.

**The terminal is emulated, not embedded.** macOS provides no supported API to
host another application's window inside your own, so Terminal.app cannot be
placed in the bottom pane. A genuine terminal means a pseudo-terminal (PTY)
running your login shell, plus a VT100/xterm emulator that interprets the escape
sequences programs like `vim`, `htop`, and `git log` emit. iKhalacy will use
[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (MIT) for the emulator —
pure Swift, no native dependencies, and mature enough that full-screen terminal
apps work correctly from the start. We own only the pane, its lifecycle, and the
integration with the open folder.

**The tree loads eagerly.** Lazy per-expansion loading needs expansion callbacks
`OutlineGroup` does not provide, so the whole tree is walked on open. A skip list
(`.git`, `node_modules`, `.build`, `DerivedData`, `__pycache__`) and a 20,000-entry
budget keep that bounded; the explorer says so when the budget is hit. Other
dotfiles stay visible — `.gitignore` and `.env` are files people open.

**The editor is CodeEditSourceEditor, not a hand-rolled text view.** It is an
AppKit source editor with tree-sitter highlighting, a gutter, and indentation
rules already solved. Writing an equivalent on `NSTextView` plus SwiftTreeSitter
is weeks of work for a worse result. The cost is real: it pulls in
CodeEditTextView, CodeEditLanguages, CodeEditSymbols and TextFormation, and the
bundled grammars dominate the app's size. Highlighting comes free with it —
`CodeLanguage.detectLanguageFrom(url:)` picks the grammar per file, falling back
to a shebang or modeline for extensionless files.

**Generated project files.** `project.yml` is checked in; the `.xcodeproj` is
not. The cost is one Homebrew dependency; the benefit is a reviewable diff every
time the project structure changes.

## Roadmap

Ordered, and deliberately narrow. Each milestone is independently usable.

- [x] **0.1** — Project scaffold, build system, three-pane window shell
- [x] **0.2** — Explorer: open a folder, browse the tree, persist the selection
- [x] **0.3** — Editor tabs, editing and saving; tree-sitter highlighting; a
  PTY terminal rooted at the open folder
- [ ] **0.4** — Find in file, pane show/hide, unsaved-changes prompts, and
  picking up files created, changed or deleted outside the app

Explicit non-goals: extensions, debugging, language servers, remote development,
Git integration, split editors.

## Contributing

- Run `./Scripts/bootstrap.sh` after any change that adds or removes files.
- Warnings are errors. Swift 6 strict concurrency is on and stays on.
- Comments explain *why*, not *what*. Prefer clear naming over commentary.
- Never edit `iKhalacy.xcodeproj`; edit `project.yml`.

## License

[MIT](LICENSE) © 2026 Ayush Prasad
