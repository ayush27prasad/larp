import AppKit
import CodeEditSourceEditor

/// A line and column in a document, 1-based, with how much to select there.
struct TextLocation: Equatable, Sendable {
    let line: Int
    let column: Int
    var length = 0
}

/// Gives a document a handle on its editor while one is on screen, so larp can
/// move the cursor and scroll — which the editor's state binding can set but
/// never scrolls to.
@MainActor
final class EditorBridge {
    weak var document: OpenDocument?
    private weak var controller: TextViewController?

    func revealPending() {
        guard let controller, let location = document?.pendingReveal else { return }
        document?.pendingReveal = nil
        let start = CursorPosition.Position(line: location.line, column: location.column)
        let end = CursorPosition.Position(line: location.line, column: location.column + location.length)
        controller.setCursorPositions([CursorPosition(start: start, end: end)], scrollToVisible: true)
        controller.view.window?.makeFirstResponder(controller.textView)
    }
}

// The editor calls its coordinators on the main thread.
extension EditorBridge: @preconcurrency TextViewCoordinator {
    func prepareCoordinator(controller: TextViewController) {
        self.controller = controller
    }

    func controllerDidAppear(controller: TextViewController) {
        self.controller = controller
        // The editor lays its text out after appearing; scroll once it has.
        DispatchQueue.main.async { [weak self] in self?.revealPending() }
    }

    func destroy() {
        controller = nil
    }
}
