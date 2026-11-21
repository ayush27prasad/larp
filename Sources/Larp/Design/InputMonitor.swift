import AppKit

/// Shortcuts and gestures larp handles before any view does: zoom (⌘+ / ⌘− /
/// ⌘0, ⌘-scroll, pinch) and find (⌘F, ⌥⌘F, ⌘G, ⇧⌘G).
///
/// A local event monitor rather than menu shortcuts alone: ⌘+ is ⌘⇧= on most
/// keyboards, which a menu item keyed to "=" never sees; scroll and pinch have
/// no menu equivalent; and the editor claims ⌘F in its own monitor. Monitors
/// run newest first, and the editor adds one for every file it shows, so
/// `restart()` re-registers this one to stay ahead of them.
@MainActor
final class InputMonitor {
    enum Command {
        /// Zoom the pane under the pointer.
        case pointerZoom(steps: Int)
        /// Zoom the whole app; nil resets to 100%.
        case appZoom(steps: Int?)
        case find(replace: Bool)
        case findAgain(forward: Bool)
    }

    private var monitor: Any?
    private var handle: (@MainActor (Command) -> Bool)?
    private var scrollAccumulator = 0.0
    private var pinchAccumulator = 0.0

    /// Scroll distance, in points, per zoom step on a trackpad.
    private static let scrollPerStep = 24.0
    private static let pinchPerStep = 0.08

    func start(_ handle: @escaping @MainActor (Command) -> Bool) {
        self.handle = handle
        restart()
    }

    func restart() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify, .keyDown]) { [weak self] event in
            // Local monitors run on the main thread.
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self, let handle = self.handle, let command = self.command(for: event) else { return false }
                return handle(command)
            }
            return consumed ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func command(for event: NSEvent) -> Command? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.type {
        case .keyDown:
            return keyCommand(event.charactersIgnoringModifiers?.lowercased(), modifiers: modifiers)

        case .scrollWheel:
            guard modifiers.contains(.command) else { return nil }
            // A mouse wheel notch is one step; a trackpad's continuous deltas
            // are summed until they amount to one.
            if !event.hasPreciseScrollingDeltas {
                return event.scrollingDeltaY == 0 ? nil : .pointerZoom(steps: event.scrollingDeltaY > 0 ? 1 : -1)
            }
            scrollAccumulator += event.scrollingDeltaY
            return drain(&scrollAccumulator, per: Self.scrollPerStep)

        case .magnify:
            pinchAccumulator += event.magnification
            return drain(&pinchAccumulator, per: Self.pinchPerStep)

        default:
            return nil
        }
    }

    private func keyCommand(_ key: String?, modifiers: NSEvent.ModifierFlags) -> Command? {
        switch (modifiers, key) {
        case (.command, "="), (.command, "+"), ([.command, .shift], "="), ([.command, .shift], "+"):
            return .appZoom(steps: 1)
        case (.command, "-"), ([.command, .shift], "_"):
            return .appZoom(steps: -1)
        case (.command, "0"):
            return .appZoom(steps: nil)
        case (.command, "f"):
            return .find(replace: false)
        case ([.command, .option], "f"):
            return .find(replace: true)
        case (.command, "g"):
            return .findAgain(forward: true)
        case ([.command, .shift], "g"):
            return .findAgain(forward: false)
        default:
            return nil
        }
    }

    private func drain(_ accumulator: inout Double, per unit: Double) -> Command? {
        let steps = Int(accumulator / unit)
        accumulator -= Double(steps) * unit
        return .pointerZoom(steps: steps)
    }
}
