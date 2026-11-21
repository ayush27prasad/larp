import CodeEditSourceEditor
import SwiftUI

/// Middle pane: tabs across the top, the active file below — as source, or
/// rendered when it is markdown — with its path above and status beneath.
struct EditorPane: View {
    @Environment(Workspace.self) private var workspace
    @Environment(\.colorScheme) private var colorScheme

    @State private var editorState = SourceEditorState()

    var body: some View {
        VStack(spacing: 0) {
            if workspace.editor.hasOpenDocuments {
                EditorTabBar(
                    documents: workspace.editor.documents,
                    // No tab looks selected while a refusal stands in for them.
                    activeID: workspace.editor.refusal == nil ? workspace.editor.activeDocumentID : nil,
                    previewID: workspace.editor.previewDocumentID,
                    onSelect: { workspace.activate($0) },
                    onClose: { workspace.closeFile($0) })
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: Chrome.contentBackground), ignoresSafeAreaEdges: [])
    }

    @ViewBuilder
    private var content: some View {
        if let refusal = workspace.editor.refusal {
            ContentUnavailableView {
                Label(refusal.url.lastPathComponent, systemImage: "doc.questionmark")
            } description: {
                Text(refusal.reason)
            }
        } else if let document = workspace.editor.activeDocument {
            PathBar(document: document, root: workspace.rootURL)
            Divider()
            if document.isMarkdown && document.showsPreview {
                MarkdownPreview(document: document) { url in
                    Task { await workspace.openFile(url) }
                }
            } else {
                editor(for: document)
            }
            StatusBar(document: document, cursor: editorState.cursorPositions?.first)
        } else {
            ContentUnavailableView(
                "No file open",
                systemImage: "doc.text",
                description: Text("Select a file in the explorer to open it."))
        }
    }

    private func editor(for document: OpenDocument) -> some View {
        @Bindable var document = document

        return SourceEditor(
            $document.text,
            language: document.language,
            configuration: SourceEditorConfiguration(
                appearance: .init(
                    theme: colorScheme == .dark ? .larpDark : .larpLight,
                    font: .monospacedSystemFont(ofSize: 12.5, weight: .regular),
                    lineHeightMultiple: 1.35,
                    wrapLines: false,
                    tabWidth: 4),
                peripherals: .init(showMinimap: false)),
            state: $editorState)
            // Rebuild per file so undo history and scroll don't leak across tabs.
            .id(document.id)
    }
}
