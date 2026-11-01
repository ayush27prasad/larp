import AppKit
import SwiftTerm

/// Wraps one PTY-backed terminal and coalesces resizes.
///
/// SwiftTerm pushes a new window size to the PTY on every layout pass, and each
/// push raises `SIGWINCH`. Collapsing the sidebar animates through dozens of
/// widths, so a prompt that repaints on `SIGWINCH` — Powerlevel10k, Starship,
/// anything with a right-hand segment — is asked to redraw dozens of times and
/// leaves a stack of half-drawn prompts behind. Resizing only once the width has
/// settled turns that storm into a single redraw.
final class TerminalHostView: NSView {
    private let terminal = LocalProcessTerminalView(frame: .zero)
    private var pendingResize: DispatchWorkItem?

    /// Called when the shell exits by itself, with whether it exited cleanly.
    /// Not called for shells stopped through `terminate()`.
    var onExit: ((_ cleanly: Bool) -> Void)?

    /// How long the width must hold steady before the PTY is told about it.
    /// Long enough to outlast a sidebar animation, short enough to feel instant.
    private static let settleDelay: TimeInterval = 0.15

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        clipsToBounds = true
        terminal.nativeBackgroundColor = .textBackgroundColor
        terminal.nativeForegroundColor = .textColor
        terminal.processDelegate = self
        addSubview(terminal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layout() {
        super.layout()

        // First pass: size immediately, or the shell starts against a zero grid.
        guard !terminal.frame.isEmpty else {
            terminal.frame = bounds
            return
        }
        guard terminal.frame.size != bounds.size else { return }

        pendingResize?.cancel()
        let target = bounds
        let work = DispatchWorkItem { [weak self] in self?.terminal.frame = target }
        pendingResize = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay, execute: work)
    }

    func startShell(in directory: URL) {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let name = (shell as NSString).lastPathComponent

        // Opt out of the user's shell config when their prompt misbehaves:
        //   defaults write in.ayush27prasad.larp terminal.plainShell -bool YES
        let plain = UserDefaults.standard.bool(forKey: "terminal.plainShell")

        terminal.startProcess(
            executable: shell,
            args: plain ? ["-f"] : [],
            environment: nil,
            // A leading dash in argv[0] marks a login shell, so the user's
            // profile — and therefore their PATH — is sourced.
            execName: plain ? name : "-" + name,
            currentDirectory: directory.path)
    }

    func focusTerminal() {
        guard window?.firstResponder !== terminal else { return }
        window?.makeFirstResponder(terminal)
    }

    func terminate() {
        pendingResize?.cancel()
        // SwiftTerm reports a shell it was told to kill like any other exit.
        terminal.processDelegate = nil
        terminal.terminate()
    }
}

extension TerminalHostView: LocalProcessTerminalViewDelegate {
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        // nil when a signal ended the shell, so only a real exit(0) is clean.
        let cleanly = exitCode == 0
        if !cleanly {
            terminal.feed(text: "\r\n[Process completed]\r\n")
        }
        onExit?(cleanly)
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
