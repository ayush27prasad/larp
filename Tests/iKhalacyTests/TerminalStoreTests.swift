import Foundation
import Testing

@testable import iKhalacy

@MainActor
struct TerminalStoreTests {
    private let directory = URL(fileURLWithPath: "/tmp", isDirectory: true)

    @Test func startsEmpty() {
        let store = TerminalStore()
        #expect(store.hasSessions == false)
        #expect(store.activeSessionID == nil)
    }

    @Test func newSessionBecomesActive() {
        let store = TerminalStore()
        let first = store.newSession(in: directory)
        let second = store.newSession(in: directory)

        #expect(store.sessions.count == 2)
        #expect(store.activeSessionID == second.id)
        #expect(store.sessions.first?.id == first.id)
    }

    @Test func numbersSessionsInOrder() {
        let store = TerminalStore()
        store.newSession(in: directory)
        store.newSession(in: directory)
        #expect(store.sessions.map(\.title) == ["Terminal 1", "Terminal 2"])
    }

    @Test func closingActiveFocusesTheOneToItsLeft() {
        let store = TerminalStore()
        let first = store.newSession(in: directory)
        let second = store.newSession(in: directory)
        let third = store.newSession(in: directory)

        store.close(third.id)
        #expect(store.activeSessionID == second.id)
        #expect(store.sessions.map(\.id) == [first.id, second.id])
    }

    @Test func closingInactiveKeepsTheActiveOne() {
        let store = TerminalStore()
        let first = store.newSession(in: directory)
        let second = store.newSession(in: directory)

        store.close(first.id)
        #expect(store.activeSessionID == second.id)
    }

    @Test func closingTheLastLeavesNothingActive() {
        let store = TerminalStore()
        let only = store.newSession(in: directory)
        store.close(only.id)

        #expect(store.hasSessions == false)
        #expect(store.activeSessionID == nil)
    }

    @Test func closeAllResetsNumbering() {
        let store = TerminalStore()
        store.newSession(in: directory)
        store.newSession(in: directory)
        store.closeAll()
        store.newSession(in: directory)

        #expect(store.sessions.map(\.title) == ["Terminal 1"])
    }

    @Test func renamesASession() {
        let store = TerminalStore()
        let session = store.newSession(in: directory)
        store.rename(session.id, to: "build")
        #expect(store.sessions.first?.title == "build")
    }

    @Test func ignoresBlankRenames() {
        let store = TerminalStore()
        let session = store.newSession(in: directory)
        store.rename(session.id, to: "   ")
        #expect(store.sessions.first?.title == "Terminal 1")
    }

    @Test func trimsWhitespaceFromRenames() {
        let store = TerminalStore()
        let session = store.newSession(in: directory)
        store.rename(session.id, to: "  tests \n")
        #expect(store.sessions.first?.title == "tests")
    }

    @Test func renamingAnUnknownSessionDoesNothing() {
        let store = TerminalStore()
        store.newSession(in: directory)
        store.rename(UUID(), to: "nope")
        #expect(store.sessions.first?.title == "Terminal 1")
    }

    @Test func renameSurvivesClosingAnotherTab() {
        let store = TerminalStore()
        let first = store.newSession(in: directory)
        let second = store.newSession(in: directory)
        store.rename(first.id, to: "server")
        store.close(second.id)
        #expect(store.sessions.map(\.title) == ["server"])
    }

    @Test func reportsNoFocusWithoutAContainer() {
        let store = TerminalStore()
        #expect(store.hasFocus == false)
    }
}

@MainActor
struct WorkspaceTerminalTests {
    private func makeWorkspace() -> Workspace {
        let suite = UserDefaults(suiteName: "iKhalacyTests-\(UUID().uuidString)")!
        return Workspace(defaults: suite)
    }

    @Test func openingAFolderStartsOneShellRootedThere() async throws {
        let temp = try TempDirectory()
        let workspace = makeWorkspace()
        await workspace.open(folder: temp.url)

        #expect(workspace.terminals.sessions.count == 1)
        #expect(workspace.terminals.sessions.first?.workingDirectory == temp.url)
    }

    @Test func openingAnotherFolderReplacesTheShells() async throws {
        let first = try TempDirectory()
        let workspace = makeWorkspace()
        await workspace.open(folder: first.url)
        workspace.newTerminal()
        #expect(workspace.terminals.sessions.count == 2)

        let second = try TempDirectory()
        await workspace.open(folder: second.url)
        #expect(workspace.terminals.sessions.count == 1)
        #expect(workspace.terminals.sessions.first?.workingDirectory == second.url)
    }

    @Test func ensureTerminalIsIdempotent() {
        let workspace = makeWorkspace()
        workspace.ensureTerminal()
        workspace.ensureTerminal()
        #expect(workspace.terminals.sessions.count == 1)
    }

    @Test func selectingAnOpenFileSwitchesToItsTab() async throws {
        let temp = try TempDirectory()
        let a = try temp.write("1", to: "a.txt")
        let b = try temp.write("2", to: "b.txt")

        let workspace = makeWorkspace()
        await workspace.open(folder: temp.url)
        await workspace.openFile(a)
        await workspace.openFile(b)
        #expect(workspace.editor.activeDocumentID == b)

        await workspace.previewSelection(a)
        #expect(workspace.editor.activeDocumentID == a)
    }

    @Test func selectingAnUnopenedFileOpensItAsAPreview() async throws {
        let temp = try TempDirectory()
        let a = try temp.write("1", to: "a.txt")
        let b = try temp.write("2", to: "b.txt")

        let workspace = makeWorkspace()
        await workspace.open(folder: temp.url)
        await workspace.openFile(a)

        await workspace.previewSelection(b)
        #expect(workspace.editor.activeDocumentID == b)
        #expect(workspace.editor.isPreview(b))
        // The pinned tab stays put.
        #expect(workspace.editor.openURLs == [a, b])
    }

    @Test func closingFocusedTabFallsBackToTheEditor() async throws {
        let temp = try TempDirectory()
        let a = try temp.write("1", to: "a.txt")

        let workspace = makeWorkspace()
        await workspace.open(folder: temp.url)
        await workspace.openFile(a)

        // No container view, so the terminal reports no focus.
        workspace.closeFocusedTab()
        #expect(workspace.editor.hasOpenDocuments == false)
    }
}
