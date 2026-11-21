import Foundation

/// How a file's bytes map to text, remembered per document so a save writes
/// the same encoding — and the same byte-order mark — that was read.
struct TextEncoding: Equatable, Sendable {
    let name: String
    let encoding: String.Encoding
    let byteOrderMark: Data

    static let utf8 = TextEncoding(name: "UTF-8", encoding: .utf8, byteOrderMark: Data())
    static let utf8WithBOM = TextEncoding(name: "UTF-8 with BOM", encoding: .utf8, byteOrderMark: Data([0xEF, 0xBB, 0xBF]))
    static let utf16LittleEndian = TextEncoding(name: "UTF-16 LE", encoding: .utf16LittleEndian, byteOrderMark: Data([0xFF, 0xFE]))
    static let utf16BigEndian = TextEncoding(name: "UTF-16 BE", encoding: .utf16BigEndian, byteOrderMark: Data([0xFE, 0xFF]))
    /// The fallback for text that isn't valid UTF-8. A superset of Latin-1's
    /// printable range, and what "extended ASCII" files almost always are.
    static let windows1252 = TextEncoding(name: "Windows 1252", encoding: .windowsCP1252, byteOrderMark: Data())
    /// Decodes any byte sequence, so it catches what Windows 1252 leaves undefined.
    static let latin1 = TextEncoding(name: "ISO 8859-1", encoding: .isoLatin1, byteOrderMark: Data())

    /// Encodings announced by a byte-order mark, checked before anything else.
    static let marked: [TextEncoding] = [.utf8WithBOM, .utf16LittleEndian, .utf16BigEndian]

    struct Unrepresentable: LocalizedError, Equatable {
        let encoding: String

        var errorDescription: String? {
            "Only characters in \(encoding) can be saved to this file."
        }
    }

    func decode(_ data: Data) -> String? {
        let body = data.dropFirst(byteOrderMark.count)
        if encoding == .utf8 {
            // Strict, and unlike String(data:encoding:) it never strips a
            // second byte-order mark from the text.
            return String(validating: body, as: UTF8.self)
        }
        return String(data: body, encoding: encoding)
    }

    /// - Throws: `Unrepresentable` when the text holds a character this
    ///   encoding can't — rather than writing a lossy approximation.
    func encode(_ text: String) throws -> Data {
        guard let body = text.data(using: encoding, allowLossyConversion: false) else {
            throw Unrepresentable(encoding: name)
        }
        return byteOrderMark + body
    }
}
