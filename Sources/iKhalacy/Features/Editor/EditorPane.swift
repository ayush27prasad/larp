import SwiftUI

/// Middle pane: contents of the active file.
/// Text loading, editing, and highlighting land in later milestones.
struct EditorPane: View {
    @Environment(Workspace.self) private var workspace

    var body: some View {
        Group {
            if let url = workspace.activeFileURL {
                ContentUnavailableView(url.lastPathComponent, systemImage: "doc.text")
            } else {
                ContentUnavailableView(
                    "No file open",
                    systemImage: "doc.text",
                    description: Text("Select a file in the explorer to view it here.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

#Preview {
    EditorPane()
        .environment(Workspace())
        .frame(width: 700, height: 400)
}
