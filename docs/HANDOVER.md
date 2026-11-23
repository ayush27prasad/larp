# Handover

Written 2026-11-23 for the next Claude session on larp. Read this after
[CLAUDE.md](../CLAUDE.md), then [PRODUCT.md](PRODUCT.md) (what larp is and
the status of each feature), then the README. This file covers what those
don't: where the work stands, how it was verified, what bit us, and how each
remaining feature should plug in. Keep it current, or delete sections once
they stop being true.

## 1. Where things stand

**Branches.** Nothing since the rename has been merged to `main`
(`cf3aca4`). Every feature was built as its own commit on a chain of feature
branches, each cut from the one before. **`develop` holds all of them**, plus
`docs/product-reference` merged in, and is the branch to review, merge and
continue from. The per-feature branches are still on the remote, but each is
just a prefix of `develop`:

```
main ─ feature/explorer-folders ─ ui-overhaul ─ frameless-window ─ zoom ─
encodings ─ zoom-limits ─ search ─ find-bar ─ find-polish ─ no-stock-find ─
sidebar-animation ─ terminal-collapse ─ fix/editor-gutter-clip ─
symbol-index ─ library-definitions ─┐
docs/product-reference ─────────────┴─ develop
```

The user merges, never the agent (see CLAUDE.md, *How features ship*). New work
branches off `develop` until it lands on `main`.

**Uncommitted on purpose:** `Examples/Production/services/orders-api/app/pricing.py`
has the user's own experiment (`TAX_RATE = 0.85`). Never commit or revert it.

**Health.** On `develop`: build clean with warnings as errors under Swift 6
strict concurrency; 137 tests pass. Footprint with Orderly open and indexed: 77 MB
(Debug build), against the 150 MB budget.

## 2. What exists now (all under `[Unreleased]` in CHANGELOG.md)

| Area | What works |
|---|---|
| Window | Frameless, with no title bar. The sidebar has its own header (traffic-light spacer, folder icon and project name, toggle). The sidebar animates in and out (⌃⌘S). |
| Explorer | A click selects a row; a single click on a file previews it, a double click pins it. A double click on a folder, or a click on its arrow, toggles it. File-type icons. Skips `.git`, `node_modules`, venvs and caches. |
| Editor | Tabs with a preview tab. Tree-sitter highlighting, with fallback grammars for Makefile, Dockerfile, `.env` and similar. Path bar and status bar (Ln/Col, language, encoding, LF/CRLF, file zoom, indexing progress, read-only lock). |
| Encodings | UTF-8 with and without BOM, UTF-16 LE/BE, Windows-1252 and Latin-1, saved back byte for byte. |
| Markdown | Native preview (MarkdownUI) with a larp theme. ⇧⌘V or the Preview/Source switch toggles it. |
| Themes | Dark is neon on true black, accent #FF2E88. Light is Apple-calm, accent #0071E3. View ▸ Appearance picks System, Light or Dark. |
| Zoom | ⌘+/⌘−/⌘0 zoom the app (90–150%). ⌘-scroll or a pinch zooms the file or shell (50–300%). A "− 110% + Reset" pill shows the level. |
| Find | larp's own ⌘F bar: count, case/word/regex (⌥⌘C/W/R), next and previous, replace and replace all with `$1`. Matches are accent-tinted CALayers. ⇧⌘F opens an IntelliJ-style Find in Files panel. |
| Terminal | SwiftTerm on the login shell. Tabs, rename, close on exit. Collapses to its tab bar (⌘J), animated. |
| ⌘-click | A tree-sitter symbol index of the project matches by name and opens a chooser when there are several matches. Names not in the project are found in library source and opened read-only. |

## 3. Code map

```
Sources/Larp/
  App/          LarpApp (Window scene, menus/commands), AppDelegate (Finder opens), Appearance
  Design/       Chrome (colours, PaneTab), Layout (window drag, sidebar toggle), Zoom + ZoomHUD,
                InputMonitor (the one local NSEvent monitor: zoom keys/scroll, ⌘F family, ⌘J),
                OptionToggle (icon buttons with hover + tooltip), FileIcon
  Workspace/    Workspace (shared state: folder, tree, stores, index), WorkspaceView (layout)
  Features/
    Explorer/   ExplorerPane, FileTreeLoader (skip list, 20k cap), FileNode, FolderPicker
    Editor/     DocumentStore, OpenDocument, EditorPane, EditorBridge (AppKit side of the editor:
                reveal/scroll, cursor, find highlights), FindModel + FindBar, TextFileLoader +
                TextEncoding, LanguageDetection, MarkdownPreview/Theme, EditorChrome, EditorTabBar,
                EditorTheme+Larp
    Search/     ProjectSearch (engine), SearchStore, FindInFilesPanel
    Navigation/ SymbolQueries (per-language tree-sitter patterns), SymbolIndex (actor: project
                index + on-demand library lookups), LibraryLocator (imports + manifests → library
                folders), DefinitionNavigator (CodeEditSourceEditor's JumpToDefinitionDelegate)
    Terminal/   TerminalStore, TerminalSession, TerminalPane/Stack/HostView, TerminalPalette
Tests/LarpTests/  one file per area; TempDirectory for disk fixtures
Examples/Production/  "Orderly", the multi-language test project (see its README)
```

