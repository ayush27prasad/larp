import Foundation

/// Walks a folder on disk and builds a `FileNode` tree.
///
/// The walk is eager. Lazy per-expansion loading would scale further, but it
/// needs expansion callbacks `OutlineGroup` does not provide; the skip list and
/// node budget below keep the eager walk bounded in the meantime.
enum FileTreeLoader {
    /// Skipped wholesale: large, generated, or pure noise. Dotfiles are *not*
    /// hidden in general — `.gitignore` and `.env` are files people want to open.
    static let ignoredDirectoryNames: Set<String> = [
        ".git", ".hg", ".svn", ".build", "node_modules", "DerivedData", "__pycache__",
    ]

    static let ignoredFileNames: Set<String> = [".DS_Store"]

    /// Upper bound on entries walked, so opening a huge folder cannot hang the app.
    static let nodeLimit = 20_000

    struct Tree: Sendable {
        let root: FileNode
        /// True when `nodeLimit` was hit and the tree on screen is incomplete.
        let isTruncated: Bool
    }

    static func load(root url: URL) async throws -> Tree {
        var budget = nodeLimit
        let root = try walk(url, budget: &budget)
        return Tree(root: root, isTruncated: budget <= 0)
    }

    private static func walk(_ url: URL, budget: inout Int) throws -> FileNode {
        let entries = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [])

        var children: [FileNode] = []
        for entry in entries where budget > 0 {
            let name = entry.lastPathComponent
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if isDirectory {
                guard !ignoredDirectoryNames.contains(name) else { continue }
                budget -= 1
                // An unreadable subfolder shouldn't abort the whole load.
                let child = (try? walk(entry, budget: &budget)) ?? FileNode(url: entry, children: [])
                children.append(child)
            } else {
                guard !ignoredFileNames.contains(name) else { continue }
                budget -= 1
                children.append(FileNode(url: entry, children: nil))
            }
        }

        return FileNode(url: url, children: children.sorted(by: precedes))
    }

    /// Folders first, then case- and number-aware alphabetical.
    private static func precedes(_ lhs: FileNode, _ rhs: FileNode) -> Bool {
        if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
