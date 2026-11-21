import CodeEditSourceEditor
import SwiftUI

/// Above the editor: where the file lives, and — for markdown — whether it is
/// shown rendered or as source.
struct PathBar: View {
    @Bindable var document: OpenDocument
    let root: URL?

    @Environment(\.uiZoom) private var zoom

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8 * zoom, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                Text(segment)
                    .foregroundStyle(index == segments.count - 1 ? .primary : .secondary)
            }
            Spacer(minLength: 8)
            if document.isMarkdown {
                Picker("View", selection: $document.showsPreview) {
                    Text("Preview").tag(true)
                    Text("Source").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
                .help("Toggle Markdown Preview (⇧⌘V)")
            }
        }
        .font(.system(size: 11 * zoom))
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(height: 28 * zoom)
        .background(Color(nsColor: Chrome.contentBackground), ignoresSafeAreaEdges: [])
    }

    /// The path below the project folder, or just the name outside one.
    private var segments: [String] {
        guard let root, document.url.path.hasPrefix(root.path + "/") else { return [document.name] }
        return document.url.path.dropFirst(root.path.count + 1).split(separator: "/").map(String.init)
    }
}

/// Below the editor: cursor position, language, encoding, line endings.
struct StatusBar: View {
    let document: OpenDocument
    let cursor: CursorPosition?

    @Environment(\.uiZoom) private var zoom

    var body: some View {
        HStack(spacing: 16) {
            Spacer()
            if document.zoom != 1 {
                Text(Zoom.percent(document.zoom))
                    .monospacedDigit()
                    .help("File zoom. ⌘-scroll to change.")
            }
            if let cursor, !(document.isMarkdown && document.showsPreview) {
                Text("Ln \(cursor.start.line), Col \(cursor.start.column)")
                    .monospacedDigit()
            }
            Text(LanguageDetection.displayName(of: document.language))
            Text(document.encoding.name)
            Text(document.usesCRLF ? "CRLF" : "LF")
        }
        .font(.system(size: 11 * zoom))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: Chrome.statusBarHeight * zoom)
        .background(Color(nsColor: Chrome.barBackground), ignoresSafeAreaEdges: [])
        .overlay(alignment: .top) { Rectangle().fill(Color(nsColor: Chrome.separator)).frame(height: 1) }
    }
}
