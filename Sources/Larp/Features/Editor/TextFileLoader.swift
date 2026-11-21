import Foundation

/// Reads a file into a string and works out its encoding, refusing what isn't
/// editable text.
enum TextFileLoader {
    /// Files above this are refused rather than loaded into a single `String`.
    static let maximumByteCount = 4 * 1024 * 1024

    struct Contents: Equatable, Sendable {
        let text: String
        let encoding: TextEncoding
    }

    enum Failure: Error, Equatable {
        case tooLarge(byteCount: Int)
        case notText
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
        return try decode(data)
    }

    /// A byte-order mark wins. Otherwise NUL bytes mean binary, valid UTF-8 is
    /// UTF-8, and anything else is read as Windows 1252 — never guessed as
    /// UTF-16, whose decoder accepts almost any bytes and once turned Latin-1
    /// files into mojibake.
    static func decode(_ data: Data) throws -> Contents {
        if let marked = TextEncoding.marked.first(where: { data.starts(with: $0.byteOrderMark) }) {
            guard let text = marked.decode(data) else { throw Failure.notText }
            return Contents(text: text, encoding: marked)
        }

        // A NUL byte in the leading bytes is the usual cheap binary tell.
        // UTF-16 is full of them, which is why its mark is checked first.
        guard !data.prefix(8_192).contains(0) else { throw Failure.notText }

        for encoding in [TextEncoding.utf8, .windows1252, .latin1] {
            if let text = encoding.decode(data) { return Contents(text: text, encoding: encoding) }
        }
        throw Failure.notText
    }

    static func describe(_ failure: Failure) -> String {
        switch failure {
        case .tooLarge(let byteCount):
            let limit = ByteCountFormatter.string(fromByteCount: Int64(maximumByteCount), countStyle: .file)
            let actual = ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
            return "Only files up to \(limit) are supported. This one is \(actual)."
        case .notText:
            return "Only text files are supported."
        case .unreadable(let reason):
            return reason
        }
    }
}
