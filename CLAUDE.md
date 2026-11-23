# larp

Your Local Agent Review Pal: a native macOS IDE for reviewing and walking
through code that Claude Code or Codex wrote, with a sidecar chat that works for
that master agent. Today it is the editor foundation — explorer, tabbed editor,
terminal — in SwiftUI + AppKit; review, walkthroughs and the sidecar are the
roadmap. It was called iKhalacy before 0.4.

**Read [docs/PRODUCT.md](docs/PRODUCT.md) first.** It is the maintained
reference for what larp is, every decision (and whether the user decided it or
it is only proposed), and the status of every feature. Features are built one
at a time; when one is specified, changed or shipped, update its row there in
the same commit. Never treat a *Proposed* item as decided.

**Then [docs/HANDOVER.md](docs/HANDOVER.md)**: where the work stands, which
branch to build on, the editor pitfalls already paid for, how to verify UI
without input access, and how each remaining feature plugs in.

Then [README.md](README.md): *Architecture decisions* explains why the app is
unsandboxed, all Swift, and built on CodeEditSourceEditor and SwiftTerm. Don't
relitigate those without a reason neither document already answers.

## How features ship

1. The user describes a feature; agree its scope under its row in
   `docs/PRODUCT.md` before building.
2. Build it on a branch (`feature/F<n>-<slug>`), with tests and doc updates,
   until the build is clean and the tests pass.
3. Push the branch and ask the user to merge it — give them a short try-it
   checklist. Pushing feature branches is pre-approved; **never push or merge
   to `main` yourself**. The user merges.
4. Refinements after their review go on the same branch.

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
- UI text is short and impersonal. Never "Larp does …"; state the rule:
  "Only UTF-8 text is supported.", "Only files up to 4 MB are supported."
- UserDefaults keys are namespaced by feature: `workspace.*`, `terminal.*`.

## Memory is a feature

Lightweight is a product promise, with a budget in the README. A change that
holds new state — a view, a cache, scrollback, a chat history — should say how
it stays bounded. Measure with `footprint <pid>` on a running app, not RSS;
launch it in the foreground, since a background launch never builds the window.

## Testing by hand

`Examples/Production/` (Orderly) is the project to try every feature on. When
a feature needs a case it lacks — a language, a file shape, a database table —
add it there, coherent with the rest, and note it in its README.

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
