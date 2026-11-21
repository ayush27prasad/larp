import Foundation
import Testing

@testable import Larp

@MainActor
struct FindModelTests {
    private func model(searching text: String) -> (FindModel, OpenDocument) {
        // The model holds its document weakly — the store owns it in the app —
        // so each test keeps the returned document alive.
        let document = OpenDocument(url: URL(fileURLWithPath: "/p/a.py"), text: text)
        let find = FindModel()
        find.document = document
        find.show(replace: false, prefill: nil)
        return (find, document)
    }

    @Test func countsMatchesAndStartsAtTheFirst() {
        let (find, document) = model(searching: "total = 1\nsubtotal = total\n")
        find.query = "total"
        #expect(find.matches.count == 3)
        #expect(find.status == "1 of 3")
        withExtendedLifetime(document) {}
    }

    @Test func nextAndPreviousWrapAround() {
        let (find, document) = model(searching: "a a a")
        find.query = "a"
        find.previous()
        #expect(find.status == "3 of 3")
        find.next()
        #expect(find.status == "1 of 3")
        withExtendedLifetime(document) {}
    }

    @Test func followsEditsToTheText() {
        let (find, document) = model(searching: "x")
        find.query = "y"
        #expect(find.status == "No results")
        document.text = "y y"
        find.refresh(revealing: false)
        #expect(find.matches.count == 2)
    }

    @Test func reportsAnInvalidPattern() {
        let (find, document) = model(searching: "x")
        find.options.regex = true
        find.query = "(x"
        #expect(find.isInvalidPattern)
        #expect(find.status == "Invalid pattern")
        withExtendedLifetime(document) {}
    }

    @Test func seedsTheQueryFromASingleLineSelection() {
        let find = FindModel()
        find.show(replace: false, prefill: "calculate_total")
        #expect(find.query == "calculate_total")
        find.show(replace: false, prefill: "two\nlines")
        #expect(find.query == "calculate_total")
    }

    @Test func regexReplacementFillsGroups() {
        let (find, document) = model(searching: "TAX_RATE = 0.08")
        find.options.regex = true
        find.query = "(\\w+) = (.+)"
        find.replacement = "$2 -> $1"
        #expect(find.replacementText(for: find.matches[0], in: document.text) == "0.08 -> TAX_RATE")
    }

    @Test func plainReplacementIsLiteral() {
        let (find, document) = model(searching: "a.b")
        find.query = "a.b"
        find.replacement = "$1"
        #expect(find.replacementText(for: find.matches[0], in: document.text) == "$1")
    }
}
