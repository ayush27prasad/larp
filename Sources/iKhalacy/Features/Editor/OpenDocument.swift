import CodeEditLanguages
import Foundation
import Observation

/// A file open in a tab, with its unsaved edits.
@Observable
@MainActor
final class OpenDocument: Identifiable {
    let url: URL

    /// Detected once from the file name; drives syntax highlighting.
    let language: CodeLanguage

    var text: String {
        didSet { isDirty = text != savedText }
    }

    /// Contents as of the last successful read or write.
    private var savedText: String
    private(set) var isDirty = false

    private let hasByteOrderMark: Bool

    nonisolated var id: URL { url }
    var name: String { url.lastPathComponent }

    init(url: URL, text: String, hasByteOrderMark: Bool = false) {
        self.url = url
        self.text = text
        self.savedText = text
        self.hasByteOrderMark = hasByteOrderMark
        // The prefix lets extensionless files be detected by shebang or modeline.
        self.language = CodeLanguage.detectLanguageFrom(
            url: url,
            prefixBuffer: String(text.prefix(1_024)))
    }

    func save() throws {
        var data = hasByteOrderMark ? TextFileLoader.byteOrderMark : Data()
        data.append(contentsOf: text.utf8)
        try data.write(to: url, options: .atomic)
        savedText = text
        isDirty = false
    }
}
