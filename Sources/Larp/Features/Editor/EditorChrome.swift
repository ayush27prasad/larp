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

    /// The path below the project folder; outside it, the full path, so
    /// library source shows which package it came from.
    private var segments: [String] {
        guard let root, document.url.path.hasPrefix(root.path + "/") else {
            return (document.url.path as NSString).abbreviatingWithTildeInPath
                .split(separator: "/").map(String.init)
        }
        return document.url.path.dropFirst(root.path.count + 1).split(separator: "/").map(String.init)
    }
}

/// Below the editor: cursor position, language, encoding, line endings.
struct StatusBar: View {
    let document: OpenDocument
    var indexProgress: (done: Int, total: Int)?

    @Environment(\.uiZoom) private var zoom

    var body: some View {
        HStack(spacing: 16) {
            if let indexProgress {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Indexing \(indexProgress.done)/\(indexProgress.total)")
                        .monospacedDigit()
                }
                .help("Building the index for ⌘-click")
            }
            Spacer()
            if document.isReadOnly {
                Label("Read-only", systemImage: "lock.fill")
                    .help("Outside the project. Only project files can be edited.")
            }
            if document.zoom != 1 {
                Text(Zoom.percent(document.zoom))
                    .monospacedDigit()
                    .help("File zoom. ⌘-scroll to change.")
            }
            if let cursor = document.cursor, !(document.isMarkdown && document.showsPreview) {
                Text("Ln \(cursor.line), Col \(cursor.column)")
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
