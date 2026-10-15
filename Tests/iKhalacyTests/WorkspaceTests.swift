import Foundation
import Testing

@testable import iKhalacy

@MainActor
struct WorkspaceTests {
    /// Isolated defaults so tests never touch the real app's stored folder.
    private func makeWorkspace() -> Workspace {
        let suite = UserDefaults(suiteName: "iKhalacyTests-\(UUID().uuidString)")!
        return Workspace(defaults: suite)
    }

    @Test func startsWithNoOpenFolder() {
        let workspace = makeWorkspace()
        #expect(workspace.rootURL == nil)
        #expect(workspace.selectedFileURL == nil)
        #expect(workspace.hasOpenFolder == false)
        #expect(workspace.treeState == .empty)
    }

    @Test func loadsTheTreeWhenAFolderOpens() async throws {
        let temp = try TempDirectory()
        try temp.write("# Title", to: "README.md")

        let workspace = makeWorkspace()
        await workspace.open(folder: temp.url)

        #expect(workspace.hasOpenFolder)
        guard case .loaded(let root, let isTruncated) = workspace.treeState else {
            Issue.record("expected a loaded tree, got \(workspace.treeState)")
            return
        }
        #expect(isTruncated == false)
        #expect(root.children?.map(\.name) == ["README.md"])
    }

    @Test func reportsFailureForAnUnreadableFolder() async {
        let workspace = makeWorkspace()
        await workspace.open(folder: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"))

        guard case .failed = workspace.treeState else {
            Issue.record("expected a failed tree, got \(workspace.treeState)")
            return
        }
    }

    @Test func restoresTheFolderFromTheLastSession() async throws {
        let temp = try TempDirectory()
        try temp.write("", to: "a.txt")

        let suite = UserDefaults(suiteName: "iKhalacyTests-\(UUID().uuidString)")!
        let first = Workspace(defaults: suite)
        await first.open(folder: temp.url)

        let second = Workspace(defaults: suite)
        await second.restoreLastFolder()
        #expect(second.rootURL == temp.url)
    }

    @Test func doesNotRestoreAFolderThatNoLongerExists() async {
        let suite = UserDefaults(suiteName: "iKhalacyTests-\(UUID().uuidString)")!
        suite.set("/nonexistent-\(UUID().uuidString)", forKey: "workspace.lastFolderPath")

        let workspace = Workspace(defaults: suite)
        await workspace.restoreLastFolder()
        #expect(workspace.hasOpenFolder == false)
    }

    @Test func restoresOpenTabsFromTheLastSession() async throws {
        let temp = try TempDirectory()
        let a = try temp.write("1", to: "a.txt")
        let b = try temp.write("2", to: "b.txt")

        let suite = UserDefaults(suiteName: "iKhalacyTests-\(UUID().uuidString)")!
        let first = Workspace(defaults: suite)
        await first.open(folder: temp.url)
        await first.openFile(a)
        await first.openFile(b)

        let second = Workspace(defaults: suite)
        await second.restoreLastFolder()
        #expect(second.editor.openURLs == [a, b])
        #expect(second.editor.activeDocumentID == b)
    }

    @Test func doesNotRestoreATabWhoseFileWasDeleted() async throws {
        let temp = try TempDirectory()
        let a = try temp.write("1", to: "a.txt")
        let b = try temp.write("2", to: "b.txt")

        let suite = UserDefaults(suiteName: "iKhalacyTests-\(UUID().uuidString)")!
        let first = Workspace(defaults: suite)
        await first.open(folder: temp.url)
        await first.openFile(a)
        await first.openFile(b)
        try FileManager.default.removeItem(at: b)

        let second = Workspace(defaults: suite)
        await second.restoreLastFolder()
        #expect(second.editor.openURLs == [a])
    }

    @Test func openingAnotherFolderClosesEveryTab() async throws {
        let temp = try TempDirectory()
        let file = try temp.write("1", to: "a.txt")

        let workspace = makeWorkspace()
        await workspace.open(folder: temp.url)
        await workspace.openFile(file)
        #expect(workspace.editor.hasOpenDocuments)

        let other = try TempDirectory()
        await workspace.open(folder: other.url)
        #expect(workspace.editor.hasOpenDocuments == false)
    }

    @Test func terminalStartsInTheProjectFolder() async throws {
        let temp = try TempDirectory()
        let workspace = makeWorkspace()
        await workspace.open(folder: temp.url)
        #expect(workspace.terminalWorkingDirectory == temp.url)
    }

    @Test func terminalFallsBackToHomeWithNoFolderOpen() {
        let workspace = makeWorkspace()
        #expect(workspace.terminalWorkingDirectory == FileManager.default.homeDirectoryForCurrentUser)
    }

    @Test func closingAFolderResetsState() async throws {
        let temp = try TempDirectory()
        let workspace = makeWorkspace()
        await workspace.open(folder: temp.url)
        workspace.closeFolder()

        #expect(workspace.rootURL == nil)
        #expect(workspace.treeState == .empty)
    }
}

@MainActor
struct FinderOpenTests {
    private func makeWorkspace() -> Workspace {
        let suite = UserDefaults(suiteName: "iKhalacyTests-\(UUID().uuidString)")!
        return Workspace(defaults: suite)
    }

    @Test func opensAFolderAsTheProjectRoot() async throws {
        let temp = try TempDirectory()
        try temp.write("hi", to: "a.txt")

        let workspace = makeWorkspace()
        await workspace.open(finderURL: temp.url)

        #expect(workspace.rootURL == temp.url)
        #expect(workspace.editor.hasOpenDocuments == false)
    }

    @Test func opensAFileAsItsFolderPlusATab() async throws {
        let temp = try TempDirectory()
        let file = try temp.write("hi", to: "src/a.txt")

        let workspace = makeWorkspace()
        await workspace.open(finderURL: file)

        #expect(workspace.rootURL?.lastPathComponent == "src")
        #expect(workspace.editor.openURLs == [file])
        #expect(workspace.editor.activeDocumentID == file)
    }

    @Test func ignoresPathsThatDoNotExist() async {
        let workspace = makeWorkspace()
        await workspace.open(finderURL: URL(fileURLWithPath: "/nope-\(UUID().uuidString)"))
        #expect(workspace.hasOpenFolder == false)
    }
}
