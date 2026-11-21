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
    @State private var input = InputMonitor()

    private enum PointerPane { case editor, terminal }

    /// What a zoom acts on, and which pill shows it.
    private enum ZoomTarget { case app, editor, terminal }
    @State private var zoomHUD: ZoomTarget?
    @State private var zoomHUDGeneration = 0
    @State private var zoomHUDIsHovered = false

    /// How long the pill lingers after the last change.
    private static let zoomHUDLinger = Duration.milliseconds(1_500)

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
                        .overlay(alignment: .topTrailing) {
                            if let target = zoomHUD, target != .terminal {
                                zoomPill(for: target)
                                    .padding(.top, (Chrome.tabBarHeight + 28) * appZoom + 10)
                                    .padding(.trailing, 14)
                            }
                        }
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
                    .overlay(alignment: .topTrailing) {
                        if zoomHUD == .terminal {
                            zoomPill(for: .terminal)
                                .padding(.top, Chrome.tabBarHeight * appZoom + 10)
                                .padding(.trailing, 14)
                        }
                    }
            }
        }
        .overlay {
            if workspace.search.isPresented {
                ZStack(alignment: .top) {
                    // Click outside to close, as with IntelliJ's popup.
                    Color.black.opacity(0.25)
                        .contentShape(.rect)
                        .onTapGesture { workspace.search.dismiss() }
                    FindInFilesPanel(search: workspace.search, root: workspace.rootURL) { match in
                        Task { await workspace.open(match) }
                    }
                    .frame(maxWidth: 820, maxHeight: 560)
                    .padding(.horizontal, 60)
                    .padding(.top, 70)
                    .padding(.bottom, 60)
                }
                .transition(.opacity)
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
        .onAppear { input.start(handleInput) }
        .onDisappear { input.stop() }
        // Each editor that appears registers its own key monitor, which runs
        // ahead of ours; re-register so ⌘F and friends reach larp first.
        .onReceive(NotificationCenter.default.publisher(for: EditorBridge.editorDidAppear)) { _ in
            input.restart()
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

    private func track(_ pane: PointerPane, isInside: Bool) {
        if isInside {
            pointerPane = pane
        } else if pointerPane == pane {
            pointerPane = nil
        }
    }

    /// - Returns: whether the input was used, so nothing else acts on it.
    private func handleInput(_ command: InputMonitor.Command) -> Bool {
        switch command {
        case .appZoom(let steps):
            zoom(.app, by: steps)
            return true
        case .find(let replace):
            // ⌘F in the terminal stays the terminal's.
            guard !workspace.terminals.hasFocus else { return false }
            return workspace.showFind(replace: replace)
        case .toggleFindOption(let option):
            // Whichever search is showing: Find in Files, then the find bar.
            if workspace.search.isPresented {
                toggle(option, in: &workspace.search.options)
            } else if workspace.editor.find.isVisible {
                toggle(option, in: &workspace.editor.find.options)
            } else {
                return false
            }
            return true
        case .findAgain(let forward):
            let find = workspace.editor.find
            guard find.isVisible, !find.matches.isEmpty else { return false }
            forward ? find.next() : find.previous()
            return true
        case .pointerZoom(let steps):
            let target: ZoomTarget
            switch pointerPane {
            case .editor:
                guard workspace.editor.activeDocument != nil else { return false }
                target = .editor
            case .terminal:
                guard workspace.terminals.activeSessionID != nil else { return false }
                target = .terminal
            case nil:
                return false
            }
            // A trackpad reports many tiny deltas per step; only whole steps zoom.
            if steps != 0 { zoom(target, by: steps) }
            return true
        }
    }

    private func toggle(_ option: InputMonitor.FindOption, in options: inout ProjectSearch.Options) {
        switch option {
        case .matchCase: options.matchCase.toggle()
        case .wholeWord: options.wholeWord.toggle()
        case .regex: options.regex.toggle()
        }
    }

    /// One zoom change, from the keyboard, the pointer or the pill.
    /// - Parameter steps: nil resets to 100%.
    private func zoom(_ target: ZoomTarget, by steps: Int?) {
        switch target {
        case .app:
            var level = appZoom
            if let steps { Zoom.step(&level, by: steps, in: .app) } else { level = 1 }
            storedAppZoom = level
        case .editor:
            guard let document = workspace.editor.activeDocument else { return }
            if let steps { Zoom.step(&document.zoom, by: steps, in: .content) } else { document.zoom = 1 }
        case .terminal:
            guard let id = workspace.terminals.activeSessionID else { return }
            if let steps { workspace.terminals.zoom(id, by: steps) } else { workspace.terminals.resetZoom(id) }
        }
        showZoomHUD(for: target)
    }

    private func level(of target: ZoomTarget) -> Double {
        switch target {
        case .app: appZoom
        case .editor: workspace.editor.activeDocument?.zoom ?? 1
        case .terminal: workspace.terminals.activeSession?.zoom ?? 1
        }
    }

    private func zoomPill(for target: ZoomTarget) -> some View {
        let title: String? = switch target {
        case .app: nil
        case .editor: "File"
        case .terminal: "Terminal"
        }
        return ZoomHUD(
            title: title,
            level: level(of: target),
            range: target == .app ? Zoom.Scope.app.range : Zoom.Scope.content.range,
            onStep: { zoom(target, by: $0) },
            onReset: { zoom(target, by: nil) })
            .onHover { isInside in
                zoomHUDIsHovered = isInside
                if !isInside { scheduleZoomHUDHide() }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func showZoomHUD(for target: ZoomTarget) {
        withAnimation(.easeOut(duration: 0.12)) { zoomHUD = target }
        scheduleZoomHUDHide()
    }

    /// Hides the pill once zooming has paused, unless the pointer is on it.
    private func scheduleZoomHUDHide() {
        zoomHUDGeneration += 1
        let generation = zoomHUDGeneration
        Task {
            try? await Task.sleep(for: Self.zoomHUDLinger)
            guard generation == zoomHUDGeneration, !zoomHUDIsHovered else { return }
            withAnimation(.easeIn(duration: 0.2)) { zoomHUD = nil }
        }
    }

    /// The explorer under its header: window buttons, project name, toggle.
    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Color.clear.frame(width: windowButtonsWidth - 8)
                if workspace.hasOpenFolder {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11 * appZoom))
                        .foregroundStyle(Color(nsColor: Chrome.accent))
                }
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
