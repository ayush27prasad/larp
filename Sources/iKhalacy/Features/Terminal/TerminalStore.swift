import AppKit
import Foundation
import Observation

/// The open shell sessions and which one is showing.
@Observable
@MainActor
final class TerminalStore {
    private(set) var sessions: [TerminalSession] = []
    var activeSessionID: TerminalSession.ID?

    /// Set by the hosting view so ⌘W can tell whether the terminal has focus.
    @ObservationIgnored weak var containerView: NSView?

    /// Numbering continues across closes, the way terminal apps label tabs.
    private var nextNumber = 1

    var activeSession: TerminalSession? {
        sessions.first { $0.id == activeSessionID }
    }

    var hasSessions: Bool { !sessions.isEmpty }

    @discardableResult
    func newSession(in directory: URL) -> TerminalSession {
        let session = TerminalSession(
            workingDirectory: directory,
            title: "Terminal \(nextNumber)")
        nextNumber += 1
        sessions.append(session)
        activeSessionID = session.id
        return session
    }

    /// Renames a session. Blank names are ignored rather than accepted, so a
    /// tab can never end up with no label.
    func rename(_ id: TerminalSession.ID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = sessions.firstIndex(where: { $0.id == id })
        else { return }
        sessions[index].title = trimmed
    }

    func close(_ id: TerminalSession.ID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions.remove(at: index)

        guard activeSessionID == id else { return }
        // Focus the tab to the left, matching the editor.
        activeSessionID = sessions.isEmpty ? nil : sessions[max(0, index - 1)].id
    }

    func closeAll() {
        sessions.removeAll()
        activeSessionID = nil
        nextNumber = 1
    }

    /// True when the key window's first responder lives inside the terminal.
    var hasFocus: Bool {
        guard let container = containerView,
              let responder = container.window?.firstResponder as? NSView
        else { return false }
        return responder === container || responder.isDescendant(of: container)
    }
}
