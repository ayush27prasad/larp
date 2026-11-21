import Foundation

/// One shell session. Pure model — the view layer owns the PTY-backed view and
/// keys it by `id`, so this stays testable without spawning a shell.
struct TerminalSession: Identifiable, Hashable, Sendable {
    let id: UUID
    let workingDirectory: URL
    var title: String
    /// This shell's own zoom, on top of the app's; ⌘-scroll over the terminal.
    var zoom = 1.0

    init(id: UUID = UUID(), workingDirectory: URL, title: String) {
        self.id = id
        self.workingDirectory = workingDirectory
        self.title = title
    }
}
