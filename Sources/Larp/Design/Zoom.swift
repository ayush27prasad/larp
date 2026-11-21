import AppKit
import SwiftUI

/// Zoom levels. The app zoom (⌘+ / ⌘− / ⌘0) scales every font and bar; each
/// file and each terminal also has its own zoom (⌘-scroll or pinch over it),
/// applied on top.
enum Zoom {
    static let appKey = "zoom.app"
    static let range = 0.5...3.0
    static let step = 0.1

    /// `steps` notches from `value`, kept to tenths so repeated zooming
    /// lands back exactly on 100%.
    static func stepped(_ value: Double, by steps: Int) -> Double {
        let next = ((value + Double(steps) * step) * 10).rounded() / 10
        return min(max(next, range.lowerBound), range.upperBound)
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct UIZoomKey: EnvironmentKey {
    static let defaultValue = 1.0
}

extension EnvironmentValues {
    /// The app-wide zoom every hard-coded size is multiplied by.
    var uiZoom: Double {
        get { self[UIZoomKey.self] }
        set { self[UIZoomKey.self] = newValue }
    }
}

/// Turns ⌘-scroll, pinch, and ⌘+ / ⌘− / ⌘0 into zoom steps.
///
/// A local event monitor rather than menu shortcuts alone: ⌘+ is ⌘⇧= on most
/// keyboards, which a menu item keyed to "=" never sees, and scroll and pinch
/// have no menu equivalent at all.
@MainActor
final class ZoomInputMonitor {
    enum Command {
        /// Zoom the pane under the pointer.
        case pointer(steps: Int)
        /// Zoom the whole app; nil resets to 100%.
        case app(steps: Int?)
    }

    private var monitor: Any?
    private var scrollAccumulator = 0.0
    private var pinchAccumulator = 0.0

    /// Scroll distance, in points, per zoom step on a trackpad.
    private static let scrollPerStep = 24.0
    private static let pinchPerStep = 0.08

    func start(_ handle: @escaping @MainActor (Command) -> Bool) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify, .keyDown]) { [weak self] event in
            // Local monitors run on the main thread.
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self, let command = self.command(for: event) else { return false }
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
            guard modifiers.subtracting(.shift) == .command else { return nil }
            switch event.charactersIgnoringModifiers {
            case "=", "+": return .app(steps: 1)
            case "-", "_": return .app(steps: -1)
            case "0": return .app(steps: nil)
            default: return nil
            }

        case .scrollWheel:
            guard modifiers.contains(.command) else { return nil }
            // A mouse wheel notch is one step; a trackpad's continuous deltas
            // are summed until they amount to one.
            if !event.hasPreciseScrollingDeltas {
                return event.scrollingDeltaY == 0 ? nil : .pointer(steps: event.scrollingDeltaY > 0 ? 1 : -1)
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

    private func drain(_ accumulator: inout Double, per unit: Double) -> Command? {
        let steps = Int(accumulator / unit)
        guard steps != 0 else { return .pointer(steps: 0) }
        accumulator -= Double(steps) * unit
        return .pointer(steps: steps)
    }
}
