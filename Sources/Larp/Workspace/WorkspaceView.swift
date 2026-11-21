import SwiftUI

/// The window shell.
///
/// Explorer and editor share the upper part; the terminal spans the full width
/// beneath both, rather than being boxed into the column right of the sidebar.
struct WorkspaceView: View {
    @Environment(Workspace.self) private var workspace

    /// Remembered across launches. VSplitView was dropped because it divided
    /// the window evenly whenever it couldn't settle on ideal heights.
    @AppStorage("layout.terminalHeight") private var terminalHeight = 240.0
    @State private var dragStartHeight: Double?

    private static let minimumTerminalHeight = 90.0
    private static let minimumEditorHeight = 200.0

    var body: some View {
        GeometryReader { geometry in
            let height = clamped(terminalHeight, in: geometry.size.height)
            VStack(spacing: 0) {
                NavigationSplitView {
                    ExplorerPane()
                        .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 420)
                } detail: {
                    EditorPane()
                }
                .navigationTitle(workspace.rootURL?.lastPathComponent ?? "Larp")
                .navigationSubtitle(
                    workspace.editor.refusal?.url.lastPathComponent
                        ?? workspace.editor.activeDocument?.name ?? "")
                .frame(maxHeight: .infinity)
                .toolbarBackground(Color(nsColor: Chrome.barBackground), for: .windowToolbar)
                .toolbarBackground(.visible, for: .windowToolbar)

                divider(totalHeight: geometry.size.height)

                TerminalPane()
                    .frame(height: height)
            }
        }
        .tint(Color(nsColor: Chrome.accent))
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

    /// A hairline with a taller grab area, dragged to resize the terminal.
    private func divider(totalHeight: Double) -> some View {
        Rectangle()
            .fill(Color(nsColor: Chrome.separator))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .contentShape(.rect)
            .padding(.vertical, -3)
            .pointerStyle(.rowResize)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartHeight ?? clamped(terminalHeight, in: totalHeight)
                        dragStartHeight = start
                        terminalHeight = clamped(start - value.translation.height, in: totalHeight)
                    }
                    .onEnded { _ in dragStartHeight = nil })
            .zIndex(1)
    }

    private func clamped(_ height: Double, in total: Double) -> Double {
        let maximum = max(Self.minimumTerminalHeight, total - Self.minimumEditorHeight)
        return min(max(height, Self.minimumTerminalHeight), maximum)
    }
}
