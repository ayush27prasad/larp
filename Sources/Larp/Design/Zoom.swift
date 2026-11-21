import AppKit
import SwiftUI

/// Zoom levels. The app zoom (⌘+ / ⌘− / ⌘0) scales every font and bar; each
/// file and each terminal also has its own zoom (⌘-scroll or pinch over it),
/// applied on top.
enum Zoom {
    static let appKey = "zoom.app"
    static let step = 0.1

    enum Scope {
        /// The whole interface. 90% keeps the smallest UI text — the 11pt
        /// status bar — at the 10pt Apple treats as the legible minimum on
        /// the Mac; past 150% the bars and tabs crowd a laptop screen.
        case app
        /// A file or a shell: only text in a scrolling view, so it can range
        /// as widely as Safari's page zoom.
        case content

        var range: ClosedRange<Double> {
            switch self {
            case .app: 0.9...1.5
            case .content: 0.5...3.0
            }
        }
    }

    /// `steps` notches from `value`, kept to tenths so repeated zooming lands
    /// back exactly on 100%, and held inside the scope's range.
    static func stepped(_ value: Double, by steps: Int, in scope: Scope) -> Double {
        clamped((value + Double(steps) * step) * 10, in: scope, tenths: true)
    }

    /// For values read back from settings, which may predate the limits.
    static func clamped(_ value: Double, in scope: Scope) -> Double {
        clamped(value, in: scope, tenths: false)
    }

    private static func clamped(_ value: Double, in scope: Scope, tenths: Bool) -> Double {
        let value = tenths ? value.rounded() / 10 : value
        return min(max(value, scope.range.lowerBound), scope.range.upperBound)
    }

    /// Steps `value` in place, beeping at a limit the way macOS does when a
    /// command has nowhere left to go.
    static func step(_ value: inout Double, by steps: Int, in scope: Scope) {
        let next = stepped(value, by: steps, in: scope)
        if next == value, steps != 0 { NSSound.beep() }
        value = next
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
