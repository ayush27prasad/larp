import CodeEditSourceEditor
import Foundation
import SwiftUI

/// Answers ⌘-click in the editor: the definitions of the name under the
/// pointer, from the symbol index. One is jumped to; several are offered in
/// the editor's chooser, definitions in the same file first. A name the
/// project doesn't define is looked up in the libraries the file imports.
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
        guard let root, url.path.hasPrefix(root.path + "/") else {
            return (url.path as NSString).abbreviatingWithTildeInPath
        }
        return String(url.path.dropFirst(root.path.count + 1))
    }

    /// The identifier before `.` or `::` ahead of `range`: `http` for a click
    /// on `Get` in `http.Get`.
    nonisolated static func qualifier(before range: NSRange, in text: NSString) -> String? {
        var end = range.location
        guard end > 0 else { return nil }
        if text.character(at: end - 1) == UInt16(UInt8(ascii: ".")) {
            end -= 1
        } else if end > 1, text.substring(with: NSRange(location: end - 2, length: 2)) == "::" {
            end -= 2
        } else {
            return nil
        }
        var start = end
        while start > 0, let scalar = Unicode.Scalar(text.character(at: start - 1)),
              CharacterSet.alphanumerics.contains(scalar) || scalar == "_" {
            start -= 1
        }
        return start < end ? text.substring(with: NSRange(location: start, length: end - start)) : nil
    }

    /// Library definitions of `name` for a click in `url`.
    private func libraryDefinitions(
        named name: String, qualifier: String?, in url: URL, text: String, workspace: Workspace
    ) async -> [SymbolIndex.Symbol] {
        let root = workspace.rootURL
        // Off the main actor: it reads manifests and lists cache folders.
        let (found, extensions) = await Task.detached { () -> ([LibraryLocator.Location], Set<String>) in
            let language = LanguageDetection.language(for: url, prefix: String(text.prefix(1_024))).id
            return (
                LibraryLocator.locations(
                    for: name, qualifier: qualifier, in: url, text: text, language: language, root: root),
                LibraryLocator.extensions(for: language))
        }.value
        var locations = found
        // A library file isn't in the project index; search it as well, first.
        if workspace.editor.activeDocument?.isReadOnly == true {
            locations.insert(LibraryLocator.Location(url: url, recursive: false), at: 0)
        }
        guard !locations.isEmpty else { return [] }
        let definitions = await workspace.symbols.libraryDefinitions(
            named: name, in: locations, extensions: extensions)
        // `pkg.Name` names something in the package, not a method on a value.
        if qualifier != nil, definitions.contains(where: { $0.kind != .method }) {
            return definitions.filter { $0.kind != .method }
        }
        return definitions
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
        var definitions = await workspace.symbols.definitions(named: name)
        if definitions.isEmpty {
            definitions = await libraryDefinitions(
                named: name, qualifier: Self.qualifier(before: range, in: text),
                in: url, text: textView.text, workspace: workspace)
        }
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
