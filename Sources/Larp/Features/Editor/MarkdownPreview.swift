import MarkdownUI
import SwiftUI

/// A markdown file rendered with native views — no web view, so no extra
/// process. Links to other files in the project open in larp; web links go to
/// the browser.
struct MarkdownPreview: View {
    let document: OpenDocument
    let openFile: (URL) -> Void

    var body: some View {
        let folder = document.url.deletingLastPathComponent()
        ScrollView {
            Markdown(document.text, baseURL: folder, imageBaseURL: folder)
                .markdownTheme(.larp)
                .textSelection(.enabled)
                .frame(maxWidth: 860, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: Chrome.contentBackground), ignoresSafeAreaEdges: [])
        .environment(\.openURL, OpenURLAction { url in
            guard url.isFileURL else { return .systemAction }
            openFile(url)
            return .handled
        })
    }
}
