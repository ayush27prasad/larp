import SwiftUI

/// A search option toggle — Aa, W, .* — shared by the find bar and Find in Files.
struct OptionToggle: View {
    let label: String
    let help: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(width: 28, height: 24)
                .foregroundStyle(isOn ? Color(nsColor: Chrome.accent) : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isOn ? Color(nsColor: Chrome.accent).opacity(0.15) : .clear))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
