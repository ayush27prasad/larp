# Changelog

All notable changes to iKhalacy are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
While the major version is `0`, minor bumps may include breaking changes.

## [Unreleased]

### Added
- Nothing yet.

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

[Unreleased]: https://github.com/ayush27prasad/iKhalacy/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ayush27prasad/iKhalacy/releases/tag/v0.1.0
