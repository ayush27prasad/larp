import SwiftUI

/// The strip of open-file tabs above the editor.
struct EditorTabBar: View {
    let documents: [OpenDocument]
    let activeID: URL?
    let previewID: URL?
    let onSelect: (URL) -> Void
    let onClose: (URL) -> Void

    @Environment(\.tabStripLeadingInset) private var leadingInset

    /// Always shown, even with no files open: it is the top of the window,
    /// and its empty part is where the window is dragged from.
    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: leadingInset)
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(documents) { document in
                        EditorTab(
                            document: document,
                            isActive: document.id == activeID,
                            isPreview: document.id == previewID,
                            onClose: { onClose(document.id) })
                            .onTapGesture { onSelect(document.id) }
                    }
                }
            }
            .scrollIndicators(.never)
            .fixedSize(horizontal: true, vertical: false)
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .dragsWindow()
        }
        .frame(height: Chrome.tabBarHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: Chrome.barBackground), ignoresSafeAreaEdges: [])
        .overlay(alignment: .bottom) { Rectangle().fill(Color(nsColor: Chrome.separator)).frame(height: 1) }
    }
}

private struct EditorTab: View {
    let document: OpenDocument
    let isActive: Bool
    let isPreview: Bool
    let onClose: () -> Void

    var body: some View {
        PaneTab(isActive: isActive) { isHovered in
            HStack(spacing: 6) {
                FileIcon.image(for: document.url)
                    .font(.system(size: 11))
                Text(document.name)
                    .italic(isPreview)
                    .lineLimit(1)
                TabCloseButton(
                    isVisible: isHovered || (isActive && !document.isDirty),
                    showsDirtyDot: document.isDirty,
                    action: onClose)
            }
        }
        .help(document.url.path)
    }
}
