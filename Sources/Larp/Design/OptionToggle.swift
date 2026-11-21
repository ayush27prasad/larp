import SwiftUI

/// The match-case, whole-word and regex toggles, shared by the find bar and
/// Find in Files. They read as words — "Match Case" — since the usual Aa / W
/// / .* glyphs mean nothing until learned, and fall back to those glyphs only
/// when there's no room for the words.
struct SearchOptionToggles: View {
    @Binding var options: ProjectSearch.Options

    var body: some View {
        ViewThatFits(in: .horizontal) {
            toggles(compact: false)
            toggles(compact: true)
        }
    }

    private func toggles(compact: Bool) -> some View {
        HStack(spacing: 4) {
            OptionToggle(label: compact ? "Aa" : "Match Case", help: "Match Case (⌥⌘C)", isOn: $options.matchCase)
            OptionToggle(label: compact ? "W" : "Whole Word", help: "Whole Word (⌥⌘W)", isOn: $options.wholeWord)
            OptionToggle(label: compact ? ".*" : "Regex", help: "Regular Expression (⌥⌘R)", isOn: $options.regex)
        }
        .fixedSize()
    }
}

/// One option chip; highlighted on hover, filled with the accent when on.
struct OptionToggle: View {
    let label: String
    let help: String
    @Binding var isOn: Bool

    @State private var isHovered = false
    @Environment(\.uiZoom) private var zoom

    var body: some View {
        Button { isOn.toggle() } label: {
            Text(label)
                .font(.system(size: 11.5 * zoom, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 8 * zoom)
                .frame(minWidth: 28 * zoom, minHeight: 24 * zoom)
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
