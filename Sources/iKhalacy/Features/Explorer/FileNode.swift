import Foundation

/// One entry in the project tree.
///
/// Directories carry a `children` array; files carry `nil`. `OutlineGroup` reads
/// exactly that distinction to decide whether to draw a disclosure triangle.
struct FileNode: Identifiable, Hashable, Sendable {
    let url: URL
    let children: [FileNode]?

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var isDirectory: Bool { children != nil }
}
