import SwiftUI

/// The strip of open-file tabs above the editor.
struct EditorTabBar: View {
    let documents: [OpenDocument]
    let activeID: URL?
    let previewID: URL?
    let onSelect: (URL) -> Void
    let onClose: (URL) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(documents) { document in
                    EditorTab(
                        document: document,
                        isActive: document.id == activeID,
                        isPreview: document.id == previewID,
                        onSelect: { onSelect(document.id) },
                        onClose: { onClose(document.id) })
                    Divider().frame(height: 14)
                }
            }
        }
        .scrollIndicators(.never)
        .frame(height: 32)
        .background(.quaternary.opacity(0.4))
    }
}

private struct EditorTab: View {
    let document: OpenDocument
    let isActive: Bool
    let isPreview: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            closeOrDirtyIndicator
            Text(document.name)
                .font(.system(size: 12))
                .italic(isPreview)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(isActive ? AnyShapeStyle(.background) : AnyShapeStyle(.clear))
        .contentShape(.rect)
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
        .help(document.url.path)
    }

    /// One slot: a dot for unsaved changes, swapping to a close button on hover.
    @ViewBuilder
    private var closeOrDirtyIndicator: some View {
        if isHovered || !document.isDirty {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .frame(width: 14, height: 14)
        } else {
            Circle()
                .fill(.secondary)
                .frame(width: 7, height: 7)
                .frame(width: 14, height: 14)
        }
    }
}
