import AppKit
import SwiftUI

@main
struct LarpApp: App {
    @State private var workspace = Workspace()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(Appearance.defaultsKey) private var appearance: Appearance = .system
    @AppStorage(Layout.sidebarVisibleKey) private var sidebarIsVisible = true
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Zoom.appKey) private var storedAppZoom = 1.0
    private var appZoom: Double { Zoom.clamped(storedAppZoom, in: .app) }

    var body: some Scene {
        // A single Window, not a WindowGroup: a WindowGroup opens an extra
        // window for every folder or file handed over by Finder or `open -a`,
        // all sharing one workspace and each starting its own shells.
        Window("Larp", id: "main") {
            WorkspaceView()
                .environment(workspace)
                .task { appDelegate.attach(workspace, openWindow: openWindow) }
                .onChange(of: appearance, initial: true) {
                    NSApp.appearance = appearance.nsAppearance
                }
        }
        // No title bar: the sidebar header and the editor's tab strip run to
        // the top of the window, and the window buttons sit over the sidebar.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1_280, height: 800)
        // Always open the window at launch, even if it was closed when the
        // app last quit: a single-window app with no window is just a menu bar.
        .defaultLaunchBehavior(.presented)
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
            CommandGroup(after: .textEditing) {
                // The keys reach InputMonitor first; these make them discoverable.
                Button("Find…") { workspace.showFind(replace: false) }
                    .keyboardShortcut("f")
                    .disabled(workspace.editor.activeDocument == nil)
                Button("Find and Replace…") { workspace.showFind(replace: true) }
                    .keyboardShortcut("f", modifiers: [.command, .option])
                    .disabled(workspace.editor.activeDocument == nil)
                Button("Find Next") { workspace.editor.find.next() }
                    .keyboardShortcut("g")
                    .disabled(workspace.editor.find.matches.isEmpty)
                Button("Find Previous") { workspace.editor.find.previous() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                    .disabled(workspace.editor.find.matches.isEmpty)
                Divider()
                Button("Find in Files…") { workspace.search.present() }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                    .disabled(!workspace.hasOpenFolder)
            }
            CommandGroup(replacing: .sidebar) {
                Button(sidebarIsVisible ? "Hide Sidebar" : "Show Sidebar") {
                    withAnimation(.easeInOut(duration: 0.18)) { sidebarIsVisible.toggle() }
                }
                .keyboardShortcut("s", modifiers: [.control, .command])

                Button("Toggle Markdown Preview") {
                    workspace.editor.activeDocument?.showsPreview.toggle()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(workspace.editor.activeDocument?.isMarkdown != true)

                Divider()
                // The keys themselves are caught first by InputMonitor, which
                // also accepts ⌘+ (⌘⇧=); these items make the zoom discoverable.
                Button("Zoom In") { storedAppZoom = Zoom.stepped(appZoom, by: 1, in: .app) }
                    .keyboardShortcut("=")
                    .disabled(appZoom >= Zoom.Scope.app.range.upperBound)
                Button("Zoom Out") { storedAppZoom = Zoom.stepped(appZoom, by: -1, in: .app) }
                    .keyboardShortcut("-")
                    .disabled(appZoom <= Zoom.Scope.app.range.lowerBound)
                Button("Actual Size") { storedAppZoom = 1 }
                    .keyboardShortcut("0")
                    .disabled(appZoom == 1)
                Divider()

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
