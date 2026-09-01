import SwiftUI

@main
struct iKhalacyApp: App {
    @State private var workspace = Workspace()

    var body: some Scene {
        WindowGroup {
            WorkspaceView()
                .environment(workspace)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1_280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") { openFolder() }
                    .keyboardShortcut("o")
                Button("Close Folder") { workspace.closeFolder() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                    .disabled(!workspace.hasOpenFolder)
            }
        }
    }

    private func openFolder() {
        guard let url = FolderPicker.chooseFolder() else { return }
        Task { await workspace.open(folder: url) }
    }
}
