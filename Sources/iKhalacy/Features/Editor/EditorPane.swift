import SwiftUI

/// Middle pane: contents of the active file.
///
/// Read-only for now — editing and saving arrive in the next milestone.
struct EditorPane: View {
    @Environment(Workspace.self) private var workspace

    @State private var contents = ""
    @State private var failureMessage: String?

    var body: some View {
        Group {
            if let url = workspace.activeFileURL {
                if let failureMessage {
                    ContentUnavailableView {
                        Label(url.lastPathComponent, systemImage: "doc.questionmark")
                    } description: {
                        Text(failureMessage)
                    }
                } else {
                    TextEditor(text: .constant(contents))
                        .font(.system(.body, design: .monospaced))
                        .textEditorStyle(.plain)
                        .scrollContentBackground(.hidden)
                }
            } else {
                ContentUnavailableView(
                    "No file open",
                    systemImage: "doc.text",
                    description: Text("Select a file in the explorer to view it here."))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .task(id: workspace.activeFileURL) { await loadActiveFile() }
    }

    private func loadActiveFile() async {
        guard let url = workspace.activeFileURL else {
            contents = ""
            failureMessage = nil
            return
        }
        do {
            contents = try await TextFileLoader.load(url)
            failureMessage = nil
        } catch let failure as TextFileLoader.Failure {
            contents = ""
            failureMessage = TextFileLoader.describe(failure)
        } catch {
            contents = ""
            failureMessage = error.localizedDescription
        }
    }
}

#Preview {
    EditorPane()
        .environment(Workspace())
        .frame(width: 700, height: 400)
}
