import Foundation
import Observation

/// Find and replace in the active file (⌘F, ⌥⌘F). Matches are recomputed from
/// the document's text whenever the query, options, text or file change; the
/// editor highlights them and selects the current one through the document's
/// bridge.
@Observable
@MainActor
final class FindModel {
    private(set) var isVisible = false
    var showsReplace = false

    var query = "" {
        didSet { if query != oldValue { currentIndex = nil; refresh(revealing: true) } }
    }

    var replacement = ""

    var options = ProjectSearch.Options() {
        didSet { if options != oldValue { currentIndex = nil; refresh(revealing: true) } }
    }

    private(set) var matches: [NSRange] = []
    private(set) var currentIndex: Int?
    private(set) var isInvalidPattern = false

    /// Bumped to ask the find field to take focus, e.g. on a second ⌘F.
    private(set) var focusRequest = 0

    /// The file being searched; set by the editor pane.
    @ObservationIgnored weak var document: OpenDocument? {
        didSet {
            guard document !== oldValue else { return }
            oldValue?.bridge.clearFindHighlights()
            currentIndex = nil
            refresh(revealing: false)
        }
    }

    /// "3 of 12", "No results", or nothing before a query.
    var status: String {
        if query.isEmpty { return "" }
        if isInvalidPattern { return "Invalid pattern" }
        guard let currentIndex, !matches.isEmpty else { return matches.isEmpty ? "No results" : "\(matches.count) results" }
        return "\(currentIndex + 1) of \(matches.count)"
    }

    func show(replace: Bool, prefill: String?) {
        if let prefill, !prefill.isEmpty, !prefill.contains(where: \.isNewline) { query = prefill }
        isVisible = true
        if replace { showsReplace = true }
        focusRequest += 1
        refresh(revealing: false)
    }

    func hide() {
        isVisible = false
        document?.bridge.clearFindHighlights()
        document?.bridge.focusEditor()
    }

    func next() { move(by: 1) }
    func previous() { move(by: -1) }

    /// Recomputes matches against the document's current text.
    /// - Parameter revealing: select and scroll to the current match, as when
    ///   the query changes; not when the text changes under it.
    func refresh(revealing: Bool) {
        guard isVisible, let document, !query.isEmpty else {
            matches = []
            isInvalidPattern = false
            document?.bridge.clearFindHighlights()
            return
        }
        guard let pattern = ProjectSearch.pattern(for: query, options: options) else {
            matches = []
            isInvalidPattern = true
            document.bridge.clearFindHighlights()
            return
        }
        isInvalidPattern = false
        let text = document.text
        matches = pattern.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
            .map(\.range)
            .filter { $0.length > 0 }

        if matches.isEmpty {
            currentIndex = nil
        } else if let index = currentIndex {
            currentIndex = min(index, matches.count - 1)
        } else {
            // Start from the first match at or after the cursor, as editors do.
            let cursor = document.bridge.cursorLocation ?? 0
            currentIndex = matches.firstIndex { $0.location >= cursor } ?? 0
        }
        document.bridge.highlightFindMatches(matches, current: currentIndex)
        if revealing, let currentIndex { document.bridge.select(matches[currentIndex]) }
    }

    func replaceCurrent() {
        guard let document, !document.isReadOnly,
              let currentIndex, matches.indices.contains(currentIndex) else { return }
        let range = matches[currentIndex]
        document.bridge.replace(range, with: replacementText(for: range, in: document.text))
        // The edit changes the text; refresh keeps the index, which now points
        // at the match after the replaced one.
        refresh(revealing: true)
    }

    func replaceAll() {
        guard let document, !document.isReadOnly, !matches.isEmpty else { return }
        let text = document.text
        // Back to front, so earlier ranges stay valid as later ones change.
        for range in matches.reversed() {
            document.bridge.replace(range, with: replacementText(for: range, in: text))
        }
        currentIndex = nil
        refresh(revealing: false)
    }

    /// The literal replacement, or for a regex the template with `$1` groups
    /// filled from this match.
    func replacementText(for range: NSRange, in text: String) -> String {
        guard options.regex,
              let pattern = ProjectSearch.pattern(for: query, options: options),
              let match = pattern.firstMatch(in: text, range: range)
        else { return replacement }
        return pattern.replacementString(for: match, in: text, offset: 0, template: replacement)
    }

    private func move(by offset: Int) {
        guard let document, !matches.isEmpty else { return }
        let index = ((currentIndex ?? -1) + offset + matches.count) % matches.count
        currentIndex = index
        document.bridge.highlightFindMatches(matches, current: index)
        document.bridge.select(matches[index])
    }
}
