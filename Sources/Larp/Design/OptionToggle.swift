import SwiftUI

/// A search option toggle — Aa, W, .* — shared by the find bar and Find in Files.
struct OptionToggle: View {
    let label: String
    let help: String
    @Binding var isOn: Bool

    @State private var isHovered = false

    var body: some View {
        Button { isOn.toggle() } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(width: 28, height: 24)
                .foregroundStyle(isOn ? Color(nsColor: Chrome.accent) : isHovered ? .primary : .secondary)
                .background(RoundedRectangle(cornerRadius: 6).fill(background))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }

    private var background: Color {
        if isOn { return Color(nsColor: Chrome.accent).opacity(isHovered ? 0.22 : 0.15) }
        return isHovered ? Color.primary.opacity(0.08) : .clear
    }
}

/// An icon-only button that shows it is one on hover, the way Xcode's and VS
/// Code's toolbar icons do; the tooltip names it and its shortcut.
struct IconButton: View {
    let symbol: String
    let help: String
    var size: CGFloat = 24
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.uiZoom) private var zoom

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11 * zoom, weight: .semibold))
                .frame(width: size * zoom, height: size * zoom)
                .foregroundStyle(!isEnabled ? .tertiary : isHovered ? .primary : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered && isEnabled ? Color.primary.opacity(0.08) : .clear))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}
