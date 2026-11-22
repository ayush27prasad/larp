import CodeEditSourceEditor
import Foundation
import SwiftUI

/// Answers ⌘-click in the editor: the definitions of the name under the
/// pointer, from the symbol index. One is jumped to; several are offered in
/// the editor's chooser, definitions in the same file first.
@MainActor
final class DefinitionNavigator {
    weak var workspace: Workspace?

    /// What a click on `name` in `url`, at `range`, should offer.
    static func links(
        for name: String,
        at range: NSRange,
        in url: URL,
        among definitions: [SymbolIndex.Symbol],
        root: URL?
    ) -> [JumpToDefinitionLink] {
        definitions
            // Clicking a definition itself has nowhere to jump to.
            .filter { !($0.url == url && NSIntersectionRange($0.range, range).length > 0) }
            .sorted { lhs, rhs in
                if (lhs.url == url) != (rhs.url == url) { return lhs.url == url }
                return (lhs.url.path, lhs.line) < (rhs.url.path, rhs.line)
            }
            .map { symbol in
                JumpToDefinitionLink(
                    // nil keeps a same-file jump inside the open editor.
                    url: symbol.url == url ? nil : symbol.url,
                    targetRange: symbol.url == url
                        ? CursorPosition(range: symbol.range)
                        : CursorPosition(line: symbol.line, column: symbol.column),
                    typeName: "\(symbol.kind.rawValue) \(symbol.name)",
                    sourcePreview: symbol.preview,
                    documentation: relativePath(of: symbol.url, root: root),
                    image: Image(systemName: icon(for: symbol.kind)))
            }
    }

    private static func relativePath(of url: URL, root: URL?) -> String {
        guard let root, url.path.hasPrefix(root.path + "/") else { return url.path }
        return String(url.path.dropFirst(root.path.count + 1))
    }

    private static func icon(for kind: SymbolIndex.Symbol.Kind) -> String {
        switch kind {
        case .function: "f.square"
        case .method: "m.square"
        case .class: "c.square"
        case .type: "t.square"
        case .constant: "k.square"
        }
    }
}

// The editor calls its delegate on the main actor.
extension DefinitionNavigator: @preconcurrency JumpToDefinitionDelegate {
    func queryLinks(forRange range: NSRange, textView: TextViewController) async -> [JumpToDefinitionLink]? {
        guard let workspace, let url = workspace.editor.activeDocument?.url else { return nil }
        let text = textView.text as NSString
        guard NSMaxRange(range) <= text.length else { return nil }
        let name = text.substring(with: range)
        let definitions = await workspace.symbols.definitions(named: name)
        let links = Self.links(for: name, at: range, in: url, among: definitions, root: workspace.rootURL)
        return links.isEmpty ? nil : links
    }

    func openLink(link: JumpToDefinitionLink) {
        guard let workspace, let url = link.url else { return }
        let start = link.targetRange.start
        Task {
            guard await workspace.openFile(url) else { return }
            workspace.editor.activeDocument?.pendingReveal = TextLocation(
                line: start.line, column: start.column,
                length: link.label.split(separator: " ").last.map { $0.utf16.count } ?? 0)
        }
    }
}
