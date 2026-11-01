import SwiftUI

/// Left pane: the file tree for the open folder.
/// Single click previews a file; double click pins it in a tab.
struct ExplorerPane: View {
    @Environment(Workspace.self) private var workspace

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
                List(selection: $workspace.selectedFileURL) {
                    OutlineGroup(root.children ?? [], id: \.id, children: \.children) { node in
                        row(for: node)
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

            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't read that folder", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Only files carry a tag and a double-click action; folders just disclose.
    /// Selecting the row previews the file; double-clicking pins its tab.
    @ViewBuilder
    private func row(for node: FileNode) -> some View {
        let label = Label(node.name, systemImage: FileIcon.symbolName(for: node))
        if node.isDirectory {
            label
        } else {
            label
                .tag(node.url)
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        Task { await workspace.openFile(node.url, preview: false) }
                    })
        }
    }

    private func chooseFolder() {
        guard let url = FolderPicker.chooseFolder() else { return }
        Task { await workspace.open(folder: url) }
    }
}
