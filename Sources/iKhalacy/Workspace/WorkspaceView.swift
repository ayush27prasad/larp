import SwiftUI

/// The window shell.
///
/// Explorer and editor share the upper half; the terminal spans the full width
/// beneath both, rather than being boxed into the column right of the sidebar.
struct WorkspaceView: View {
    @Environment(Workspace.self) private var workspace

    var body: some View {
        VSplitView {
            NavigationSplitView {
                ExplorerPane()
                    .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 420)
            } detail: {
                EditorPane()
            }
            .navigationTitle(workspace.rootURL?.lastPathComponent ?? "iKhalacy")
            .navigationSubtitle(
                workspace.editor.refusal?.url.lastPathComponent
                    ?? workspace.editor.activeDocument?.name ?? "")
            .frame(minHeight: 200, maxHeight: .infinity)

            TerminalPane()
                .frame(minHeight: 80, idealHeight: 220)
        }
        // Restoring here, not in a pane: the panes swap views as the tree loads,
        // which would cancel the task partway through.
        .task {
            await workspace.restoreLastFolder()
            workspace.ensureTerminal()
        }
        .alert(
            "Couldn't save \(workspace.saveFailure?.fileName ?? "the file")",
            isPresented: Binding(
                get: { workspace.saveFailure != nil },
                set: { if !$0 { workspace.saveFailure = nil } }),
            presenting: workspace.saveFailure
        ) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure.reason)
        }
    }
}
