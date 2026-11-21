import AppKit
import CodeEditSourceEditor
import CodeEditTextView

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

    /// Posted when an editor appears. The editor registers a key monitor as it
    /// does, which then runs ahead of larp's, so larp's is re-registered.
    static let editorDidAppear = Notification.Name("larp.editorDidAppear")

    private static let findGroup = "larp.find"

    var selectedText: String? {
        guard let controller, let range = controller.cursorPositions.first?.range, range.length > 0 else { return nil }
        return (controller.text as NSString).substring(with: range)
    }

    /// The cursor as a UTF-16 offset.
    var cursorLocation: Int? {
        controller?.cursorPositions.first?.range.location
    }

    func highlightFindMatches(_ ranges: [NSRange], current: Int?) {
        let emphases = ranges.enumerated().map { index, range in
            Emphasis(range: range, style: .standard, inactive: index != current)
        }
        controller?.textView.emphasisManager?.replaceEmphases(emphases, for: Self.findGroup)
    }

    func clearFindHighlights() {
        controller?.textView.emphasisManager?.removeEmphases(for: Self.findGroup)
    }

    /// Selects and scrolls to `range` without taking focus from the find field.
    func select(_ range: NSRange) {
        controller?.setCursorPositions([CursorPosition(range: range)], scrollToVisible: true)
    }

    /// Through the text view, so the change is undoable like typing.
    func replace(_ range: NSRange, with string: String) {
        controller?.textView.replaceCharacters(in: range, with: string)
    }

    func focusEditor() {
        guard let controller else { return }
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
        NotificationCenter.default.post(name: Self.editorDidAppear, object: nil)
        // The editor lays its text out after appearing; scroll once it has.
        DispatchQueue.main.async { [weak self] in
            self?.revealPending()
            // The new editor starts without find highlights; restore them.
            self?.document?.findModel?.refresh(revealing: false)
        }
    }

    func destroy() {
        controller = nil
    }
}
