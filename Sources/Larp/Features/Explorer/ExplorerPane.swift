import SwiftUI

/// Left pane: the file tree for the open folder.
///
/// Single click selects any row; for a file that also opens a preview tab.
/// Double click pins a file's tab, or expands and collapses a folder, which
/// its disclosure arrow also does on a single click.
struct ExplorerPane: View {
    @Environment(Workspace.self) private var workspace

    /// Folders currently disclosed. Kept here rather than left to
    /// `OutlineGroup`, which owns its expansion state and gives no way to
    /// toggle it from a double click.
    @State private var expanded: Set<URL> = []

    var body: some View {
        @Bindable var workspace = workspace

        Group {
            switch workspace.treeState {
            case .empty:
                ContentUnavailableView {
                    Label("No folder open", systemImage: "folder.badge.plus")
                } description: {
                    Text("Open a folder to browse its files.")
                } actions: {
                    Button("Open Folder…") { chooseFolder() }
                }

            case .loading:
                ProgressView().controlSize(.small)

            case .loaded(let root, let isTruncated):
                List(selection: $workspace.selectedURL) {
                    ForEach(root.children ?? []) { node in
                        FileTreeRow(node: node, expanded: $expanded)
                    }
                    if isTruncated {
                        Label(
                            "Tree truncated at \(FileTreeLoader.nodeLimit) items",
                            systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)

            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't read that folder", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: Chrome.sidebarBackground))
        // A different folder is a different tree; nothing should stay open.
        .onChange(of: workspace.rootURL) { expanded = [] }
    }

    private func chooseFolder() {
        guard let url = FolderPicker.chooseFolder() else { return }
        Task { await workspace.open(folder: url) }
    }
}

private struct FileTreeRow: View {
    @Environment(Workspace.self) private var workspace

    let node: FileNode
    @Binding var expanded: Set<URL>

    var body: some View {
        if let children = node.children {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(children) { child in
                    FileTreeRow(node: child, expanded: $expanded)
                }
            } label: {
                label.onDoubleTap { isExpanded.wrappedValue.toggle() }
            }
            .tag(node.url)
        } else {
            label
                .tag(node.url)
                .onDoubleTap {
                    Task { await workspace.openFile(node.url, preview: false) }
                }
        }
    }

    private var label: some View {
        Label {
            Text(node.name)
        } icon: {
            FileIcon.image(for: node.url, isDirectory: node.isDirectory)
        }
    }

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { expanded.contains(node.url) },
            set: { if $0 { expanded.insert(node.url) } else { expanded.remove(node.url) } })
    }
}

private extension View {
    /// Simultaneous, so the list still selects the row on the first click.
    func onDoubleTap(perform action: @escaping () -> Void) -> some View {
        simultaneousGesture(TapGesture(count: 2).onEnded(action))
    }
}
