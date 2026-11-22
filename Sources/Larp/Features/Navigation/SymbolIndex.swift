import CodeEditLanguages
import Foundation
import SwiftTreeSitter

/// Where every function, type, method and top-level constant in the project is
/// defined, found by parsing each file with its tree-sitter grammar.
///
/// It matches by name — the way GitHub's code navigation does — so a common
/// name can have several candidates; a language server, when added, gives
/// exact answers. Built in the background when a folder opens, and updated
/// file by file on save.
actor SymbolIndex {
    struct Symbol: Equatable, Sendable {
        enum Kind: String, Sendable {
            case function, method, `class`, type, constant
        }

        let name: String
        let kind: Kind
        let url: URL
        /// UTF-16 range of the name in the file, as the editor counts.
        let range: NSRange
        /// 1-based.
        let line: Int
        let column: Int
        /// The definition's line, trimmed, for the chooser.
        let preview: String
    }

    private var symbolsByFile: [URL: [Symbol]] = [:]
    /// nil when a language has no usable patterns, so it isn't retried.
    private var queries: [TreeSitterLanguage: Query?] = [:]

    var fileCount: Int { symbolsByFile.count }

    /// Re-indexes every file, reporting progress after each.
    func rebuild(files: [URL], progress: @Sendable (_ done: Int, _ total: Int) async -> Void) async {
        symbolsByFile = [:]
        for (done, url) in files.enumerated() {
            if Task.isCancelled { return }
            index(url)
            await progress(done + 1, files.count)
        }
    }

    /// Re-indexes one file from disk, or from `text` when it is already loaded.
    func update(_ url: URL, text: String? = nil) {
        index(url, text: text)
    }

    func definitions(named name: String) -> [Symbol] {
        symbolsByFile.values.flatMap { $0.filter { $0.name == name } }
    }

    func symbols(in url: URL) -> [Symbol] {
        symbolsByFile[url] ?? []
    }

    private func index(_ url: URL, text: String? = nil) {
        guard let text = text ?? Self.read(url) else {
            symbolsByFile[url] = nil
            return
        }
        let language = LanguageDetection.language(for: url, prefix: String(text.prefix(1_024)))
        guard let grammar = language.language, let query = query(for: language.id, grammar: grammar) else {
            symbolsByFile[url] = nil
            return
        }
        let parser = Parser()
        guard (try? parser.setLanguage(grammar)) != nil, let tree = parser.parse(text) else { return }
        symbolsByFile[url] = Self.symbols(in: text, url: url, tree: tree, query: query)
    }

    private func query(for language: TreeSitterLanguage, grammar: Language) -> Query? {
        if let cached = queries[language] { return cached }
        // Keep only the patterns this grammar accepts, then compile them as one.
        let valid = SymbolQueries.patterns(for: language).filter {
            (try? Query(language: grammar, data: Data($0.utf8))) != nil
        }
        let query = valid.isEmpty ? nil : try? Query(language: grammar, data: Data(valid.joined(separator: "\n").utf8))
        queries[language] = query
        return query
    }

    private static func read(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count <= TextFileLoader.maximumByteCount
        else { return nil }
        return try? TextFileLoader.decode(data).text
    }

    private static func symbols(in text: String, url: URL, tree: MutableTree, query: Query) -> [Symbol] {
        let string = text as NSString
        let lineStarts = Self.lineStarts(in: string)
        var symbols: [Symbol] = []
        let cursor = query.execute(in: tree)
        while let match = cursor.next() {
            for capture in match.captures {
                guard let kind = capture.nameComponents.first.flatMap(Symbol.Kind.init(rawValue:)) else { continue }
                let range = capture.node.range
                guard range.length > 0, NSMaxRange(range) <= string.length else { continue }
                let lineIndex = Self.line(containing: range.location, in: lineStarts)
                let lineRange = string.lineRange(for: NSRange(location: range.location, length: 0))
                symbols.append(Symbol(
                    name: string.substring(with: range),
                    kind: kind,
                    url: url,
                    range: range,
                    line: lineIndex + 1,
                    column: range.location - lineStarts[lineIndex] + 1,
                    preview: string.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }
        return symbols
    }

    /// UTF-16 offset of each line's first character.
    private static func lineStarts(in string: NSString) -> [Int] {
        var starts = [0]
        var location = 0
        while location < string.length {
            let range = string.lineRange(for: NSRange(location: location, length: 0))
            location = NSMaxRange(range)
            if location < string.length { starts.append(location) }
        }
        return starts
    }

    private static func line(containing offset: Int, in starts: [Int]) -> Int {
        var low = 0, high = starts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if starts[mid] <= offset { low = mid } else { high = mid - 1 }
        }
        return low
    }
}
