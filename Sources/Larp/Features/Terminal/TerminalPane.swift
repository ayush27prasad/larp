import SwiftUI

/// Bottom pane: tabs across the top, the active shell below.
struct TerminalPane: View {
    @Environment(Workspace.self) private var workspace
    @Environment(\.uiZoom) private var zoom

    /// The pane's height when expanded. The shells keep it while the pane
    /// collapses — clipped rather than resized — so the PTY isn't sent a
    /// resize per animation frame and prompts don't redraw mid-fold.
    let expandedHeight: Double

    var body: some View {
        VStack(spacing: 0) {
            TerminalTabBar(
                sessions: workspace.terminals.sessions,
                activeID: workspace.terminals.activeSessionID,
                isCollapsed: workspace.terminals.isCollapsed,
                onSelect: {
                    workspace.terminals.activeSessionID = $0
                    workspace.terminals.isCollapsed = false
                },
                onClose: { workspace.terminals.close($0) },
                onRename: { workspace.terminals.rename($0, to: $1) },
                onAdd: { workspace.newTerminal() },
                onToggleCollapse: { workspace.terminals.isCollapsed.toggle() })
            TerminalStack(store: workspace.terminals)
                .frame(height: max(0, expandedHeight - Chrome.tabBarHeight * zoom))
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: Chrome.contentBackground), ignoresSafeAreaEdges: [])
    }
}

/// Left-aligned tabs sized to their titles, the way editor tabs are, with the
/// add button straight after them.
private struct TerminalTabBar: View {
    let sessions: [TerminalSession]
    let activeID: TerminalSession.ID?
    let isCollapsed: Bool
    let onSelect: (TerminalSession.ID) -> Void
    let onClose: (TerminalSession.ID) -> Void
    let onRename: (TerminalSession.ID, String) -> Void
    let onAdd: () -> Void
    let onToggleCollapse: () -> Void

    @Environment(\.uiZoom) private var zoom

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(sessions) { session in
                        TerminalTab(
                            session: session,
                            isActive: session.id == activeID,
                            onSelect: { onSelect(session.id) },
                            onClose: { onClose(session.id) },
                            onRename: { onRename(session.id, $0) })
                    }
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 11 * zoom, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 32 * zoom, height: Chrome.tabBarHeight * zoom)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .help("New Terminal (⌘T)")
                }
            }
            .scrollIndicators(.never)
            Spacer(minLength: 0)
            IconButton(
                symbol: isCollapsed ? "chevron.up" : "chevron.down",
                help: isCollapsed ? "Show Terminal (⌘J)" : "Hide Terminal (⌘J)",
                action: onToggleCollapse)
                .padding(.trailing, 8)
        }
        .frame(height: Chrome.tabBarHeight * zoom)
        .background(Color(nsColor: Chrome.barBackground), ignoresSafeAreaEdges: [])
        .overlay(alignment: .bottom) { Rectangle().fill(Color(nsColor: Chrome.separator)).frame(height: 1) }
    }
}

private struct TerminalTab: View {
    let session: TerminalSession
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onRename: (String) -> Void

    @State private var isRenaming = false
    @State private var draft = ""
    @FocusState private var fieldIsFocused: Bool
    @Environment(\.uiZoom) private var zoom

    var body: some View {
        PaneTab(isActive: isActive) { isHovered in
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 11 * zoom))
                if isRenaming {
                    TextField("", text: $draft)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 80, maxWidth: 160)
                        .focused($fieldIsFocused)
                        .onSubmit(commit)
                        // Escape abandons the edit and keeps the old name.
                        .onExitCommand { isRenaming = false }
                        .onChange(of: fieldIsFocused) { _, focused in
                            if !focused { commit() }
                        }
                } else {
                    Text(session.title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 180)
                }
                TabCloseButton(isVisible: isHovered || isActive || isRenaming, action: onClose)
            }
        }
        .onTapGesture(count: 2, perform: beginRenaming)
        .onTapGesture(perform: onSelect)
        .help(isRenaming ? "" : "\(session.workingDirectory.path) — double-click to rename")
    }

    private func beginRenaming() {
        draft = session.title
        isRenaming = true
        fieldIsFocused = true
    }

    private func commit() {
        guard isRenaming else { return }
        isRenaming = false
        onRename(draft)
    }
}