## 4. Things that bit us (read before touching the editor)

- **One SourceEditorState per editor, and it is constant.** EditorPane passes
  `.constant(SourceEditorState())`. A shared binding replayed one file's
  scroll, cursor and find-panel state onto the next and undid programmatic
  jumps. Anything that moves the editor goes through `OpenDocument.bridge`
  (`EditorBridge`), and the cursor flows back through
  `textViewDidChangeSelection`.
- **Scroll with `NSView.scroll(_:)`.** `reflectScrolledClipView` on the
  CodeEdit scroll view threw the window off screen. Before layout,
  `scrollToVisible` does nothing, which is why reveals wait 0.1 s and centre
  by hand.
- **Clip the editor.** Since macOS 14, views don't clip to bounds, and the
  gutter drew over the tabs while scrolling.
  `controllerDidAppear` sets `clipsToBounds` on the scroll view and the
  controller's view. Observers on the scroll view must be registered there
  too, not in `prepareCoordinator`, where the view isn't loaded yet; that
  crashed.
- **Local event monitors run newest first.** The editor adds its own monitor
  for every file it opens. Larp's InputMonitor re-registers whenever an editor
  appears (`EditorBridge.editorDidAppear`) so its shortcuts stay on top. That
  is how ⌘F reaches larp's find bar instead of the stock panel. Menu commands
  were replaced too (`CommandGroup(replacing: .textEditing)`).
- **No emphasis manager for highlights.** It draws a second text layer, which
  looked blurry in dark mode. Find matches are plain CALayers behind the text,
  limited to 2,000.
- **SwiftTerm:**
  - Don't install a custom ANSI palette. Doing it before the shell started
    blanked the terminal, and it made Powerlevel10k unreadable.
  - Set `processDelegate = nil` before `terminate()`.
  - Version 1.99.2 or later is required. The lockfile is committed.
- **Accent colour.** macOS overrides an app's accent unless the system accent
  is Multicolor, so use `Chrome.accent` explicitly.
- **Fast tooltips.** `NSInitialToolTipDelay` is registered at 350 ms in
  `LarpApp.init`. A hand-rolled tooltip overlay was tried and reverted: it
  clipped and overlapped controls. Use `.help`.
- **New files need `./Scripts/bootstrap.sh`.** Otherwise the build doesn't see
  them, which shows up as baffling "cannot find X in scope" errors.
- **Concurrency.** Static helpers that tests call off the main actor must be
  `nonisolated` on `@MainActor` types. Closures passed to `Task.detached` must
  capture only Sendable values; `CodeLanguage` isn't Sendable, so detect the
  language inside the closure.

## 5. Verifying UI without input access

The agent has no Accessibility or keystroke permission, so UI was checked with
throwaway builds:
1. Add code marked `// SCREENSHOT-ONLY` that triggers the action
   programmatically, such as opening a file, showing find or setting the zoom.
2. Build, then relaunch with
   `open -n …/Larp.app --args -AppleInterfaceStyle Dark` or the defaults you
   need.
3. Capture with `screencapture -l<windowID>`. Find the window ID through
   CGWindowList with `optionAll`, because the window may be in a full-screen
   Space.
4. Revert, then confirm `grep -rn "SCREENSHOT-ONLY\|EXPERIMENT" Sources Tests`
   finds nothing before committing.

For logic, prefer a temporary test that prints real data. That is how the
library lookup was measured on this machine's Go stdlib: `http.ListenAndServe`
resolved in about 65 ms. Animations were checked by slowing them down and
pixel-scanning a series of captures.

Memory: `footprint <pid>` on a foreground launch. The core budget is 150 MB.

## 6. How the user works

- Builds feature by feature, then reviews by using the app, then refines. Keep
  each feature to one clean commit with a prose message. No `Co-Authored-By`
  or "Generated with" lines: the user's global rule overrides the harness.
- Push branches and never touch `main`. After a feature, restart the app on
  `Examples/Production` so the user can try it, and give a short try-it list.
- UI taste:
  - Icons with tooltips, not word labels.
  - Copy states rules: "Only X is supported." Never "Larp does…".
  - Dark is hacker neon; light is Apple.
  - Animate panes.
  - Nothing yellow or blurry.
- Cares a lot about RAM, and about matching IntelliJ's reading and navigation
  feel without the bloat.

## 7. What's next, and how each piece plugs in

In the order I'd build it. The user picks; PRODUCT.md is the source of truth
for scope.

