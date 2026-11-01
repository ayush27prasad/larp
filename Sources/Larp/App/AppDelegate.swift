import AppKit

/// Receives folders opened from Finder — "Open With", drag onto the icon, or
/// `open -a Larp <path>` — and hands them to the workspace.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var workspace: Workspace?

    /// URLs that arrived before the scene existed. Launching by dropping a
    /// folder on the icon delivers the URL before the window is built.
    private var deferredURLs: [URL] = []

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let workspace else {
            deferredURLs = urls
            return
        }
        handle(urls, in: workspace)
    }

    /// Called once the scene is up, draining anything that arrived early.
    func attach(_ workspace: Workspace) {
        guard self.workspace == nil else { return }
        self.workspace = workspace

        let pending = deferredURLs
        deferredURLs = []
        handle(pending, in: workspace)
    }

    private func handle(_ urls: [URL], in workspace: Workspace) {
        // One window, so only the first target is meaningful.
        guard let url = urls.first else { return }
        Task { await workspace.open(finderURL: url) }
    }
}
