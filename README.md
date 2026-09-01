# iKhalacy

A lightweight, native macOS code editor: a file tree on the left, the active file
in the middle, and a real shell at the bottom — in one window.

Built with SwiftUI and AppKit, for macOS 15 and later.

> **Status: pre-alpha.** The window shell and build system exist. The three panes
> are placeholders. See [Roadmap](#roadmap) and [CHANGELOG.md](CHANGELOG.md).

## Why

The goal is not to reimplement VS Code. It is an aggregated view of three things
that are normally three apps: browse a project, read and edit a text file, and run
commands against it — without Electron, and without a plugin ecosystem.

Target file types are text and code: Markdown, Python, JavaScript, Java, Swift,
and similar. Binary formats are out of scope.

## Requirements

| | |
|---|---|
| macOS | 15.0 (Sequoia) or later |
| Xcode | 26.0 or later |
| Swift | 6.0 language mode, strict concurrency |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | `brew install xcodegen` |

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

## Layout

```
iKhalacy/
├── project.yml               # Single source of truth for the Xcode project
├── Scripts/bootstrap.sh      # Regenerates the .xcodeproj
├── Sources/iKhalacy/
│   ├── App/                  # Entry point and app-level scene wiring
│   ├── Workspace/            # Shared state + the three-pane window shell
│   ├── Features/
│   │   ├── Explorer/         # Left pane — file tree
│   │   ├── Editor/           # Middle pane — active file
│   │   └── Terminal/         # Bottom pane — shell session
│   └── Resources/            # Info.plist, asset catalog
└── Tests/iKhalacyTests/      # Swift Testing suites
```

Each pane is a self-contained feature folder. Panes never reach into each other;
they coordinate only through the shared `Workspace` model, which owns the open
folder and the active file. Adding a feature means adding a folder under
`Features/` — not threading state through the view hierarchy.

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

**Syntax highlighting is deferred.** v0.1 renders plain monospaced text. The
engine choice — incremental parsing versus pattern matching — is deliberately
left open until file loading and the terminal are solid.

**Generated project files.** `project.yml` is checked in; the `.xcodeproj` is
not. The cost is one Homebrew dependency; the benefit is a reviewable diff every
time the project structure changes.

## Roadmap

Ordered, and deliberately narrow. Each milestone is independently usable.

- [x] **0.1** — Project scaffold, build system, three-pane window shell
- [ ] **0.2** — Explorer: open a folder, browse the tree, persist the selection
- [ ] **0.3** — Editor: load, display, and save text files
- [ ] **0.4** — Terminal: PTY + SwiftTerm, rooted at the open folder
- [ ] **0.5** — Syntax highlighting
- [ ] **0.6** — Tabs, find in file, pane show/hide

Explicit non-goals: extensions, debugging, language servers, remote development,
Git integration, split editors.

## Contributing

- Run `./Scripts/bootstrap.sh` after any change that adds or removes files.
- Warnings are errors. Swift 6 strict concurrency is on and stays on.
- Comments explain *why*, not *what*. Prefer clear naming over commentary.
- Never edit `iKhalacy.xcodeproj`; edit `project.yml`.

## License

[MIT](LICENSE) © 2026 Ayush Prasad
