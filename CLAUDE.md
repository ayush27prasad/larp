# larp

Your Local Agent Review Pal: a native macOS IDE for reviewing and walking
through code that Claude Code or Codex wrote, with a sidecar chat that works for
that master agent. Today it is the editor foundation — explorer, tabbed editor,
terminal — in SwiftUI + AppKit; review, walkthroughs and the sidecar are the
roadmap. It was called iKhalacy before 0.4.

Read [README.md](README.md) first: *Why* is the product direction, and
*Architecture decisions* explains why the app is unsandboxed, all Swift, free of
web views, and built on CodeEditSourceEditor and SwiftTerm. Don't relitigate
those without a reason the README doesn't already answer.

## Build and test

```sh
./Scripts/bootstrap.sh    # after adding, removing or renaming any file
xcodebuild -scheme Larp -destination 'platform=macOS' -skipPackagePluginValidation build
xcodebuild -scheme Larp -destination 'platform=macOS' -skipPackagePluginValidation test
```

- XcodeGen globs `Sources/` and `Tests/`, so a new file is invisible to the
  build until `bootstrap.sh` regenerates the project. Never edit
  `Larp.xcodeproj` — it is generated and gitignored, apart from the committed
  `Package.resolved` inside it.
- Dependencies are pinned by that `Package.resolved`. To move one, change its
  range in `project.yml`, run `bootstrap.sh`, then
  `xcodebuild -resolvePackageDependencies -scheme Larp`, and commit the
  lockfile alongside the code that needs the new version.
- `Running SwiftLint for CodeEditTextView / CodeEditSourceEditor` is reported as
  a failed command on every build. That is the dependencies linting themselves;
  it is expected. Judge the result by `** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **`.
- Warnings are errors and Swift 6 strict concurrency is on. Both stay on.

## Conventions

- Panes never reach into each other. Shared state lives on `Workspace`; each
  pane's own state lives in an `@Observable @MainActor` store under its feature
  folder (`DocumentStore`, `TerminalStore`). AppKit views stay out of stores so
  the stores are testable without a window.
- Tests use Swift Testing (`@Test`, `#expect`). `TempDirectory` gives a
  throwaway file tree; `Workspace` tests inject a fresh `UserDefaults` suite so
  they never touch the real app's defaults.
- Comments explain *why*. Match the existing density, which is low.
- UserDefaults keys are namespaced by feature: `workspace.*`, `terminal.*`.

## Memory is a feature

Lightweight is a product promise, with a budget in the README. A change that
holds new state — a view, a cache, scrollback, a chat history — should say how
it stays bounded. Measure with `footprint <pid>` on a running app, not RSS;
launch it in the foreground, since a background launch never builds the window.

## Docs move with the code

Every user-visible change updates `CHANGELOG.md` under `[Unreleased]`, and the
README wherever it describes the behaviour, in the same commit. The 0.3 work
once drifted from its docs within minutes; the README is the onboarding doc, so
a stale one costs the next session real time.

## Versions and commits

- Roadmap milestones and release numbers are the same thing. A release bumps
  `MARKETING_VERSION` in `project.yml`, dates its CHANGELOG section, and gets an
  annotated `vX.Y.Z` tag.
- Commit messages: a short subject, then prose explaining what changed and why,
  wrapped at 72 columns. Milestone commits lead with the version
  (`0.2 explorer: …`).
