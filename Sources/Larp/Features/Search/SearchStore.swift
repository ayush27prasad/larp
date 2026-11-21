import Foundation
import Observation

/// Find in Files: the query, its options, the results, and which match is
/// selected. Each edit to the query or options restarts the search after a
/// short pause, cancelling the one in flight.
@Observable
@MainActor
final class SearchStore {
    var isPresented = false

    var query = "" {
        didSet { if query != oldValue { scheduleSearch() } }
    }

    var options = ProjectSearch.Options() {
        didSet { if options != oldValue { scheduleSearch() } }
    }

    private(set) var result = ProjectSearch.Result()
    private(set) var isSearching = false
    var selectedMatchID: String?

    /// The files to search, supplied by the workspace from its file tree.
    @ObservationIgnored var files: () -> [URL] = { [] }

    @ObservationIgnored private var task: Task<Void, Never>?

    /// Long enough to skip the intermediate states of a word being typed.
    private static let typingPause = Duration.milliseconds(120)

    var matches: [ProjectSearch.Match] { result.files.flatMap(\.matches) }

    var selectedMatch: ProjectSearch.Match? {
        matches.first { $0.id == selectedMatchID }
    }

    func present() {
        isPresented = true
        // The project may have changed since the last search.
        scheduleSearch()
    }

    /// Reruns the search if the panel is open, for when the files changed.
    func refresh() {
        if isPresented { scheduleSearch() }
    }

    func dismiss() {
        isPresented = false
        task?.cancel()
    }

    func moveSelection(by offset: Int) {
        let matches = self.matches
        guard !matches.isEmpty else { return }
        let current = matches.firstIndex { $0.id == selectedMatchID } ?? -offset
        let next = min(max(current + offset, 0), matches.count - 1)
        selectedMatchID = matches[next].id
    }

    /// Runs the search now rather than after the typing pause; for tests.
    func searchNow() async {
        task?.cancel()
        await run(query: query, options: options, files: files())
    }

    private func scheduleSearch() {
        task?.cancel()
        guard isPresented, !query.isEmpty else {
            result = ProjectSearch.Result()
            isSearching = false
            return
        }
        let (query, options, files) = (query, options, files())
        isSearching = true
        task = Task {
            try? await Task.sleep(for: Self.typingPause)
            guard !Task.isCancelled else { return }
            await run(query: query, options: options, files: files)
        }
    }

    private func run(query: String, options: ProjectSearch.Options, files: [URL]) async {
        let result = await ProjectSearch.search(query, options: options, in: files)
        guard !Task.isCancelled else { return }
        self.result = result
        isSearching = false
        if selectedMatch == nil { selectedMatchID = result.files.first?.matches.first?.id }
    }

    /// A few lines either side of the selected match, for the preview.
    func context(around match: ProjectSearch.Match, radius: Int = 4) -> [(number: Int, text: String)] {
        guard let data = try? Data(contentsOf: match.url, options: .mappedIfSafe),
              let text = try? TextFileLoader.decode(data).text
        else { return [] }
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let range = max(0, match.line - 1 - radius)...min(lines.count - 1, match.line - 1 + radius)
        return range.map { (number: $0 + 1, text: String(lines[$0])) }
    }
}