1. **F4: keep up with the agent.** This comes first because nothing agentic
   works without it.
   - Add an FSEvents watcher (`FSEventStreamCreate` on `rootURL`, file-level
     events) owned by `Workspace`.
   - Refresh the tree by re-walking only the changed directories in
     `FileTreeLoader`.
   - Call `symbols.update(url)` for changed files.
   - For an open tab: reload it silently when it isn't dirty. When it is
     dirty, show a conflict bar ("Changed on disk: Keep mine / Load theirs /
     Compare"), and later route Compare into the F6 diff view.
   - Prompt before closing or quitting with dirty tabs. That needs
     `applicationShouldTerminate` in AppDelegate.
   - Suppress events caused by larp's own saves: remember the mtime after
     `OpenDocument.save()`.
2. **Find usages (⌥F7) and symbol search (⌘O / ⇧⌘O).**
   - Usages: whole-word Find in Files for the name, filtered to files where
     tree-sitter sees the name as an identifier node (to drop comments and
     strings). Show the results in the Find in Files panel, reusing
     `ProjectSearch.Match`.
   - Symbol search: a fuzzy filter over `SymbolIndex` (add an
     `allSymbols()`), in a panel like FindInFilesPanel. ⇧⌘O can do files the
     same way from `projectFiles`.
3. **Folding shortcuts** (⌥⌘← / →, ⌥⇧⌘← / →). CodeEditSourceEditor 0.15 has a
   fold ribbon but keeps its fold model internal. Either fork or patch it as a
   local package to expose fold and unfold, or compute ranges from tree-sitter
   ourselves and drive the text view's folding API.
4. **F6: diff and review.** The core differentiator.
   - Get the changes from `git diff --no-color -U3` (or libgit2 later), run
     through `Process` off the main actor.
   - Parse hunks into a model under `Features/Review/`.
   - Show a side-by-side or inline view. CodeEditSourceEditor has no diff
     mode, so render two editors with synced scrolling and CALayer
     backgrounds per changed line, the same technique as the find highlights.
   - Accept or reject a hunk with `git apply --cached` or `--reverse` on the
     hunk patch.
   - Keep comments in a review model that later feeds the agent (F10).
5. **F7–F9: language servers, opt-in per language.** These replace the
   name-based guessing.
   - Add an `LSPClient` (JSON-RPC over the server's stdio, one `Process` per
     language, started only when that language is enabled in settings).
   - Order: pyright, gopls, typescript-language-server, rust-analyzer, then
     jdtls (heavy, and the one that makes Java libraries and jars reachable).
   - `DefinitionNavigator.queryLinks` asks the LSP first and falls back to
     `SymbolIndex`, then to `LibraryLocator`. Keep both fallbacks; they're
     instant and cost nothing.
   - The LSP also brings references, rename, hover, diagnostics and code
     actions (F8).
   - Show each server's memory cost in settings (decision P2).
6. **F10 and F11: agent harness.** Run the master agent visibly in a terminal
   tab. Drive the sidecar headlessly through `claude -p --output-format
   stream-json` or the Agent SDK, or `codex exec --json`, as decided in P4.
   The sidecar chat is a new pane with a bounded history (memory budget).
7. **P5: larp as an MCP server.** Expose `open_file(path, line)`,
   `go_to_definition`, `highlight_range`, `show_diff_hunk` and
   `walkthrough_step`. Every one maps onto something that already exists:
   - `Workspace.openFile` plus `pendingReveal`.
   - `DefinitionNavigator`.
   - The CALayer highlights in EditorBridge.

   This is what lets an agent drive the UI.
8. **F12: walkthroughs.** The sidecar plans the steps and drives them over P5.
   The UI is a step strip ("3 / 9 · `place_order` → `reserve_stock`") with
   next and previous, and each step reveals and highlights a range.
9. **F13: manager mode.** An issue board backed by a file in the repo (for
   example `.larp/issues.json`), with one git worktree per issue (P6) and
   agents spawned through F10. The changelog is appended by agents through
   MCP.
10. **Modules F14–F16.** Each is opt-in and costs nothing until enabled.
    - DB viewer: start with SQLite (`db/dev.sqlite` in Orderly) using
      libsqlite3, then Postgres and MySQL with native drivers.
    - JSON graph: native SwiftUI Canvas, tested on `data/catalog.json`.
    - UML: needs a renderer, and a web view only while it is open (P3).

## 8. Open questions for the user

The full list is in PRODUCT.md §4:
- The sidecar's model.
- ACP vs the CLIs' JSON modes.
- What "subscribe" means.
- Logo and icon.

Also still undecided:
- Whether a project-local `.venv` should appear greyed in the explorer, the
  way JetBrains shows "excluded", instead of being hidden as it is now.
- Whether Java library navigation is worth a decompiler before jdtls.
