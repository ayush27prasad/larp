import Foundation
import Observation

/// The state shared by the three panes: the open folder, its file tree, the
/// explorer selection, and the documents open in tabs.
@Observable
@MainActor
final class Workspace {
    enum TreeState: Equatable {
        case empty
        case loading
        case loaded(FileNode, isTruncated: Bool)
        case failed(String)
    }

    private(set) var rootURL: URL?
    private(set) var treeState: TreeState = .empty

    /// Highlighted row in the explorer. Selecting a file opens it in a preview
    /// tab, or focuses the tab it is already in.
    var selectedFileURL: URL? {
        didSet {
            guard oldValue != selectedFileURL, let url = selectedFileURL else { return }
            Task { await previewSelection(url) }
        }
    }

    let editor = DocumentStore()
    let terminals = TerminalStore()

    private let defaults: UserDefaults
    private static let lastFolderKey = "workspace.lastFolderPath"
    private static let openFilesKey = "workspace.openFilePaths"
    private static let activeFileKey = "workspace.activeFilePath"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasOpenFolder: Bool { rootURL != nil }

    /// Where the terminal starts. The open project if there is one, else home.
    var terminalWorkingDirectory: URL {
        rootURL ?? FileManager.default.homeDirectoryForCurrentUser
    }

    // MARK: - Folders

    func open(folder url: URL) async {
        rootURL = url
        selectedFileURL = nil
        editor.closeAll()
        // Shells are rooted at the project, so a new project means new shells.
        terminals.closeAll()
        terminals.newSession(in: url)
        treeState = .loading
        defaults.set(url.path, forKey: Self.lastFolderKey)
        persistSession()

        do {
            let tree = try await FileTreeLoader.load(root: url)
            // A newer open() may have superseded this one while we walked disk.
            guard rootURL == url else { return }
            treeState = .loaded(tree.root, isTruncated: tree.isTruncated)
        } catch {
            guard rootURL == url else { return }
            treeState = .failed(error.localizedDescription)
        }
    }

    /// Opens something Finder handed us: a folder as the project root, or a
    /// file as its enclosing folder with the file already in a tab.
    func open(finderURL url: URL) async {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return
        }

        if isDirectory.boolValue {
            await open(folder: url)
        } else {
            await open(folder: url.deletingLastPathComponent())
            await openFile(url)
        }
    }

    func closeFolder() {
        rootURL = nil
        selectedFileURL = nil
        editor.closeAll()
        treeState = .empty
        defaults.removeObject(forKey: Self.lastFolderKey)
        persistSession()
    }

    // MARK: - Documents

    /// What a single click in the explorer does: preview the file, or focus the
    /// tab it is already in. Separate from the `selectedFileURL` observer so it
    /// can be awaited rather than raced.
    func previewSelection(_ url: URL) async {
        await openFile(url, preview: true)
    }

    /// - Parameter preview: true for a single click, which reuses the preview
    ///   tab; false for a double click, which pins the file.
    @discardableResult
    func openFile(_ url: URL, preview: Bool = false) async -> Bool {
        do {
            try await editor.open(url, preview: preview)
            selectedFileURL = url
            persistSession()
            return true
        } catch {
            return false
        }
    }

    func closeFile(_ url: URL) {
        editor.close(url)
        persistSession()
    }

    // MARK: - Terminals

    /// Guarantees a shell exists, for launches where no folder is restored.
    func ensureTerminal() {
        guard !terminals.hasSessions else { return }
        terminals.newSession(in: terminalWorkingDirectory)
    }

    func newTerminal() {
        terminals.newSession(in: terminalWorkingDirectory)
    }

    /// ⌘W closes whichever pane has focus, the way editors behave.
    func closeFocusedTab() {
        if terminals.hasFocus, let id = terminals.activeSessionID {
            terminals.close(id)
        } else if let url = editor.activeDocumentID {
            closeFile(url)
        }
    }

    func saveActiveDocument() throws {
        try editor.activeDocument?.save()
    }

    func activate(_ url: URL) {
        editor.activeDocumentID = url
        persistSession()
    }

    // MARK: - Session

    /// Reopens the folder, tabs, and active tab from the last session.
    func restoreLastFolder() async {
        guard rootURL == nil,
              let folderPath = defaults.string(forKey: Self.lastFolderKey),
              FileManager.default.fileExists(atPath: folderPath)
        else { return }

        // Read before open(folder:) clears them.
        let openPaths = defaults.stringArray(forKey: Self.openFilesKey) ?? []
        let activePath = defaults.string(forKey: Self.activeFileKey)

        await open(folder: URL(fileURLWithPath: folderPath, isDirectory: true))

        for path in openPaths where FileManager.default.fileExists(atPath: path) {
            _ = try? await editor.open(URL(fileURLWithPath: path))
        }
        if let activePath, editor.openURLs.contains(URL(fileURLWithPath: activePath)) {
            editor.activeDocumentID = URL(fileURLWithPath: activePath)
        }
        persistSession()
    }

    private func persistSession() {
        defaults.set(editor.openURLs.map(\.path), forKey: Self.openFilesKey)
        if let active = editor.activeDocumentID?.path {
            defaults.set(active, forKey: Self.activeFileKey)
        } else {
            defaults.removeObject(forKey: Self.activeFileKey)
        }
    }
}
