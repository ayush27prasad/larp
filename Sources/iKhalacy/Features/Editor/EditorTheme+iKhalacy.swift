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
    /// Xcode's default light palette.
    static var iKhalacyLight: EditorTheme {
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

    /// Unused while the app is pinned to light, kept for a future preference.
    static var iKhalacyDark: EditorTheme {
        EditorTheme(
            text: .init(hex: 0xDFDF_E0),
            insertionPoint: NSColor(hex: 0xDFDF_E0),
            invisibles: .init(hex: 0x5360_6E),
            background: NSColor(hex: 0x1F1F_24),
            lineHighlight: NSColor(hex: 0x2F2F_35),
            selection: NSColor(hex: 0x4551_63),
            keywords: .init(hex: 0xFC5F_A3),
            commands: .init(hex: 0xA167_E6),
            types: .init(hex: 0x5DD8_FF),
            attributes: .init(hex: 0xA167_E6),
            variables: .init(hex: 0x41A1_C0),
            values: .init(hex: 0xD0BF_69),
            numbers: .init(hex: 0xD0BF_69),
            strings: .init(hex: 0xFC6A_5D),
            characters: .init(hex: 0xD0BF_69),
            comments: .init(hex: 0x6C79_86, italic: true))
    }
}
