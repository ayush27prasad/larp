import SwiftUI

/// The window shell.
///
/// A frameless window: the sidebar header and the editor's tab strip are its
/// top edge, with the window buttons over the sidebar. Explorer and editor
/// share the upper part; the terminal spans the full width beneath both.
/// Both dividers drag, and every size is remembered.
struct WorkspaceView: View {
    @Environment(Workspace.self) private var workspace

    @AppStorage(Layout.terminalHeightKey) private var terminalHeight = 240.0
    @AppStorage(Layout.sidebarWidthKey) private var sidebarWidth = 260.0
    @AppStorage(Layout.sidebarVisibleKey) private var sidebarIsVisible = true
    @State private var dragStartHeight: Double?
    @State private var dragStartWidth: Double?
    @State private var isFullScreen = false

    @AppStorage(Zoom.appKey) private var storedAppZoom = 1.0
    /// Clamped on read: a stored level may predate the limits.
    private var appZoom: Double { Zoom.clamped(storedAppZoom, in: .app) }
    /// Which pane ⌘-scroll and pinch zoom: the one under the pointer.
    @State private var pointerPane: PointerPane?
    @State private var zoomInput = ZoomInputMonitor()

    private enum PointerPane { case editor, terminal }

    /// Room for the window buttons, which full screen hides.
    private var windowButtonsWidth: CGFloat { isFullScreen ? 8 : Layout.windowButtonsWidth }

    private static let minimumTerminalHeight = 90.0
    private static let minimumEditorHeight = 200.0
    private static let sidebarWidthRange = 180.0...480.0

    var body: some View {
        GeometryReader { geometry in
            let height = clamped(terminalHeight, in: geometry.size.height)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    if sidebarIsVisible {
                        sidebar
                            .frame(width: min(max(sidebarWidth, Self.sidebarWidthRange.lowerBound), Self.sidebarWidthRange.upperBound))
                            .transition(.move(edge: .leading))
                        verticalDivider
                    }
                    EditorPane()
                        .onHover { track(.editor, isInside: $0) }
                        .environment(\.tabStripLeadingInset, sidebarIsVisible ? 0 : windowButtonsWidth + 32)
                        .overlay(alignment: .topLeading) {
                            if !sidebarIsVisible {
                                SidebarToggle()
                                    .frame(height: Chrome.tabBarHeight * appZoom)
                                    .padding(.leading, windowButtonsWidth)
                            }
                        }
                }
                .frame(maxHeight: .infinity)

                divider(totalHeight: geometry.size.height)

                TerminalPane()
                    .frame(height: height)
                    .onHover { track(.terminal, isInside: $0) }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .navigationTitle(workspace.rootURL?.lastPathComponent ?? "Larp")
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
        .tint(Color(nsColor: Chrome.accent))
        .environment(\.uiZoom, appZoom)
        .onAppear { zoomInput.start(handleZoom) }
        .onDisappear { zoomInput.stop() }
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

    private func track(_ pane: PointerPane, isInside: Bool) {
        if isInside {
            pointerPane = pane
        } else if pointerPane == pane {
            pointerPane = nil
        }
    }

    /// - Returns: whether the input was used, so it doesn't also scroll.
    private func handleZoom(_ command: ZoomInputMonitor.Command) -> Bool {
        switch command {
        case .app(let steps):
            var zoom = appZoom
            if let steps { Zoom.step(&zoom, by: steps, in: .app) } else { zoom = 1 }
            storedAppZoom = zoom
            return true
        case .pointer(let steps):
            switch pointerPane {
            case .editor:
                guard let document = workspace.editor.activeDocument else { return false }
                if steps != 0 { Zoom.step(&document.zoom, by: steps, in: .content) }
                return true
            case .terminal:
                guard let id = workspace.terminals.activeSessionID else { return false }
                if steps != 0 { workspace.terminals.zoom(id, by: steps) }
                return true
            case nil:
                return false
            }
        }
    }

    /// The explorer under its header: window buttons, project name, toggle.
    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Color.clear.frame(width: windowButtonsWidth - 8)
                Text(workspace.rootURL?.lastPathComponent ?? "Larp")
                    .font(.system(size: 12 * appZoom, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                SidebarToggle()
            }
            .padding(.trailing, 6)
            .frame(height: Chrome.tabBarHeight * appZoom)
            .contentShape(.rect)
            .dragsWindow()
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(nsColor: Chrome.separator)).frame(height: 1)
            }
            ExplorerPane()
        }
        .background(Color(nsColor: Chrome.sidebarBackground), ignoresSafeAreaEdges: [])
    }

    /// Between sidebar and editor; dragged to resize the sidebar.
    private var verticalDivider: some View {
        Rectangle()
            .fill(Color(nsColor: Chrome.separator))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 3)
            .contentShape(.rect)
            .padding(.horizontal, -3)
            .pointerStyle(.columnResize)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartWidth ?? sidebarWidth
                        dragStartWidth = start
                        sidebarWidth = min(max(start + value.translation.width, Self.sidebarWidthRange.lowerBound),
                                           Self.sidebarWidthRange.upperBound)
                    }
                    .onEnded { _ in dragStartWidth = nil })
            .zIndex(1)
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
