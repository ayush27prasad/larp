import Foundation
import Testing

@testable import Larp

struct FileIconTests {
    @Test(arguments: [
        ("Model.swift", "swift"),
        ("README.md", "text.alignleft"),
        ("config.json", "curlybraces"),
        ("main.py", "chevron.left.forwardslash.chevron.right"),
        ("Widget.java", "chevron.left.forwardslash.chevron.right"),
        ("LICENSE", "doc"),
    ])
    func picksASymbolPerFileType(name: String, expected: String) {
        let node = FileNode(url: URL(fileURLWithPath: "/tmp/\(name)"), children: nil)
        #expect(FileIcon.symbolName(for: node) == expected)
    }

    @Test func usesAFolderSymbolForDirectories() {
        let node = FileNode(url: URL(fileURLWithPath: "/tmp/src"), children: [])
        #expect(FileIcon.symbolName(for: node) == "folder")
    }
}
