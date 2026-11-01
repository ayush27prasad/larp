import Foundation

/// SF Symbol shown beside each entry in the tree.
enum FileIcon {
    private static let symbolsByExtension: [String: String] = [
        "swift": "swift",
        "md": "text.alignleft", "markdown": "text.alignleft", "txt": "doc.plaintext",
        "json": "curlybraces", "yml": "curlybraces", "yaml": "curlybraces", "toml": "curlybraces",
        "html": "chevron.left.forwardslash.chevron.right",
        "css": "paintbrush",
        "sh": "terminal", "zsh": "terminal", "bash": "terminal",
    ]

    private static let codeExtensions: Set<String> = [
        "py", "js", "jsx", "ts", "tsx", "java", "kt", "rb", "go", "rs",
        "c", "h", "cpp", "hpp", "cs", "php", "scala", "m", "mm",
    ]

    static func symbolName(for node: FileNode) -> String {
        if node.isDirectory { return "folder" }
        let ext = node.url.pathExtension.lowercased()
        if let symbol = symbolsByExtension[ext] { return symbol }
        if codeExtensions.contains(ext) { return "chevron.left.forwardslash.chevron.right" }
        return "doc"
    }
}
