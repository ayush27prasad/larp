import SwiftUI

/// Bottom pane: an embedded terminal running the user's login shell.
/// The PTY and emulator land in a later milestone.
struct TerminalPane: View {
    var body: some View {
        ContentUnavailableView(
            "Terminal pending",
            systemImage: "apple.terminal",
            description: Text("A shell session will run here."))
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.03))
    }
}

#Preview {
    TerminalPane()
        .frame(width: 700, height: 200)
}
