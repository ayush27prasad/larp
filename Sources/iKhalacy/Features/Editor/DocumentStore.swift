import Foundation
import Observation

/// The files open in tabs, and which one is showing.
///
/// One tab may be a *preview*: opened by a single click, shown in italics, and
/// replaced by the next single click rather than accumulating. Double-clicking
/// pins it. This is VS Code's model, and it keeps browsing a repository from
/// leaving forty tabs behind.
@Observable
@MainActor
final class DocumentStore {
    /// A file that was asked for but couldn't be opened, and why.
    struct Refusal: Equatable {
        let url: URL
        let reason: String
    }

    private(set) var documents: [OpenDocument] = []
    private(set) var previewDocumentID: URL?

    /// Shown in place of the editor until a tab is chosen, so a click on a
    /// binary file explains itself instead of appearing to do nothing.
    private(set) var refusal: Refusal?

    var activeDocumentID: URL? {
        didSet { refusal = nil }
    }

    var activeDocument: OpenDocument? {
        documents.first { $0.id == activeDocumentID }
    }

    var hasOpenDocuments: Bool { !documents.isEmpty }
    var openURLs: [URL] { documents.map(\.url) }

    func isPreview(_ id: URL) -> Bool { previewDocumentID == id }

    /// Opens `url`, or focuses the tab it is already in.
    /// - Parameter preview: single-click open. A preview tab is reused by the
    ///   next preview; a pinned one is not.
    @discardableResult
    func open(_ url: URL, preview: Bool = false) async throws -> OpenDocument {
        if let existing = documents.first(where: { $0.url == url }) {
            activeDocumentID = existing.id
            // Double-clicking a preview tab pins it.
            if !preview, previewDocumentID == existing.id { previewDocumentID = nil }
            return existing
        }

        let contents: TextFileLoader.Contents
        do {
            contents = try await TextFileLoader.load(url)
        } catch {
            let reason = (error as? TextFileLoader.Failure).map(TextFileLoader.describe)
            refusal = Refusal(url: url, reason: reason ?? error.localizedDescription)
            throw error
        }
        let document = OpenDocument(
            url: url,
            text: contents.text,
            hasByteOrderMark: contents.hasByteOrderMark)

        if preview,
           let replacing = previewDocumentID,
           let index = documents.firstIndex(where: { $0.id == replacing }) {
            if documents[index].isDirty {
                // Never discard unsaved edits — pin it and open alongside.
                previewDocumentID = nil
                documents.append(document)
            } else {
                documents[index] = document
            }
        } else {
            documents.append(document)
        }

        activeDocumentID = document.id
        if preview { previewDocumentID = document.id }
        return document
    }

    /// Promotes a preview tab to a permanent one.
    func pin(_ id: URL) {
        guard previewDocumentID == id else { return }
        previewDocumentID = nil
    }

    func close(_ id: URL) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents.remove(at: index)
        if previewDocumentID == id { previewDocumentID = nil }

        guard activeDocumentID == id else { return }
        // Focus the tab to the left, the way editors do.
        activeDocumentID = documents.isEmpty ? nil : documents[max(0, index - 1)].id
    }

    func closeAll() {
        documents.removeAll()
        activeDocumentID = nil
        previewDocumentID = nil
    }
}
