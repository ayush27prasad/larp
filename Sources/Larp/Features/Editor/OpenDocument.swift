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

    var isMarkdown: Bool { language.id == .markdown }

    /// Read once on open; saving keeps whatever endings the text has.
    let usesCRLF: Bool

    /// Where to put the cursor and scroll to, e.g. a search result. Applied —
    /// and cleared — by `bridge` once this document's editor is on screen.
    var pendingReveal: TextLocation? {
        didSet { bridge.revealPending() }
    }

    /// Where the cursor is, mirrored from the editor for the status bar.
    var cursor: TextLocation?

    /// The find bar, while it is searching this document.
    @ObservationIgnored weak var findModel: FindModel?

    /// Connects this document to its editor view while one is showing.
    @ObservationIgnored let bridge = EditorBridge()

    /// Outside the project, as library source is: viewable, never saved.
    var isReadOnly = false

    /// This file's own zoom, on top of the app's; ⌘-scroll over the editor.
    var zoom = 1.0

    /// Markdown opens rendered; ⇧⌘V flips to the source and back.
    var showsPreview: Bool

    /// Read on open and used again on save, so the bytes round-trip.
    let encoding: TextEncoding

    nonisolated var id: URL { url }
    var name: String { url.lastPathComponent }

    init(url: URL, text: String, encoding: TextEncoding = .utf8) {
        self.url = url
        self.text = text
        self.savedText = text
        self.encoding = encoding
        // The prefix lets extensionless files be detected by shebang or modeline.
        let language = LanguageDetection.language(for: url, prefix: String(text.prefix(1_024)))
        self.language = language
        self.showsPreview = language.id == .markdown
        self.usesCRLF = text.contains("\r\n")
        bridge.document = self
    }

    func save() throws {
        guard !isReadOnly else { return }
        try encoding.encode(text).write(to: url, options: .atomic)
        savedText = text
        isDirty = false
    }
}
