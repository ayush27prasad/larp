import Foundation
import Testing

@testable import Larp

struct ProjectSearchTests {
    private func search(
        _ query: String,
        _ options: ProjectSearch.Options = .init(),
        files: [(String, Data)],
        limit: Int = ProjectSearch.maximumMatches
    ) async throws -> ProjectSearch.Result {
        let temp = try TempDirectory()
        let urls = try files.map { try temp.write($0.1, to: $0.0) }
        return await ProjectSearch.search(query, options: options, in: urls, limit: limit)
    }

    private func text(_ string: String) -> Data { Data(string.utf8) }

    @Test func findsTextCaseInsensitivelyByDefault() async throws {
        let result = try await search("total", files: [("a.py", text("x = 1\ndef calculate_Total():\n    total = 0\n"))])
        #expect(result.matchCount == 2)
        #expect(result.files.first?.matches.map(\.line) == [2, 3])
    }

    @Test func matchCaseNarrowsIt() async throws {
        let result = try await search("Total", .init(matchCase: true), files: [("a.py", text("total\nTotal\n"))])
        #expect(result.files.first?.matches.map(\.line) == [2])
    }

    @Test func wholeWordSkipsPartOfALongerName() async throws {
        let result = try await search("order", .init(wholeWord: true), files: [("a.go", text("orders := 1\norder := 2\n"))])
        #expect(result.files.first?.matches.map(\.line) == [2])
    }

    @Test func regexSearches() async throws {
        let result = try await search("V\\d+__", .init(regex: true), files: [("m.txt", text("V1__init\nV12__view\nnotes\n"))])
        #expect(result.matchCount == 2)
    }

    @Test func reportsAnInvalidPattern() async throws {
        let result = try await search("(unclosed", .init(regex: true), files: [("a.txt", text("x"))])
        #expect(result.isInvalidPattern)
    }

    @Test func treatsRegexCharactersLiterallyWhenRegexIsOff() async throws {
        let result = try await search("a.b", files: [("a.txt", text("axb\na.b\n"))])
        #expect(result.files.first?.matches.map(\.line) == [2])
    }

    @Test func countsCRLFLinesLikeTheEditor() async throws {
        let result = try await search("hit", files: [("a.txt", text("one\r\ntwo\r\nhit\r\n"))])
        #expect(result.files.first?.matches.first?.line == 3)
    }

    @Test func pointsAtTheMatchAndTrimsThePreview() async throws {
        let result = try await search("total", files: [("a.py", text("    return total\n"))])
        let match = try #require(result.files.first?.matches.first)
        #expect(match.column == 12)
        #expect(match.length == 5)
        #expect(match.preview == "return total")
        #expect(match.highlights == [NSRange(location: 7, length: 5)])
    }

    @Test func skipsBinaryFilesAndSearchesOtherEncodings() async throws {
        let result = try await search("café", files: [
            ("blob.bin", Data([0x00, 0x63, 0x61, 0x66])),
            ("latin1.txt", "café".data(using: .isoLatin1)!),
        ])
        #expect(result.files.map(\.url.lastPathComponent) == ["latin1.txt"])
    }

    @Test func stopsAtTheLimit() async throws {
        let result = try await search("x", files: [("a.txt", text(String(repeating: "x\n", count: 50)))], limit: 10)
        #expect(result.matchCount == 10)
        #expect(result.isTruncated)
    }
}

@MainActor
struct FindInFilesTests {
    private func makeWorkspace() -> Workspace {
        Workspace(defaults: UserDefaults(suiteName: "LarpTests-\(UUID().uuidString)")!)
    }

    @Test func searchesTheOpenFolderAndOpensAResultAtItsLine() async throws {
        let temp = try TempDirectory()
        try temp.write("a = 1\n", to: "one.py")
        // The temp folder sits behind a /var -> /private/var symlink, which the
        // tree walk resolves.
        let target = try temp.write("x\ny\n    total = 0\n", to: "sub/two.py").resolvingSymlinksInPath()
        try temp.write("total", to: ".git/HEAD")

        let workspace = makeWorkspace()
        await workspace.open(folder: temp.url)
        workspace.search.present()
        workspace.search.query = "total"
        await workspace.search.searchNow()

        // .git is skipped, as in the explorer.
        #expect(workspace.search.result.files.map { $0.url.resolvingSymlinksInPath() } == [target])
        let match = try #require(workspace.search.selectedMatch)

        await workspace.open(match)
        #expect(workspace.search.isPresented == false)
        #expect(workspace.editor.activeDocumentID?.resolvingSymlinksInPath() == target)
        // No editor view in tests, so the reveal waits for one.
        #expect(workspace.editor.activeDocument?.pendingReveal == TextLocation(line: 3, column: 5, length: 5))
    }

    @Test func movesTheSelectionThroughMatchesAcrossFiles() async throws {
        let temp = try TempDirectory()
        try temp.write("hit\nhit\n", to: "a.txt")
        try temp.write("hit\n", to: "b.txt")

        let workspace = makeWorkspace()
        await workspace.open(folder: temp.url)
        workspace.search.present()
        workspace.search.query = "hit"
        await workspace.search.searchNow()

        let ids = workspace.search.matches.map(\.id)
        #expect(workspace.search.selectedMatchID == ids[0])
        workspace.search.moveSelection(by: 1)
        workspace.search.moveSelection(by: 1)
        #expect(workspace.search.selectedMatchID == ids[2])
        workspace.search.moveSelection(by: 1)
        #expect(workspace.search.selectedMatchID == ids[2])
    }
}

@MainActor
struct FindInFilesRefreshTests {
    @Test func aSearchOpenedBeforeTheTreeLoadsRunsWhenItDoes() async throws {
        let temp = try TempDirectory()
        try temp.write("total\n", to: "a.py")

        let workspace = Workspace(defaults: UserDefaults(suiteName: "LarpTests-\(UUID().uuidString)")!)
        workspace.search.present()
        workspace.search.query = "total"
        await workspace.search.searchNow()
        #expect(workspace.search.result.matchCount == 0)

        await workspace.open(folder: temp.url)
        // The refresh waits out the typing pause before searching.
        try await Task.sleep(for: .milliseconds(400))
        #expect(workspace.search.result.matchCount == 1)
    }
}
