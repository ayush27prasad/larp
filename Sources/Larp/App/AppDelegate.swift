import AppKit
import SwiftUI

/// Receives folders opened from Finder — "Open With", drag onto the icon, or
/// `open -a Larp <path>` — and hands them to the workspace.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var workspace: Workspace?
    private var openWindow: OpenWindowAction?

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
    func attach(_ workspace: Workspace, openWindow: OpenWindowAction) {
        guard self.workspace == nil else { return }
        self.workspace = workspace
        self.openWindow = openWindow

        let pending = deferredURLs
        deferredURLs = []
        handle(pending, in: workspace)
    }

    private func handle(_ urls: [URL], in workspace: Workspace) {
        // One window, so only the first target is meaningful.
        guard let url = urls.first else { return }
        // The one window may have been closed; a folder handed over by Finder
        // should bring it back rather than open invisibly.
        if !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) {
            openWindow?(id: "main")
        }
        Task { await workspace.open(finderURL: url) }
    }
}
