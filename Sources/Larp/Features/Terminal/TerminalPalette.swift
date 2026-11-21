import AppKit

/// Terminal colours for each appearance. The background is the editor's, so
/// the two panes read as one surface.
///
/// The 16 ANSI colours are deliberately left at SwiftTerm's standard set:
/// prompts like Powerlevel10k draw their own segment backgrounds and are
/// designed against those colours, and a themed palette made them unreadable.
struct TerminalPalette {
    let background: NSColor
    let foreground: NSColor
    let caret: NSColor
    let selection: NSColor

    static func forAppearance(_ appearance: NSAppearance) -> TerminalPalette {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
    }

    static let light = TerminalPalette(
        background: Chrome.rgb(0xFFFFFF),
        foreground: Chrome.rgb(0x1D1D1F),
        caret: Chrome.rgb(0x0071E3),
        selection: Chrome.rgb(0xB3D7FF))

    static let dark = TerminalPalette(
        background: Chrome.rgb(0x050507),
        foreground: Chrome.rgb(0xD8FFEE),
        caret: Chrome.rgb(0x00FF9C),
        selection: Chrome.rgb(0x203A33))
}
