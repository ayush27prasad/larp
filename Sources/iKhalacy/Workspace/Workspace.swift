import Foundation
import Observation

/// The state shared by the three panes: which folder is open, its file tree,
/// and which file is active.
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

    /// File selected in the explorer. Directories never land here.
    var activeFileURL: URL? {
        didSet { persist(activeFileURL?.path, forKey: Self.activeFileKey) }
    }

    private let defaults: UserDefaults
    private static let lastFolderKey = "workspace.lastFolderPath"
    private static let activeFileKey = "workspace.activeFilePath"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasOpenFolder: Bool { rootURL != nil }

    func open(folder url: URL) async {
        rootURL = url
        activeFileURL = nil
        treeState = .loading
        defaults.set(url.path, forKey: Self.lastFolderKey)

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

    /// Reopens the folder and file from the last session, if both still exist.
    func restoreLastFolder() async {
        guard rootURL == nil,
              let folderPath = defaults.string(forKey: Self.lastFolderKey),
              FileManager.default.fileExists(atPath: folderPath)
        else { return }

        // Read before open(folder:) clears it.
        let filePath = defaults.string(forKey: Self.activeFileKey)
        await open(folder: URL(fileURLWithPath: folderPath, isDirectory: true))

        if let filePath, FileManager.default.fileExists(atPath: filePath) {
            activeFileURL = URL(fileURLWithPath: filePath)
        }
    }

    func closeFolder() {
        rootURL = nil
        activeFileURL = nil
        treeState = .empty
        defaults.removeObject(forKey: Self.lastFolderKey)
    }

    private func persist(_ value: String?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
