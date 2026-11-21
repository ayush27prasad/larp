import SwiftUI

/// Find in Files (⇧⌘F), after IntelliJ's: a floating panel with the query and
/// its options on top, results grouped by file in the middle, and the lines
/// around the selected match below. ↑↓ move, ↩ opens, esc closes.
struct FindInFilesPanel: View {
    @Bindable var search: SearchStore
    let root: URL?
    let onOpen: (ProjectSearch.Match) -> Void

    @FocusState private var fieldIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color(nsColor: Chrome.separator))
            results
            if let match = search.selectedMatch {
                Divider().overlay(Color(nsColor: Chrome.separator))
                ContextPreview(lines: search.context(around: match), match: match)
                    .frame(height: 150)
            }
            footer
        }
        .background(Color(nsColor: Chrome.contentBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: Chrome.separator)))
        .shadow(color: .black.opacity(0.35), radius: 30, y: 10)
        .onAppear { fieldIsFocused = true }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Find in files", text: $search.query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($fieldIsFocused)
                .onSubmit { search.selectedMatch.map(onOpen) }
                .onKeyPress(.downArrow) { search.moveSelection(by: 1); return .handled }
                .onKeyPress(.upArrow) { search.moveSelection(by: -1); return .handled }
                .onExitCommand { search.dismiss() }
            OptionToggle(label: "Aa", help: "Match Case (⌥⌘C)", isOn: $search.options.matchCase)
            OptionToggle(label: "W", help: "Whole Words (⌥⌘W)", isOn: $search.options.wholeWord)
            OptionToggle(label: ".*", help: "Regex (⌥⌘R)", isOn: $search.options.regex)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }

    @ViewBuilder
    private var results: some View {
        if search.result.files.isEmpty {
            Text(emptyMessage)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(search.result.files) { file in
                            FileHeader(url: file.url, root: root, count: file.matches.count)
                            ForEach(file.matches) { match in
                                MatchRow(match: match, isSelected: match.id == search.selectedMatchID)
                                    .id(match.id)
                                    .onTapGesture(count: 2) { onOpen(match) }
                                    .onTapGesture { search.selectedMatchID = match.id }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: search.selectedMatchID) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
            }
        }
    }

    private var emptyMessage: String {
        if search.query.isEmpty { return "Type to search the project." }
        if search.result.isInvalidPattern { return "Only valid regular expressions are supported." }
        return search.isSearching ? "Searching…" : "No matches."
    }

    private var footer: some View {
        HStack {
            Text(summary)
            Spacer()
            Text("↑↓ navigate   ↩ open   esc close")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(Color(nsColor: Chrome.barBackground))
    }

    private var summary: String {
        let result = search.result
        guard result.matchCount > 0 else { return search.isSearching ? "Searching…" : "" }
        let matches = result.matchCount == 1 ? "1 match" : "\(result.matchCount) matches"
        let files = result.files.count == 1 ? "1 file" : "\(result.files.count) files"
        return result.isTruncated ? "First \(matches) in \(files)" : "\(matches) in \(files)"
    }
}

private struct FileHeader: View {
    let url: URL
    let root: URL?
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            FileIcon.image(for: url)
            Text(url.lastPathComponent).fontWeight(.semibold)
            Text(folder).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
            Spacer()
            Text("\(count)").foregroundStyle(.secondary).monospacedDigit()
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    /// The folder below the project root.
    private var folder: String {
        let path = url.deletingLastPathComponent().path
        guard let root, path.hasPrefix(root.path) else { return path }
        return String(path.dropFirst(root.path.count + 1))
    }
}

private struct MatchRow: View {
    let match: ProjectSearch.Match
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(match.line)")
                .foregroundStyle(.tertiary)
                .frame(width: 40, alignment: .trailing)
            Text(highlighted)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 14)
        .frame(height: 24)
        .background(isSelected ? Color(nsColor: Chrome.accent).opacity(0.18) : .clear)
        .contentShape(.rect)
    }

    private var highlighted: AttributedString {
        var text = AttributedString(match.preview)
        for range in match.highlights {
            guard let bounds = Range(range, in: match.preview),
                  let lower = AttributedString.Index(bounds.lowerBound, within: text),
                  let upper = AttributedString.Index(bounds.upperBound, within: text)
            else { continue }
            text[lower..<upper].backgroundColor = Color(nsColor: Chrome.accent).opacity(0.35)
            text[lower..<upper].foregroundColor = .primary
        }
        return text
    }
}

/// The lines around the selected match, the match's own line marked.
private struct ContextPreview: View {
    let lines: [(number: Int, text: String)]
    let match: ProjectSearch.Match

    var body: some View {
        // Vertical only: a two-way scroll view centres content narrower than
        // itself, which pushed short lines into the middle.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(lines, id: \.number) { line in
                    HStack(spacing: 10) {
                        Text("\(line.number)")
                            .foregroundStyle(.tertiary)
                            .frame(width: 40, alignment: .trailing)
                        Text(line.text)
                            .foregroundStyle(line.number == match.line ? .primary : .secondary)
                            .lineLimit(1)
                    }
                    .frame(height: 17)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(line.number == match.line ? Color(nsColor: Chrome.accent).opacity(0.12) : .clear)
                }
            }
            .font(.system(size: 12, design: .monospaced))
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
        }
        .background(Color(nsColor: Chrome.barBackground))
    }
}
