import Foundation

/// Reads a file into a string, refusing anything that isn't editable text.
enum TextFileLoader {
    /// Files above this are refused rather than loaded into a single `String`.
    static let maximumByteCount = 4 * 1024 * 1024

    enum Failure: Error, Equatable {
        case tooLarge(byteCount: Int)
        case notText
        case unreadable(String)
    }

    static func load(_ url: URL) async throws -> String {
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

        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .utf16) { return text }
        throw Failure.notText
    }

    static func describe(_ failure: Failure) -> String {
        switch failure {
        case .tooLarge(let byteCount):
            let limit = ByteCountFormatter.string(fromByteCount: Int64(maximumByteCount), countStyle: .file)
            let actual = ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
            return "This file is \(actual). iKhalacy opens files up to \(limit)."
        case .notText:
            return "This doesn't look like a text file."
        case .unreadable(let reason):
            return reason
        }
    }
}
