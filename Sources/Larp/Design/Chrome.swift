import AppKit
import SwiftUI

/// Colours and metrics shared by every pane, so the editor, the markdown
/// preview and the terminal sit on one surface in both appearances.
///
/// Light is Apple-calm: white content on apple.com's #F5F5F7 greys, Apple blue
/// as the accent. Dark is a neon-on-black hacker theme in the spirit of
/// Synthwave '84 and Cyberpunk, on a true-black base like Warp's: neon pink
/// accent, green caret, a glow on the active tab. The accent colour itself
/// lives in the asset catalogue so system controls pick it up too.
enum Chrome {
    /// The surface code sits on. Matches the editor themes' backgrounds.
    static var contentBackground: NSColor { dynamic(light: 0xFFFFFF, dark: 0x050507) }

    /// Tab strips, the status bar and the window's toolbar.
    static var barBackground: NSColor { dynamic(light: 0xF5F5F7, dark: 0x0B0B0F) }

    /// The explorer.
    static var sidebarBackground: NSColor { dynamic(light: 0xF5F5F7, dark: 0x08080B) }

    /// larp's own accent. Set explicitly because macOS replaces an app's
    /// accent colour with the user's system accent unless that is Multicolor.
    static var accent: NSColor { dynamic(light: 0x0071E3, dark: 0xFF2E88) }

    // Markdown preview: the page's own colours, not GitHub's greys.
    static var stripe: NSColor { dynamic(light: 0xF5F5F7, dark: 0x0C0C13) }
    static var codeBackground: NSColor { dynamic(light: 0xF0F0F3, dark: 0x0F0F18) }
    static var inlineCode: NSColor { dynamic(light: 0xC41A16, dark: 0x39FF88) }
    static var link: NSColor { dynamic(light: 0x0071E3, dark: 0x3DE8FF) }

    /// Hairlines between regions.
    static var separator: NSColor { dynamic(light: 0xD2D2D7, dark: 0x1D1D26) }

    /// Also the sidebar header's height, so the two line up across the top.
    static let tabBarHeight: CGFloat = 36
    static let statusBarHeight: CGFloat = 24

    static func dynamic(light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            rgb(appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        }
    }

    static func rgb(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}

/// One tab in a pane's tab strip. The active tab joins the content below it —
/// same background, an accent line on top — and the rest recede.
struct PaneTab<Content: View>: View {
    let isActive: Bool
    @ViewBuilder let content: (_ isHovered: Bool) -> Content

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uiZoom) private var zoom

    var body: some View {
        content(isHovered)
            .font(.system(size: 12 * zoom))
            .foregroundStyle(isActive ? .primary : .secondary)
            .padding(.horizontal, 12 * zoom)
            .frame(height: Chrome.tabBarHeight * zoom)
            .background(background, ignoresSafeAreaEdges: [])
            .overlay(alignment: .top) {
                if isActive {
                    let accent = Color(nsColor: Chrome.accent)
                    Rectangle()
                        .fill(accent)
                        .frame(height: 2)
                        // The neon glow is the dark theme's signature; light stays flat.
                        .shadow(color: colorScheme == .dark ? accent : .clear, radius: 5)
                }
            }
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color(nsColor: Chrome.separator)).frame(width: 1)
            }
            .contentShape(.rect)
            .onHover { isHovered = $0 }
    }

    private var background: Color {
        if isActive { return Color(nsColor: Chrome.contentBackground) }
        return isHovered ? Color.primary.opacity(0.05) : .clear
    }
}

/// The close button that shares its slot with the unsaved-changes dot.
struct TabCloseButton: View {
    let isVisible: Bool
    var showsDirtyDot = false
    let action: () -> Void

    @Environment(\.uiZoom) private var zoom

    var body: some View {
        ZStack {
            if isVisible {
                Button(action: action) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8 * zoom, weight: .bold))
                        .frame(width: 16 * zoom, height: 16 * zoom)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Close")
            } else if showsDirtyDot {
                Circle().fill(.secondary).frame(width: 7 * zoom, height: 7 * zoom)
            }
        }
        .frame(width: 16 * zoom, height: 16 * zoom)
    }
}
