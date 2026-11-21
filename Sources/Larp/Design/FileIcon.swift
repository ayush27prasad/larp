import Foundation
import SwiftUI

/// The SF Symbol and colour beside each file, in the explorer and on tabs.
enum FileIcon {
    private static let symbolsByExtension: [String: String] = [
        "swift": "swift",
        "md": "text.alignleft", "markdown": "text.alignleft", "txt": "doc.plaintext",
        "json": "curlybraces", "yml": "curlybraces", "yaml": "curlybraces", "toml": "curlybraces",
        "html": "chevron.left.forwardslash.chevron.right", "xml": "chevron.left.forwardslash.chevron.right",
        "css": "paintbrush",
        "sh": "terminal", "zsh": "terminal", "bash": "terminal",
        "sql": "cylinder", "sqlite": "cylinder", "db": "cylinder",
        "png": "photo", "jpg": "photo", "jpeg": "photo", "gif": "photo", "svg": "photo", "webp": "photo",
        "lock": "lock",
    ]

    private static let symbolsByName: [String: String] = [
        "dockerfile": "shippingbox", "makefile": "hammer",
        "license": "checkmark.seal", ".gitignore": "eye.slash", ".gitattributes": "eye.slash",
    ]

    private static let codeExtensions: Set<String> = [
        "py", "js", "jsx", "ts", "tsx", "java", "kt", "rb", "go", "rs", "proto",
        "c", "h", "cpp", "hpp", "cs", "php", "scala", "m", "mm",
    ]

    /// Language colours, loosely after each language's own branding.
    private static let tintsByExtension: [String: Color] = [
        "swift": .orange, "py": .blue, "js": .yellow, "jsx": .yellow, "ts": .blue, "tsx": .blue,
        "go": .cyan, "rs": .brown, "java": .red, "kt": .purple, "rb": .red, "proto": .teal,
        "c": .indigo, "h": .indigo, "cpp": .indigo, "hpp": .indigo, "cs": .purple, "php": .indigo,
        "html": .orange, "xml": .orange, "css": .blue,
        "json": .green, "yml": .pink, "yaml": .pink, "toml": .pink,
        "sh": .green, "zsh": .green, "bash": .green,
        "sql": .teal, "sqlite": .teal, "db": .teal,
        "png": .mint, "jpg": .mint, "jpeg": .mint, "gif": .mint, "svg": .mint, "webp": .mint,
    ]

    static func symbolName(for node: FileNode) -> String {
        symbolName(for: node.url, isDirectory: node.isDirectory)
    }

    static func symbolName(for url: URL, isDirectory: Bool) -> String {
        if isDirectory { return "folder" }
        if let symbol = symbolsByName[url.lastPathComponent.lowercased()] { return symbol }
        let ext = url.pathExtension.lowercased()
        if let symbol = symbolsByExtension[ext] { return symbol }
        if codeExtensions.contains(ext) { return "chevron.left.forwardslash.chevron.right" }
        return "doc"
    }

    static func tint(for url: URL, isDirectory: Bool) -> Color {
        if isDirectory { return .blue }
        return tintsByExtension[url.pathExtension.lowercased()] ?? .secondary
    }

    /// An icon view, ready to drop into a label.
    static func image(for url: URL, isDirectory: Bool = false) -> some View {
        Image(systemName: symbolName(for: url, isDirectory: isDirectory))
            .foregroundStyle(tint(for: url, isDirectory: isDirectory))
    }
}
