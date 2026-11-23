# larp

**Your Local Agent Review Pal.** A lightweight, native macOS IDE for working
alongside Claude Code and Codex — built for reviewing and walking through the
code your agent writes, with a sidecar chat that works for the agent rather
than competing with it.

Built with SwiftUI and AppKit, for macOS 15 and later.

> **Status: alpha.** The foundation works — browse a project, edit files in tabs
> with syntax highlighting, and run your agent in a real terminal below. The
> review, walkthrough and sidecar features are next; see [Roadmap](#roadmap)
> and [CHANGELOG.md](CHANGELOG.md). larp grew out of an editor called iKhalacy,
> and the history before 0.4 carries that name.

## Why

Coding agents now write most of the diff. The hard part has moved from typing
code to understanding it: what the agent changed, why, and whether it's right.
larp is built for that half of the job.

- **Review first.** The main view is what your agent changed, not a blank
  editor.
- **Walkthroughs.** Step through a change in a sensible order instead of
  reading files alphabetically.
- **A sidecar, not a second agent.** The chat beside the review answers your
  questions and runs errands for the master agent — Claude Code or Codex —
  which stays in charge of the code.
- **Local-first.** No larp server and no larp account. It runs next to the
  agents you already use, in your terminal, with your own setup.
- **Lightweight.** Native SwiftUI and AppKit — no Electron, no embedded browser.
  The budget is under 150 MB with a project, a few tabs, two terminals and the
  chat open, measured with `footprint`. Today's build uses about 71 MB.

Target file types are text and code: Markdown, Python, JavaScript, Java, Swift,
and similar. Binary formats are out of scope. UTF-8, UTF-16 (with a byte-order
mark) and Windows 1252 / Latin-1 files open and save in their own encoding,
byte for byte; the status bar shows which. A save that would need a character
the file's encoding can't hold is refused rather than written lossily.

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
| [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) | MIT | Renders markdown with native SwiftUI views — no web view |

The first build clones ~43 tree-sitter grammars via CodeEditLanguages and takes
several minutes. Later builds are incremental.

## Getting started

```sh
git clone git@github.com:ayush27prasad/larp.git
cd larp
./Scripts/bootstrap.sh
open Larp.xcodeproj
```

`Larp.xcodeproj` is **generated and gitignored**. Never edit it by hand and
never commit it — edit [`project.yml`](project.yml) and re-run the bootstrap
script. This keeps the repository free of `project.pbxproj` merge conflicts.

The one committed file inside it is SwiftPM's lockfile,
`project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, which pins every
dependency so each clone builds the same versions. XcodeGen leaves it alone.

Command-line build and test:

```sh
xcodebuild -scheme Larp -destination 'platform=macOS' build
xcodebuild -scheme Larp -destination 'platform=macOS' test
```

## Artwork and appearance

larp has no logo yet, so the app shows the default macOS icon. iKhalacy's
stock-art logo was left out of this repository, history included, because its
licence was never confirmed to allow public redistribution. Once larp has a
logo, put it at `Design/logo.ai` and run:

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

The window has no title bar. The sidebar header — window buttons, project name,
sidebar toggle — and the editor's tab strip are its top edge, and their empty
parts drag the window. With the sidebar hidden, the toggle moves to the start
of the tab strip.

**View ▸ Appearance** picks System, Light or Dark; System follows macOS.

- **Light** is Apple-calm: white content on apple.com's `#F5F5F7` greys, Apple
  blue (`#0071E3`) as the accent, and Xcode's default syntax colours.
- **Dark** is neon on true black, after Synthwave '84 and Cyberpunk themes on a
  Warp-style black base: neon pink accent with a glow on the active tab, a green
  caret, and syntax in pink keywords, green strings, cyan functions, violet
  types and amber numbers.

Every colour lives in `Design/Chrome.swift` (panes) and
`Features/Editor/EditorTheme+Larp.swift` (syntax), so the editor, markdown
preview and terminal share one surface. larp draws its own accent explicitly,
because macOS replaces an app's accent colour with the system accent unless
that is set to Multicolor; system controls such as the sidebar selection follow
the system accent, as Mac apps should. The terminal keeps the standard ANSI
colours, since prompts like Powerlevel10k are designed against them.

Markdown opens rendered — natively, with no web view — and ⇧⌘V or the
Preview/Source switch above it flips to the source. Links to other files in
the project open in larp.

## Terminal

The pane runs your login shell (`$SHELL`, falling back to `/bin/zsh`) on a PTY,
started in the open project folder, so your profile, `PATH` and prompt all apply.

⌘T or the tab bar's + button opens another session. Every shell stays alive in
the background — switching tabs hides a view rather than respawning the process.
Double-click a tab to rename it. Exiting a shell closes its tab; if it exits
with an error the tab stays open so you can read why. Opening a different
project folder closes the shells and starts a fresh one rooted there.

Resizes are coalesced before they reach the PTY. Every layout pass otherwise
raises `SIGWINCH`, and animating the sidebar open or closed walks through dozens
of widths — prompts that repaint on `SIGWINCH`, such as Powerlevel10k or
Starship, redraw once per width and leave a stack of half-drawn prompts. The
terminal is resized only once the width has held steady for 150 ms.

If a prompt still misbehaves, start the shell without your config:

```sh
defaults write in.ayush27prasad.larp terminal.plainShell -bool YES
```

That runs `$SHELL -f` — no `.zshrc`, no framework, a stock prompt. You lose the
aliases and `PATH` your profile sets, so it is a diagnostic rather than a
default. Undo with `defaults delete in.ayush27prasad.larp terminal.plainShell`.

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
larp/
├── project.yml               # Single source of truth for the Xcode project
├── Scripts/
│   ├── bootstrap.sh          # Regenerates the .xcodeproj
│   └── make-icon.sh          # Regenerates the app icon from Design/logo.ai
├── Sources/Larp/
│   ├── App/                  # Entry point, scene wiring, appearance
│   ├── Design/               # Shared colours, tab styling, file icons
│   ├── Workspace/            # Shared state + the three-pane window shell
│   ├── Features/
│   │   ├── Explorer/         # Left pane — file tree
│   │   ├── Editor/           # Middle pane — active file
│   │   └── Terminal/         # Bottom pane — shell session
│   └── Resources/            # Info.plist, asset catalog
├── Examples/
│   ├── Production/           # Orderly: the realistic project larp is tested on
│   └── SampleProject/        # Tiny mixed-language fixture
└── Tests/LarpTests/          # Swift Testing suites
```

Each pane is a self-contained feature folder. Panes never reach into each other;
they coordinate only through the shared `Workspace` model, which owns the open
folder and the active file. Adding a feature means adding a folder under
`Features/` — not threading state through the view hierarchy.

## Trying it

Press ⌘O and pick any folder — or point it at `Examples/Production/`. That is
Orderly, a realistic multi-language monorepo (Python, Go, Java, Rust,
TypeScript, Swift, Kotlin, SQL) kept here as the project larp is tested on; its
README lists which larp features each part exercises.

| | |
|---|---|
| Open a folder | ⌘O |
| Preview a file | click it in the explorer |
| Keep a file open in its own tab | double-click it in the explorer |
| Expand or collapse a folder | double-click it, or click its arrow |
| Save | ⌘S |
| New terminal | ⌘T |
| Rename a terminal | double-click its tab |
| Resize the terminal | drag the line above it — the height is remembered |
| Collapse or expand the terminal | ⌘J, or the chevron at the right of its tabs |
| Show or hide the sidebar | ⌃⌘S, or the sidebar button; drag its edge to resize |
| Move the window | drag the empty part of the tab strip or the sidebar header |
| Markdown preview / source | ⇧⌘V |
| Go to definition | ⌘-click a name — several definitions offer a choice; library names open the library's source, read-only |
| Find in the file | ⌘F — ↩ / ⇧↩ or ⌘G / ⇧⌘G to move, esc to close |
| Find and replace | ⌥⌘F — regex replacements take `$1` groups |
| Match case / whole words / regex | ⌥⌘C / ⌥⌘W / ⌥⌘R, in either find |
| Find in files | ⇧⌘F — ↑↓ to move, ↩ to open at the match |
| Zoom the whole app | ⌘+ / ⌘− / ⌘0, 90%–150% — remembered |
| Zoom one file or terminal | ⌘-scroll or pinch over it, 50%–300% |
| Light, dark or system appearance | View ▸ Appearance |
| Close tab | ⌘W — closes the terminal tab if the terminal has focus, otherwise the editor tab |
| Close folder | ⇧⌘W |

You can also open a project from Finder — right-click a folder and pick
**Open With ▸ Larp**, drag a folder onto the app icon, or run
`open -a Larp <path>`. Handing it a *file* opens that file's enclosing
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
`ENABLE_APP_SANDBOX` is `NO`. Consequence: larp cannot ship on the Mac App
Store. Distribution, if any, would be a notarized `.app` with Hardened Runtime,
which is already enabled.

**The terminal is emulated, not embedded.** macOS provides no supported API to
host another application's window inside your own, so Terminal.app cannot be
placed in the bottom pane. A genuine terminal means a pseudo-terminal (PTY)
running your login shell, plus a VT100/xterm emulator that interprets the escape
sequences programs like `vim`, `htop`, and `git log` emit. larp uses
[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (MIT) for the emulator —
pure Swift, no native dependencies, and mature enough that full-screen terminal
apps work correctly from the start. We own only the pane, its lifecycle, and the
integration with the open folder.

**The tree loads eagerly.** Lazy per-expansion loading needs expansion callbacks
`OutlineGroup` does not provide, so the whole tree is walked on open. A skip list
(`.git`, `node_modules`, `.build`, `DerivedData`, `__pycache__`, Python
virtualenvs `.venv`/`venv` and tool caches) and a 20,000-entry
budget keep that bounded; the explorer says so when the budget is hit. Other
dotfiles stay visible — `.gitignore` and `.env` are files people open.

**The editor is CodeEditSourceEditor, not a hand-rolled text view.** It is an
AppKit source editor with tree-sitter highlighting, a gutter, and indentation
rules already solved. Writing an equivalent on `NSTextView` plus SwiftTreeSitter
is weeks of work for a worse result. The cost is real: it pulls in
CodeEditTextView, CodeEditLanguages, CodeEditSymbols and TextFormation, and the
bundled grammars dominate the app's size. Highlighting comes free with it —
`CodeLanguage.detectLanguageFrom(url:)` picks the grammar per file, falling back
to a shebang or modeline for extensionless files. For everyday files it leaves
as plain text, `LanguageDetection` borrows a close grammar: Makefiles and `.env`
as shell, XML and plists as HTML, `.jsonc` as JSON, `.ini` as TOML. Approximate
highlighting beats none. Protocol Buffers still has no grammar.

**No web views.** The chat and the diff views will be rendered natively, never
in a `WKWebView`. Each web view runs its own web-content process, which alone
can cost as much memory as the rest of the app, and the budget in [Why](#why)
leaves no room for it. Long views — diffs, scrollback — only draw what is on
screen.

**All Swift, no Rust core.** A Rust core behind a SwiftUI shell was considered
for memory and rejected: Swift and Rust are both native with no garbage
collector, so the same data costs the same in either, and most of the footprint
is AppKit and SwiftUI themselves, which stay. A Rust core would only pay off
alongside separate Linux and Windows UIs. A specific Rust library with no Swift
equivalent can still come in behind a narrow interface.

**Go to definition is name-based, from tree-sitter.** Opening a folder parses
every file in the background with the grammars larp already ships, recording
where each function, type, method and top-level constant is defined
(`Features/Navigation/SymbolQueries.swift`, per language); saving re-indexes
that file. ⌘-click looks the name up. Matching by name, as GitHub's code
navigation does, means a common name can offer several candidates — the price
of needing no language server. Opt-in language servers will give exact answers
later and take over where enabled.

A name the project doesn't define is looked up in library source, on demand
(`LibraryLocator`): the file's imports, plus the project's manifests, point at
a few packages — a virtualenv's `site-packages` and the Python standard library
beside it, `node_modules` and `@types`, Go's standard library and module cache
(by `go.mod` version, or `vendor/`), Cargo's registry (by `Cargo.lock` version)
and rustup's `rust-src`. Only files containing the name are parsed, at most
4,000 per lookup, and the last 32 answers are cached. Library files open
read-only. Java and Kotlin libraries are compiled jars with no source to find;
those wait for language servers.

**Generated project files.** `project.yml` is checked in; the `.xcodeproj` is
not. The cost is one Homebrew dependency; the benefit is a reviewable diff every
time the project structure changes.

## Roadmap

Ordered, and deliberately narrow. Each milestone is independently usable.

- [x] **0.1** — Project scaffold, build system, three-pane window shell
- [x] **0.2** — Explorer: open a folder, browse the tree, persist the selection
- [x] **0.3** — Editor tabs, editing and saving; tree-sitter highlighting; a
  PTY terminal rooted at the open folder
- [ ] **0.4** — Keeping up with the agent: the tree and open tabs pick up files
  created, changed or deleted outside the app, and unsaved edits are never
  silently discarded or overwritten. Also find in file and pane show/hide.
- [ ] **0.5** — Review: what the agent changed, file by file and hunk by hunk.

After that, in rough order: walkthroughs, the sidecar chat, and deeper
integration with Claude Code and Codex. These get specified as they come up.

The full feature list — IntelliJ-style navigation and refactoring via opt-in
language servers, the agent harness and walkthroughs, manager mode, and modules
for databases, diagrams and JSON — lives in [docs/PRODUCT.md](docs/PRODUCT.md),
with the status of each. larp is macOS only, and it is not another coding agent:
the sidecar works for the one you already run.

## Contributing

- Run `./Scripts/bootstrap.sh` after any change that adds or removes files.
- Warnings are errors. Swift 6 strict concurrency is on and stays on.
- Comments explain *why*, not *what*. Prefer clear naming over commentary.
- Never edit `Larp.xcodeproj`; edit `project.yml`.

## License

[MIT](LICENSE) © 2026 Ayush Prasad
