import Foundation

/// Reads a file into a string, refusing anything that isn't editable text.
enum TextFileLoader {
    /// Files above this are refused rather than loaded into a single `String`.
    static let maximumByteCount = 4 * 1024 * 1024

    /// UTF-8's byte-order mark. Kept out of the editable text and written back
    /// on save, so saving never adds or strips one.
    static let byteOrderMark = Data([0xEF, 0xBB, 0xBF])

    struct Contents: Equatable, Sendable {
        let text: String
        let hasByteOrderMark: Bool
    }

    enum Failure: Error, Equatable {
        case tooLarge(byteCount: Int)
        case notText
        case notUTF8
        case unreadable(String)
    }

    static func load(_ url: URL) async throws -> Contents {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw Failure.unreadable(error.localizedDescription)
        }

        guard data.count <= maximumByteCount else {
            throw Failure.tooLarge(byteCount: data.count)
        }
        // A NUL byte in the leading bytes is the usual cheap binary tell.
        guard !data.prefix(8_192).contains(0) else { throw Failure.notText }

        // UTF-8 only, because saving writes UTF-8. A fallback to UTF-16 once
        // stood here, but it accepts almost any bytes: Latin-1 files decoded
        // as mojibake, and ⌘S then overwrote the original with it.
        let hasByteOrderMark = data.starts(with: byteOrderMark)
        let body = hasByteOrderMark ? data.dropFirst(byteOrderMark.count) : data
        guard let text = String(validating: body, as: UTF8.self) else { throw Failure.notUTF8 }
        return Contents(text: text, hasByteOrderMark: hasByteOrderMark)
    }

    static func describe(_ failure: Failure) -> String {
        switch failure {
        case .tooLarge(let byteCount):
            let limit = ByteCountFormatter.string(fromByteCount: Int64(maximumByteCount), countStyle: .file)
            let actual = ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
            return "This file is \(actual). iKhalacy opens files up to \(limit)."
        case .notText:
            return "This doesn't look like a text file."
        case .notUTF8:
            return "iKhalacy only opens UTF-8 text, and this file uses another encoding."
        case .unreadable(let reason):
            return reason
        }
    }
}
