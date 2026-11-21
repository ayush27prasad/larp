import SwiftUI

/// ⌘F's bar under the path bar, in larp's own style rather than the editor's
/// stock panel: query, "3 of 12", Aa / W / .*, previous and next, close; and a
/// replace row from the chevron or ⌥⌘F. ↩ next, ⇧↩ previous, esc closes.
struct FindBar: View {
    @Bindable var find: FindModel

    @Environment(\.uiZoom) private var zoom
    @FocusState private var focused: Field?

    private enum Field { case query, replacement }

    var body: some View {
        VStack(spacing: 6 * zoom) {
            HStack(spacing: 8 * zoom) {
                IconButton(
                    symbol: find.showsReplace ? "chevron.down" : "chevron.right",
                    help: find.showsReplace ? "Hide Replace" : "Show Replace (⌥⌘F)",
                    size: 20
                ) { find.showsReplace.toggle() }

                field(icon: "magnifyingglass", placeholder: "Find", text: $find.query, focus: .query) {
                    Text(find.status)
                        .foregroundStyle(find.status == "No results" || find.isInvalidPattern ? Color.red.opacity(0.85) : .secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                }
                OptionToggle(label: "Aa", help: "Match Case (⌥⌘C)", isOn: $find.options.matchCase)
                OptionToggle(label: "W", help: "Whole Words (⌥⌘W)", isOn: $find.options.wholeWord)
                OptionToggle(label: ".*", help: "Regex (⌥⌘R)", isOn: $find.options.regex)
                IconButton(symbol: "chevron.up", help: "Previous Match (⇧↩ or ⇧⌘G)", action: find.previous)
                    .disabled(find.matches.isEmpty)
                IconButton(symbol: "chevron.down", help: "Next Match (↩ or ⌘G)", action: find.next)
                    .disabled(find.matches.isEmpty)
                IconButton(symbol: "xmark", help: "Close (esc)", action: find.hide)
            }

            if find.showsReplace {
                HStack(spacing: 8 * zoom) {
                    Color.clear.frame(width: 16 * zoom, height: 1)
                    field(icon: "arrow.2.squarepath", placeholder: "Replace", text: $find.replacement, focus: .replacement) {
                        EmptyView()
                    }
                    Button("Replace", action: find.replaceCurrent)
                        .disabled(find.currentIndex == nil)
                        .help("Replace This Match (↩ in the replace field)")
                    Button("All", action: find.replaceAll)
                        .disabled(find.matches.isEmpty)
                        .help("Replace All Matches")
                }
                .buttonStyle(PillButtonStyle())
            }
        }
        .font(.system(size: 12 * zoom))
        .padding(.horizontal, 12)
        .padding(.vertical, 6 * zoom)
        .background(Color(nsColor: Chrome.barBackground), ignoresSafeAreaEdges: [])
        .overlay(alignment: .bottom) { Rectangle().fill(Color(nsColor: Chrome.separator)).frame(height: 1) }
        .onAppear { focused = .query }
        .onChange(of: find.focusRequest) { focused = .query }
        .onExitCommand(perform: find.hide)
    }

    private func field<Accessory: View>(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        focus: Field,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 6 * zoom) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.system(size: 11 * zoom))
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .focused($focused, equals: focus)
                .onKeyPress(keys: [.return]) { press in
                    guard focus == .query else { find.replaceCurrent(); return .handled }
                    press.modifiers.contains(.shift) ? find.previous() : find.next()
                    return .handled
                }
            accessory()
        }
        .padding(.horizontal, 8)
        .frame(height: 26 * zoom)
        .background(Color(nsColor: Chrome.contentBackground), in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(focused == focus ? Color(nsColor: Chrome.accent) : Color(nsColor: Chrome.separator)))
    }
}

/// A small bordered button for the replace row.
private struct PillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .frame(height: 24)
            .foregroundStyle(isEnabled ? .primary : .tertiary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: Chrome.separator)))
    }
}
