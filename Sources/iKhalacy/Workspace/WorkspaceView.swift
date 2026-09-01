import SwiftUI

/// The window shell: explorer on the left, editor above terminal on the right.
struct WorkspaceView: View {
    @Environment(Workspace.self) private var workspace

    var body: some View {
        NavigationSplitView {
            ExplorerPane()
                .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 420)
        } detail: {
            VSplitView {
                EditorPane()
                    .frame(minHeight: 200, maxHeight: .infinity)
                TerminalPane()
                    .frame(minHeight: 80, idealHeight: 200)
            }
        }
        .navigationTitle(workspace.rootURL?.lastPathComponent ?? "iKhalacy")
        .navigationSubtitle(workspace.activeFileURL?.lastPathComponent ?? "")
    }
}

#Preview {
    WorkspaceView()
        .environment(Workspace())
        .frame(width: 900, height: 600)
}
