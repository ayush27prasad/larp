import SwiftUI

/// Window layout that survives relaunches, shared by the window shell and the
/// View menu.
enum Layout {
    static let sidebarVisibleKey = "layout.sidebarVisible"
    static let sidebarWidthKey = "layout.sidebarWidth"
    static let terminalHeightKey = "layout.terminalHeight"

    /// Room for the close, minimise and zoom buttons, which sit over the
    /// content now that the window has no title bar.
    static let windowButtonsWidth: CGFloat = 78
}

private struct TabStripLeadingInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Space the editor's tab strip leaves at its leading edge: zero beside the
    /// sidebar, room for the window buttons and the sidebar toggle without it.
    var tabStripLeadingInset: CGFloat {
        get { self[TabStripLeadingInsetKey.self] }
        set { self[TabStripLeadingInsetKey.self] = newValue }
    }
}

extension View {
    /// Lets the view drag the window, standing in for the title bar it lost.
    func dragsWindow() -> some View {
        gesture(WindowDragGesture())
            .allowsWindowActivationEvents(true)
    }
}

/// The sidebar show/hide button, used in the sidebar header and, while the
/// sidebar is hidden, at the start of the editor's tab strip.
struct SidebarToggle: View {
    @AppStorage(Layout.sidebarVisibleKey) private var isVisible = true
    @Environment(\.uiZoom) private var zoom

    var body: some View {
        Button {
            isVisible.toggle()
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 13 * zoom))
                .foregroundStyle(.secondary)
                .frame(width: 28 * zoom, height: 24 * zoom)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(isVisible ? "Hide Sidebar (⌃⌘S)" : "Show Sidebar (⌃⌘S)")
    }
}
