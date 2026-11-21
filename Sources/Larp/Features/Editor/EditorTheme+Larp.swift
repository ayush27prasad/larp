import AppKit
import CodeEditSourceEditor

extension NSColor {
    /// `rrggbb`, no alpha — the form the palettes below are written in.
    fileprivate convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}

extension EditorTheme.Attribute {
    fileprivate init(hex: UInt32, italic: Bool = false) {
        self.init(color: NSColor(hex: hex), italic: italic)
    }
}

extension EditorTheme {
    /// Xcode's default light palette — the most familiar one on the Mac.
    static var larpLight: EditorTheme {
        EditorTheme(
            text: .init(hex: 0x0000_00),
            insertionPoint: NSColor(hex: 0x0000_00),
            invisibles: .init(hex: 0xD6D6_D6),
            background: NSColor(hex: 0xFFFF_FF),
            lineHighlight: NSColor(hex: 0xECF5_FF),
            selection: NSColor(hex: 0xB2D7_FF),
            keywords: .init(hex: 0x9B23_93),
            commands: .init(hex: 0x6438_20),
            types: .init(hex: 0x0B4F_79),
            attributes: .init(hex: 0x815F_03),
            variables: .init(hex: 0x326D_74),
            values: .init(hex: 0x1C00_CF),
            numbers: .init(hex: 0x1C00_CF),
            strings: .init(hex: 0xC41A_16),
            characters: .init(hex: 0x1C00_CF),
            comments: .init(hex: 0x2675_07, italic: true))
    }

    /// Neon on black: keywords pink, strings green, functions cyan, types
    /// violet, numbers amber, comments a dim slate that stays out of the way.
    static var larpDark: EditorTheme {
        EditorTheme(
            text: .init(hex: 0xE4E4EA),
            insertionPoint: NSColor(hex: 0x00FF9C),
            invisibles: .init(hex: 0x2A2A33),
            background: NSColor(hex: 0x050507),
            lineHighlight: NSColor(hex: 0x0E0E14),
            selection: NSColor(hex: 0x203A33),
            keywords: .init(hex: 0xFF3CAC),
            commands: .init(hex: 0x3DE8FF),
            types: .init(hex: 0xB388FF),
            attributes: .init(hex: 0xFF9E64),
            variables: .init(hex: 0x9CFFD9),
            values: .init(hex: 0xFFD166),
            numbers: .init(hex: 0xFFB020),
            strings: .init(hex: 0x39FF88),
            characters: .init(hex: 0xFFB020),
            comments: .init(hex: 0x5C6573, italic: true))
    }
}
