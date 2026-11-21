import SwiftUI

/// The pill that appears while zooming — "App  −  110%  +  Reset" — like a
/// browser's zoom bubble. It doesn't scale with the app zoom itself, so it
/// stays usable at either end of the range.
struct ZoomHUD: View {
    let title: String
    let level: Double
    let range: ClosedRange<Double>
    let onStep: (Int) -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
                .padding(.trailing, 2)
            button("minus", help: "Zoom Out", disabled: level <= range.lowerBound) { onStep(-1) }
            Text(Zoom.percent(level))
                .monospacedDigit()
                .frame(minWidth: 42)
            button("plus", help: "Zoom In", disabled: level >= range.upperBound) { onStep(1) }
            Rectangle().fill(Color(nsColor: Chrome.separator)).frame(width: 1, height: 14)
            Button("Reset", action: onReset)
                .buttonStyle(.plain)
                .foregroundStyle(level == 1 ? .tertiary : .primary)
                .disabled(level == 1)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color(nsColor: Chrome.separator)))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
    }

    private func button(_ symbol: String, help: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 20, height: 20)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? .tertiary : .primary)
        .disabled(disabled)
        .help(help)
    }
}
