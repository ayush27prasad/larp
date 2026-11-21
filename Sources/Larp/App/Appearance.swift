import AppKit

/// The light/dark choice in View ▸ Appearance. System follows macOS.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let defaultsKey = "appearance.mode"

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Set on NSApp rather than through SwiftUI's preferredColorScheme, which
    /// doesn't reach the AppKit-hosted editor and terminal.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}
