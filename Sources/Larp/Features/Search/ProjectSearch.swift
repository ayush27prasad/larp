import Foundation

/// Searches a project's text files — the engine behind Find in Files (⇧⌘F).
///
/// Runs off the main actor, checks for cancellation between files so a new
/// keystroke abandons a stale search, and stops at `maximumMatches` so a huge
/// project can't stall it.
enum ProjectSearch {
    static let maximumMatches = 2_000
    /// Longest preview kept per matching line; the rest is cut.
    static let previewLength = 240

    struct Options: Equatable, Sendable {
        var matchCase = false
        var wholeWord = false
        var regex = false
    }

    struct Match: Identifiable, Equatable, Sendable {
        let url: URL
        /// 1-based, like the editor's cursor positions.
        let line: Int
        let column: Int
        let length: Int
        /// The line, leading whitespace trimmed, with each hit's range in it.
        let preview: String
        let highlights: [NSRange]

        var id: String { "\(url.path):\(line):\(column)" }
    }

    struct FileMatches: Identifiable, Equatable, Sendable {
        let url: URL
        let matches: [Match]
        var id: URL { url }
    }

    struct Result: Equatable, Sendable {
        var files: [FileMatches] = []
        var matchCount = 0
        var isTruncated = false
        var isInvalidPattern = false
    }

    static func search(
        _ query: String,
        options: Options,
        in files: [URL],
        limit: Int = maximumMatches
    ) async -> Result {
        var result = Result()
        guard !query.isEmpty else { return result }
        guard let pattern = pattern(for: query, options: options) else {
            result.isInvalidPattern = true
            return result
        }

        for url in files {
            if Task.isCancelled || result.matchCount >= limit { break }
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
                  data.count <= TextFileLoader.maximumByteCount,
                  let text = try? TextFileLoader.decode(data).text
            else { continue }

            let matches = self.matches(of: pattern, in: text, url: url, budget: limit - result.matchCount)
            guard !matches.isEmpty else { continue }
            result.files.append(FileMatches(url: url, matches: matches))
            result.matchCount += matches.count
        }
        result.isTruncated = result.matchCount >= limit
        return result
    }

    /// Nil when `regex` is on and the query isn't a valid pattern.
    static func pattern(for query: String, options: Options) -> NSRegularExpression? {
        var source = options.regex ? query : NSRegularExpression.escapedPattern(for: query)
        if options.wholeWord { source = "\\b\(source)\\b" }
        return try? NSRegularExpression(
            pattern: source,
            options: options.matchCase ? [] : [.caseInsensitive])
    }

    private static func matches(of pattern: NSRegularExpression, in text: String, url: URL, budget: Int) -> [Match] {
        var found: [Match] = []
        // Splitting on isNewline keeps CRLF one break, so line numbers match
        // the editor's.
        for (index, line) in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated() {
            let line = String(line)
            let hits = pattern.matches(in: line, range: NSRange(line.startIndex..., in: line))
                .map(\.range)
                .filter { $0.length > 0 }
            guard let first = hits.first else { continue }

            let trimmed = line.utf16.prefix { $0 == 0x20 || $0 == 0x09 }.count
            let preview = String(line.dropFirst(line.prefix { $0 == " " || $0 == "\t" }.count).prefix(previewLength))
            let previewLength = (preview as NSString).length
            let highlights = hits.compactMap { hit -> NSRange? in
                let shifted = NSRange(location: hit.location - trimmed, length: hit.length)
                guard shifted.location >= 0, NSMaxRange(shifted) <= previewLength else { return nil }
                return shifted
            }

            found.append(Match(
                url: url, line: index + 1, column: first.location + 1, length: first.length,
                preview: preview, highlights: highlights))
            if found.count >= budget { break }
        }
        return found
    }
}
