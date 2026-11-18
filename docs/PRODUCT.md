# larp — product reference

The single source of truth for **what larp is, what has been decided, and which
features exist or are planned**. Every session reads this before starting work
and updates it in the same commit as any change it affects. If this file and the
code disagree, one of them is a bug.

Status words used below:
- **Decided** — the user chose it. Change only with the user's say-so.
- **Proposed** — Claude's recommendation, not yet confirmed by the user.
- **Shipped / In progress / Planned / Idea** — feature state.

Last reviewed: 2026-11-18.

## 1. What larp is

**larp — Your Local Agent Review Pal.** A native, lightweight macOS IDE for
working alongside coding agents (Claude Code, Codex). The agent writes most of
the code; larp is where you understand, review, navigate and steer it — with
IntelliJ-Ultimate-level code reading and reviewing, minus the bloat.

Two ways to use it:
- **Developer mode** — you care about the code: review diffs, walk through
  features, navigate like IntelliJ (⌘-click, find usages), refactor.
- **Manager mode** — you don't want to look at code: a chat + project-management
  view where you dump issues, multiple agents pick them up in parallel, and you
  track progress and a changelog.

## 2. Decisions

| # | Decision | Status | Why |
|---|---|---|---|
| D1 | **macOS only.** | Decided 2026-11-18 | Lets the app be fully native; no cross-platform UI layer. |
| D2 | **All Swift (SwiftUI + AppKit), no Rust core.** | Decided 2026-11 | Measured 71 MB footprint. Swift and Rust have the same memory profile (native, no GC); most memory is SwiftUI/AppKit itself, which a Rust core keeps. Swift calls C directly, so there is no loss of low-level control (PTYs, `posix_spawn`, signals, `mmap`, FSEvents). Rust would only pay off for cross-platform, ruled out by D1. A single Rust library may still come in behind a narrow interface if no Swift equivalent exists. |
| D3 | **Lightweight is a feature.** Memory budget: the core stays under 150 MB (`footprint`) with a project, a few tabs, two terminals and the chat open. | Decided (user requirement); number Proposed | The user's main reason for a native app. |
| D4 | **Opt-in per feature and per language** — users get only what they turn on (languages/LSPs, DB viewer, UML, …). | Decided (user requirement) | "Users get only what they subscribe to." |
| D5 | **Terminal: SwiftTerm**, running the user's real login shell on a PTY. Terminal.app cannot be embedded (macOS has no API to host another app's window). | Decided | Mature emulator; full-screen TUIs like Claude Code work. Has an optional GPU (Metal) renderer to evaluate for heavy agent output. |
| D6 | **Editor: CodeEditSourceEditor** (tree-sitter highlighting). | Decided (inherited) | Weeks of work saved over a hand-rolled editor. |
| D7 | Unsandboxed, Hardened Runtime; no Mac App Store. | Decided (inherited) | Needs a shell and arbitrary folders. |
| D8 | XcodeGen (`project.yml`), `Package.resolved` committed. | Decided (inherited) | Reviewable project diffs; reproducible dependency versions. |
| P1 | **Lean core + opt-in modules.** Core = explorer, editor, terminal, diff, agent harness. Everything else (each language's LSP, DB viewer, UML, JSON graph, PM board) is a module that costs nothing until enabled. | Proposed | How D3 and D4 coexist with a large feature list. |
| P2 | **Heavy work runs in separate processes** — language servers, agents, DB drivers. The memory budget covers the core; each module states its own cost. | Proposed | A single Java LSP can exceed 500 MB; it must be opt-in and visible. |
| P3 | **No web views in the core.** A module that needs one (e.g. a diagram renderer) creates it when opened and tears it down when closed. | Proposed (revises the README's strict "no web views") | Each WKWebView is its own process costing as much as the app. |
| P4 | **Integrate agents through structured protocols, not by scraping the terminal.** The master agent can still run visibly in a terminal tab; the sidecar and PM workers are driven headlessly (Claude Code `-p --output-format stream-json` / Agent SDK, Codex `exec --json` / app-server, or Zed's Agent Client Protocol — to evaluate). | Proposed | Reliable control and state, instead of parsing a TUI. |
| P5 | **larp is itself an MCP server** exposing IDE actions (open file at line, go to definition, show diff hunk, highlight range, start walkthrough step). | Proposed | This is what lets an agent *drive* the UI — the basis of agentic walkthroughs. |
| P6 | **One git worktree per issue** for parallel agents in manager mode. | Proposed | Agents can't trample each other's working copy. |

## 3. Features

| # | Feature | Status | Notes |
|---|---|---|---|
| F1 | Explorer: open a folder, file tree, session restore | Shipped (0.2) | Eager walk, 20k-entry cap. |
| F2 | Editor: tabs (VS Code preview model), editing, saving, tree-sitter highlighting | Shipped (0.3) | UTF-8 only; refusals explained. |
| F3 | Terminal: multiple PTY tabs, rename, close on clean exit | Shipped (0.3) | SwiftTerm 1.99. |
| F4 | Keep up with the agent: tree and open tabs reload on external changes; unsaved edits never silently lost (prompts on close/quit, conflict when disk and buffer both changed) | Planned (0.4) | Prerequisite for everything agentic. |
| F5 | Find in file, pane show/hide | Planned (0.4) | |
| F6 | **Diff checker / review**: what changed, file by file and hunk by hunk; accept/reject; comment back to the agent | Planned (0.5) | Core differentiator. |
| F7 | **Code navigation à la IntelliJ**: ⌘-click go-to-definition, find usages, symbol search, call hierarchy | Planned | Via LSP (P1/P2) per enabled language. |
| F8 | **Refactoring**: rename, extract, code actions | Planned | LSP gives rename/extract/code actions; IntelliJ's deepest per-language refactorings are out of reach without its engines — agents cover the rest. |
| F9 | **Per-language opt-in** (LSP install/enable per language) | Planned | D4, P1. |
| F10 | **Agent harness**: master agent (Claude Code or Codex) + sidecar agent working alongside, sharing context | Planned | P4, P5. Sidecar serves the master; it doesn't compete for the code. |
| F11 | **Terminal-level control of agents** — start/stop/watch agent sessions, see their state | Planned | Terminal tab for visibility + structured channel (P4). |
| F12 | **Agentic walkthrough UI**: "walk me through feature X" → sidecar starts at the entry point and steps through it, opening each function as in ⌘-click, line by line | Planned | Needs F7 + P5. |
| F13 | **Manager mode**: chat + PM board; dump issues; multiple agents pick them up in worktrees; shared context; maintained changelog | Planned | P6. |
| F14 | **DB viewer** (TablePlus + DBeaver style): connect, browse schema, query, edit rows | Planned (module) | Start with Postgres, MySQL, SQLite natively; DBeaver's breadth comes from Java drivers. |
| F15 | **UML / diagrams**: generate from code, create new drawings | Planned (module) | Mermaid/PlantUML need JS/Java to render → P3. |
| F16 | **JSON graph viewer** (JSON Crack-like) for JSON files | Planned (module) | Native rendering feasible. |

The user will specify features in detail one at a time; each feature's detail
goes under its row (or a linked `docs/features/F<n>-*.md`) when agreed.

## 4. Open questions

- Sidecar's own model: does it call the same agent (Claude Code/Codex), an API,
  or a local model? (A local model would dwarf the memory budget — gigabytes.)
- Integration protocol choice (P4): direct CLI JSON modes vs ACP.
- "Subscribe" — a settings toggle, or a paid tier per module?
- Logo and app icon (none yet).

## 5. Landscape

**Zed** (Rust, GPUI, cross-platform) is the closest existing product, as of
Nov 2026: fast native editor with LSP, extensions, git panel, and an agent
panel that runs Claude Code, Codex and others through the Agent Client Protocol,
with parallel agent threads and terminal threads. It has **no** database viewer,
UML/drawing, JSON graph viewer, or issue-board/manager mode, and its walkthrough
and review are agent-chat-centric rather than an IDE the agent drives.
larp's angle: review/walkthrough-first, manager mode, and the IntelliJ-style
tool modules — macOS-native and lean.
