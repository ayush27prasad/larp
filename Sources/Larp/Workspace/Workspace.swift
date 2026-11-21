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

    /// Counts folder opens and closes. Comparing rootURL can't tell a restore
    /// apart from Finder reopening the very same folder mid-restore.
    private var folderGeneration = 0
    private(set) var treeState: TreeState = .empty

    /// Highlighted row in the explorer, file or folder. Selecting a file opens
    /// it in a preview tab, or focuses the tab it is already in; selecting a
    /// folder only highlights it.
    var selectedURL: URL? {
        didSet {
            guard oldValue != selectedURL, let url = selectedURL, !Self.isDirectory(url) else { return }
            Task { await previewSelection(url) }
        }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    let editor = DocumentStore()
    let terminals = TerminalStore()
    let search = SearchStore()

    private let defaults: UserDefaults
    private static let lastFolderKey = "workspace.lastFolderPath"
    private static let openFilesKey = "workspace.openFilePaths"
    private static let activeFileKey = "workspace.activeFilePath"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        search.files = { [weak self] in self?.projectFiles ?? [] }
    }

    /// Every file in the tree, in explorer order — what Find in Files searches.
    /// The tree's skip list keeps .git, node_modules and the like out.
    var projectFiles: [URL] {
        guard case .loaded(let root, _) = treeState else { return [] }
        var files: [URL] = []
        func collect(_ node: FileNode) {
            guard let children = node.children else { return files.append(node.url) }
            children.forEach(collect)
        }
        collect(root)
        return files
    }

    /// Opens ⌘F's find bar on the active file, seeded with the selection.
    /// - Returns: false with no file open, so the key passes through.
    @discardableResult
    func showFind(replace: Bool) -> Bool {
        guard let document = editor.activeDocument else { return false }
        // Find works on the source; leave the rendered preview for it.
        if document.isMarkdown && document.showsPreview { document.showsPreview = false }
        editor.find.show(replace: replace, prefill: document.bridge.selectedText)
        return true
    }

    /// Opens a search result in a regular tab, cursor on the match.
    func open(_ match: ProjectSearch.Match) async {
        search.dismiss()
        guard await openFile(match.url) else { return }
        editor.activeDocument?.pendingReveal = TextLocation(
            line: match.line, column: match.column, length: match.length)
    }

    var hasOpenFolder: Bool { rootURL != nil }

    /// Where the terminal starts. The open project if there is one, else home.
    var terminalWorkingDirectory: URL {
        rootURL ?? FileManager.default.homeDirectoryForCurrentUser
    }

    // MARK: - Folders

    /// - Returns: this open's generation, for callers that must notice being
    ///   superseded while it ran.
    @discardableResult
    func open(folder url: URL) async -> Int {
        folderGeneration += 1
        let generation = folderGeneration
        rootURL = url
        selectedURL = nil
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
            guard folderGeneration == generation else { return generation }
            treeState = .loaded(tree.root, isTruncated: tree.isTruncated)
            // A search opened while the tree loaded saw no files; rerun it.
            search.refresh()
        } catch {
            guard folderGeneration == generation else { return generation }
            treeState = .failed(error.localizedDescription)
        }
        return generation
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
        folderGeneration += 1
        rootURL = nil
        selectedURL = nil
        editor.closeAll()
        treeState = .empty
        defaults.removeObject(forKey: Self.lastFolderKey)
        persistSession()
    }

    // MARK: - Documents

    /// What a single click in the explorer does: preview the file, or focus the
    /// tab it is already in. Separate from the `selectedURL` observer so it
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
            selectedURL = url
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

    /// A save that failed, for the window to report. The document stays dirty,
    /// so nothing is lost by dismissing it.
    struct SaveFailure: Equatable {
        let fileName: String
        let reason: String
    }

    var saveFailure: SaveFailure?

    func saveActiveDocument() {
        guard let document = editor.activeDocument else { return }
        do {
            try document.save()
        } catch {
            saveFailure = SaveFailure(fileName: document.name, reason: error.localizedDescription)
        }
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

        let generation = await open(folder: URL(fileURLWithPath: folderPath, isDirectory: true))

        // A folder or file handed over by Finder while this ran wins — even
        // the same folder — so stop rather than mixing the old tabs in.
        for path in openPaths where FileManager.default.fileExists(atPath: path) {
            guard folderGeneration == generation else { return }
            _ = try? await editor.open(URL(fileURLWithPath: path))
        }
        guard folderGeneration == generation else { return }
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
