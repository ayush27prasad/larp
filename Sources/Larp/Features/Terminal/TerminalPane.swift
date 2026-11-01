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
            Divider()
            TerminalStack(store: workspace.terminals)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Tabs share the width evenly — one fills the bar, two take half each, and so
/// on — with the add button pinned at a fixed width on the right.
private struct TerminalTabBar: View {
    let sessions: [TerminalSession]
    let activeID: TerminalSession.ID?
    let onSelect: (TerminalSession.ID) -> Void
    let onClose: (TerminalSession.ID) -> Void
    let onRename: (TerminalSession.ID, String) -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(sessions) { session in
                TerminalTab(
                    session: session,
                    isActive: session.id == activeID,
                    onSelect: { onSelect(session.id) },
                    onClose: { onClose(session.id) },
                    onRename: { onRename(session.id, $0) })
                    .frame(maxWidth: .infinity)
                Divider().frame(height: 14)
            }

            Button(action: onAdd) {
                Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .frame(width: 28)
            .help("New Terminal (⌘T)")
        }
        .frame(height: 28)
        .background(.quaternary.opacity(0.4))
    }
}

private struct TerminalTab: View {
    let session: TerminalSession
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onRename: (String) -> Void

    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var draft = ""
    @FocusState private var fieldIsFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isRenaming ? 1 : 0)
            .frame(width: 14, height: 14)

            if isRenaming {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .focused($fieldIsFocused)
                    .onSubmit(commit)
                    // Escape abandons the edit and keeps the old name.
                    .onExitCommand { isRenaming = false }
                    .onChange(of: fieldIsFocused) { _, focused in
                        if !focused { commit() }
                    }
            } else {
                Text(session.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(isActive ? AnyShapeStyle(.background) : AnyShapeStyle(.clear))
        .contentShape(.rect)
        .onTapGesture(count: 2, perform: beginRenaming)
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
        .help(isRenaming ? "" : session.workingDirectory.path)
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
