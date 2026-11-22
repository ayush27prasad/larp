import CodeEditSourceEditor
import SwiftUI

/// Middle pane: tabs across the top, the active file below — as source, or
/// rendered when it is markdown — with its path above and status beneath.
struct EditorPane: View {
    @Environment(Workspace.self) private var workspace
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uiZoom) private var zoom

    @State private var editorState = SourceEditorState()

    var body: some View {
        VStack(spacing: 0) {
            EditorTabBar(
                documents: workspace.editor.documents,
                // No tab looks selected while a refusal stands in for them.
                activeID: workspace.editor.refusal == nil ? workspace.editor.activeDocumentID : nil,
                previewID: workspace.editor.previewDocumentID,
                onSelect: { workspace.activate($0) },
                onClose: { workspace.closeFile($0) })
            content
                // Fill the rest, so the tab strip stays pinned to the top even
                // when the placeholder alone would be shorter than the pane.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: Chrome.contentBackground), ignoresSafeAreaEdges: [])
        // The find bar follows the active file, and its matches follow edits.
        .onChange(of: workspace.editor.activeDocumentID, initial: true) {
            let document = workspace.editor.activeDocument
            document?.findModel = workspace.editor.find
            workspace.editor.find.document = document
        }
        .onChange(of: workspace.editor.activeDocument?.text) {
            workspace.editor.find.refresh(revealing: false)
        }
        // Highlights are layers with fixed colours and positions: recolour
        // them on an appearance switch, and re-place them when zoom re-lays
        // the text out.
        .onChange(of: colorScheme) {
            workspace.editor.find.refresh(revealing: false)
        }
        .onChange(of: zoom * (workspace.editor.activeDocument?.zoom ?? 1)) {
            DispatchQueue.main.async { workspace.editor.find.refresh(revealing: false) }
        }
    }

    private var content: some View {
        VStack(spacing: 0) { contentRows }
    }

    @ViewBuilder
    private var contentRows: some View {
        if let refusal = workspace.editor.refusal {
            ContentUnavailableView {
                Label(refusal.url.lastPathComponent, systemImage: "doc.questionmark")
            } description: {
                Text(refusal.reason)
            }
        } else if let document = workspace.editor.activeDocument {
            PathBar(document: document, root: workspace.rootURL)
            Divider()
            if workspace.editor.find.isVisible {
                FindBar(find: workspace.editor.find)
            }
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

    /// The editor state minus its stock find panel's fields. That state is
    /// shared by every file, so once the stock panel had opened, its open flag
    /// and query were replayed onto each file opened after — grey, doubled
    /// match boxes everywhere. Stripped, the editor is never told to show it;
    /// larp's own find bar is the only one larp drives.
    private var editorStateWithoutFind: Binding<SourceEditorState> {
        Binding(
            get: {
                var state = editorState
                state.findPanelVisible = nil
                state.findText = nil
                state.replaceText = nil
                return state
            },
            set: { editorState = $0 })
    }

    private func editor(for document: OpenDocument) -> some View {
        @Bindable var document = document

        return SourceEditor(
            $document.text,
            language: document.language,
            configuration: SourceEditorConfiguration(
                appearance: .init(
                    theme: colorScheme == .dark ? .larpDark : .larpLight,
                    font: .monospacedSystemFont(ofSize: 12.5 * zoom * document.zoom, weight: .regular),
                    lineHeightMultiple: 1.35,
                    wrapLines: false,
                    tabWidth: 4),
                peripherals: .init(showMinimap: false)),
            state: editorStateWithoutFind,
            coordinators: [document.bridge])
            // Rebuild per file so undo history and scroll don't leak across tabs.
            .id(document.id)
    }
}
