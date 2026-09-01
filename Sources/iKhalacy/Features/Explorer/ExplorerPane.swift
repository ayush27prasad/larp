import SwiftUI

/// Left pane: the file tree for the open folder.
/// Tree loading and selection land in a later milestone.
struct ExplorerPane: View {
    @Environment(Workspace.self) private var workspace

    var body: some View {
        Group {
            if workspace.hasOpenFolder {
                ContentUnavailableView("File tree pending", systemImage: "folder")
            } else {
                ContentUnavailableView(
                    "No folder open",
                    systemImage: "folder.badge.plus",
                    description: Text("Open a folder to browse its files.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ExplorerPane()
        .environment(Workspace())
        .frame(width: 240, height: 500)
}
