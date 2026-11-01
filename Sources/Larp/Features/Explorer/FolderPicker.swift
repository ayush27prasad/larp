import AppKit

/// Wraps the one `NSOpenPanel` configuration the app needs.
@MainActor
enum FolderPicker {
    static func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a project folder to open."
        panel.prompt = "Open"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
