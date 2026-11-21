import SwiftUI

/// Bottom pane: tabs across the top, the active shell below.
struct TerminalPane: View {
    @Environment(Workspace.self) private var workspace

    var body: some View {
        VStack(spacing: 0) {
            TerminalTabBar(
                sessions: workspace.terminals.sessions,
                activeID: workspace.terminals.activeSessionID,
                onSelect: { workspace.terminals.activeSessionID = $0 },
                onClose: { workspace.terminals.close($0) },
                onRename: { workspace.terminals.rename($0, to: $1) },
                onAdd: { workspace.newTerminal() })
            TerminalStack(store: workspace.terminals)
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
    let onSelect: (TerminalSession.ID) -> Void
    let onClose: (TerminalSession.ID) -> Void
    let onRename: (TerminalSession.ID, String) -> Void
    let onAdd: () -> Void

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
