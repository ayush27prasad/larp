import AppKit
import SwiftUI

@main
struct LarpApp: App {
    @State private var workspace = Workspace()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(Appearance.defaultsKey) private var appearance: Appearance = .system

    var body: some Scene {
        // A single Window, not a WindowGroup: a WindowGroup opens an extra
        // window for every folder or file handed over by Finder or `open -a`,
        // all sharing one workspace and each starting its own shells.
        Window("Larp", id: "main") {
            WorkspaceView()
                .environment(workspace)
                .task { appDelegate.attach(workspace) }
                .onChange(of: appearance, initial: true) {
                    NSApp.appearance = appearance.nsAppearance
                }
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
            CommandGroup(after: .sidebar) {
                Button("Toggle Markdown Preview") {
                    workspace.editor.activeDocument?.showsPreview.toggle()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(workspace.editor.activeDocument?.isMarkdown != true)

                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                }
            }
        }
    }

    private func openFolder() {
        guard let url = FolderPicker.chooseFolder() else { return }
        Task { await workspace.open(folder: url) }
    }
}
