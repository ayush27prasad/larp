import Foundation
import Testing

@testable import iKhalacy

@MainActor
struct WorkspaceTests {
    @Test func startsWithNoOpenFolder() {
        let workspace = Workspace()
        #expect(workspace.rootURL == nil)
        #expect(workspace.activeFileURL == nil)
        #expect(workspace.hasOpenFolder == false)
    }

    @Test func reportsAnOpenFolderOnceRootIsSet() {
        let workspace = Workspace()
        workspace.rootURL = URL(fileURLWithPath: "/tmp", isDirectory: true)
        #expect(workspace.hasOpenFolder)
    }
}
