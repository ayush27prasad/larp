import Foundation

/// One shell session. Pure model — the view layer owns the PTY-backed view and
/// keys it by `id`, so this stays testable without spawning a shell.
struct TerminalSession: Identifiable, Hashable, Sendable {
    let id: UUID
    let workingDirectory: URL
    var title: String

    init(id: UUID = UUID(), workingDirectory: URL, title: String) {
        self.id = id
        self.workingDirectory = workingDirectory
        self.title = title
    }
}
