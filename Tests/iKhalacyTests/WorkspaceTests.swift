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
        #expect(workspace.activeFileURL == nil)
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

    @Test func clearsTheActiveFileWhenOpeningAnotherFolder() async throws {
        let temp = try TempDirectory()
        try temp.write("", to: "a.txt")

        let workspace = makeWorkspace()
        await workspace.open(folder: temp.url)
        workspace.activeFileURL = temp.url.appendingPathComponent("a.txt")

        let other = try TempDirectory()
        await workspace.open(folder: other.url)
        #expect(workspace.activeFileURL == nil)
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

    @Test func restoresTheActiveFileFromTheLastSession() async throws {
        let temp = try TempDirectory()
        let file = try temp.write("hi", to: "a.txt")

        let suite = UserDefaults(suiteName: "iKhalacyTests-\(UUID().uuidString)")!
        let first = Workspace(defaults: suite)
        await first.open(folder: temp.url)
        first.activeFileURL = file

        let second = Workspace(defaults: suite)
        await second.restoreLastFolder()
        #expect(second.activeFileURL?.path == file.path)
    }

    @Test func doesNotRestoreAnActiveFileThatWasDeleted() async throws {
        let temp = try TempDirectory()
        let file = try temp.write("hi", to: "a.txt")

        let suite = UserDefaults(suiteName: "iKhalacyTests-\(UUID().uuidString)")!
        let first = Workspace(defaults: suite)
        await first.open(folder: temp.url)
        first.activeFileURL = file
        try FileManager.default.removeItem(at: file)

        let second = Workspace(defaults: suite)
        await second.restoreLastFolder()
        #expect(second.activeFileURL == nil)
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
