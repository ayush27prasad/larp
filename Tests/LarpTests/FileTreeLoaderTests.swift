import Foundation
import Testing

@testable import Larp

struct FileTreeLoaderTests {
    @Test func listsFoldersBeforeFilesAndSortsNaturally() async throws {
        let temp = try TempDirectory()
        try temp.write("", to: "banana.txt")
        try temp.write("", to: "apple.txt")
        try temp.write("", to: "item10.txt")
        try temp.write("", to: "item2.txt")
        try temp.makeDirectory("zebra")

        let tree = try await FileTreeLoader.load(root: temp.url)
        let names = (tree.root.children ?? []).map(\.name)

        #expect(names == ["zebra", "apple.txt", "banana.txt", "item2.txt", "item10.txt"])
    }

    @Test func skipsNoiseDirectoriesButKeepsDotfiles() async throws {
        let temp = try TempDirectory()
        try temp.write("", to: ".git/HEAD")
        try temp.write("", to: "node_modules/left-pad/index.js")
        try temp.write("", to: ".gitignore")
        try temp.write("", to: ".DS_Store")

        let tree = try await FileTreeLoader.load(root: temp.url)
        let names = (tree.root.children ?? []).map(\.name)

        #expect(names == [".gitignore"])
    }

    @Test func nestsChildrenAndMarksFilesAsLeaves() async throws {
        let temp = try TempDirectory()
        try temp.write("print()", to: "src/utils/strings.py")

        let tree = try await FileTreeLoader.load(root: temp.url)
        let src = try #require(tree.root.children?.first)
        #expect(src.isDirectory)

        let utils = try #require(src.children?.first)
        #expect(utils.name == "utils")

        let file = try #require(utils.children?.first)
        #expect(file.name == "strings.py")
        #expect(file.isDirectory == false)
        #expect(file.children == nil)
    }

    @Test func reportsAnUntruncatedTreeForSmallFolders() async throws {
        let temp = try TempDirectory()
        try temp.write("", to: "only.txt")

        let tree = try await FileTreeLoader.load(root: temp.url)
        #expect(tree.isTruncated == false)
    }

    @Test func throwsWhenTheRootIsMissing() async {
        let missing = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)", isDirectory: true)
        await #expect(throws: (any Error).self) {
            try await FileTreeLoader.load(root: missing)
        }
    }
}
