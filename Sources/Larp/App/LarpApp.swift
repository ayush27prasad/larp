import AppKit
import SwiftUI

@main
struct LarpApp: App {
    @State private var workspace = Workspace()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Pin the whole app to light, AppKit-hosted panes included — SwiftUI's
        // preferredColorScheme alone doesn't reach the editor or terminal views.
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
    }

    var body: some Scene {
        WindowGroup {
            WorkspaceView()
                .environment(workspace)
                .preferredColorScheme(.light)
                .task { appDelegate.attach(workspace) }
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
            CommandGroup(replacing: .saveItem) {
                Button("Save") { workspace.saveActiveDocument() }
                    .keyboardShortcut("s")
                    .disabled(workspace.editor.activeDocument == nil)
                Button("New Terminal") { workspace.newTerminal() }
                    .keyboardShortcut("t")
                Button("Close Tab") { workspace.closeFocusedTab() }
                    .keyboardShortcut("w")
            }
        }
    }

    private func openFolder() {
        guard let url = FolderPicker.chooseFolder() else { return }
        Task { await workspace.open(folder: url) }
    }
}
