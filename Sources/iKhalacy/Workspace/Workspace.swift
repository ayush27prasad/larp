import Foundation
import Observation

/// The state shared by the three panes: which folder is open, and which file is active.
@Observable
@MainActor
final class Workspace {
    /// Root folder shown in the explorer. `nil` until the user opens one.
    var rootURL: URL?

    /// File currently shown in the editor.
    var activeFileURL: URL?

    var hasOpenFolder: Bool { rootURL != nil }
}
