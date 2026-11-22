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

    /// Beyond this many matches, only the first are tinted; the count stays exact.
    private static let maximumHighlights = 2_000
    private var findLayers: [CALayer] = []
    private var lastHighlight: (ranges: [NSRange], current: Int?)?
    private var scrollObserver: (any NSObjectProtocol)?
    private var pendingRefresh: DispatchWorkItem?

    var selectedText: String? {
        guard let controller, let range = controller.cursorPositions.first?.range, range.length > 0 else { return nil }
        return (controller.text as NSString).substring(with: range)
    }

    /// The cursor as a UTF-16 offset.
    var cursorLocation: Int? {
        controller?.cursorPositions.first?.range.location
    }

    /// Matches tinted with the theme's accent — neon pink in dark, Apple blue
    /// in light — instead of the system's yellow: the current match filled and
    /// outlined, the rest faintly enough to show where they are.
    ///
    /// Drawn as plain layers behind the text rather than through the text
    /// view's emphasis manager, which also paints a copy of the matched text
    /// on top, in black and a pixel off — garbled against a dark theme.
    func highlightFindMatches(_ ranges: [NSRange], current: Int?) {
        lastHighlight = (ranges, current)
        removeFindLayers()
        guard let controller, let host = controller.textView.layer,
              let layout = controller.textView.layoutManager
        else { return }

        let accent = Chrome.resolved(Chrome.accent, for: controller.view.effectiveAppearance)
        for (index, range) in ranges.prefix(Self.maximumHighlights).enumerated() {
            let isCurrent = index == current
            for rect in layout.rectsFor(range: range) where !rect.isEmpty {
                let layer = CALayer()
                layer.frame = rect.insetBy(dx: -1.5, dy: 0)
                layer.cornerRadius = 3
                layer.backgroundColor = accent.withAlphaComponent(isCurrent ? 0.38 : 0.16).cgColor
                if isCurrent {
                    layer.borderWidth = 1
                    layer.borderColor = accent.withAlphaComponent(0.9).cgColor
                }
                // Index 1, as the emphasis manager does: behind the text,
                // above the view's own background.
                host.insertSublayer(layer, at: UInt32(min(1, host.sublayers?.count ?? 0)))
                findLayers.append(layer)
            }
        }
    }

    func clearFindHighlights() {
        lastHighlight = nil
        removeFindLayers()
    }

    /// The stock find panel's emphasis group in CodeEditSourceEditor.
    private static let stockFindGroup = "codeedit.find"

    /// Removes matches the editor's own find panel emphasised, in case it ran.
    func clearStockFindHighlights() {
        controller?.textView.emphasisManager?.removeEmphases(for: Self.stockFindGroup)
    }

    private func removeFindLayers() {
        findLayers.forEach { $0.removeFromSuperlayer() }
        findLayers = []
    }

    /// Lines lay out lazily, so a match far off screen may have no final
    /// position yet; scrolling redraws the highlights once it settles.
    private func observeScrolling(of controller: TextViewController) {
        scrollObserver.map(NotificationCenter.default.removeObserver)
        let clipView = controller.scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification, object: clipView, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleHighlightRefresh() }
        }
    }

    private func scheduleHighlightRefresh() {
        guard lastHighlight != nil else { return }
        pendingRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let (ranges, current) = self.lastHighlight else { return }
            self.highlightFindMatches(ranges, current: current)
        }
        pendingRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
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
        // The line-number gutter is a floating subview of the scroll view as
        // tall as the whole document, and since macOS 14 views don't clip to
        // their bounds by default: scrolled, its off-screen numbers drew over
        // the path bar and tabs. Clip the scroll view and its container.
        controller.scrollView.clipsToBounds = true
        controller.view.clipsToBounds = true
        // Not in prepareCoordinator: the scroll view doesn't exist until the
        // view has loaded.
        observeScrolling(of: controller)
        NotificationCenter.default.post(name: Self.editorDidAppear, object: nil)
        // The editor lays its text out after appearing; scroll once it has.
        DispatchQueue.main.async { [weak self] in
            self?.revealPending()
            // The new editor starts without find highlights; restore them.
            self?.document?.findModel?.refresh(revealing: false)
        }
    }

    func destroy() {
        removeFindLayers()
        scrollObserver.map(NotificationCenter.default.removeObserver)
        scrollObserver = nil
        controller = nil
    }
}
