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
            CommandGroup(replacing: .newItem) {}
        }
    }
}
