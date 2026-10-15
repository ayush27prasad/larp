import Foundation
import Testing

@testable import iKhalacy

@MainActor
struct DocumentStoreTests {
    @Test func opensAFileIntoATabAndActivatesIt() async throws {
        let temp = try TempDirectory()
        let file = try temp.write("hello", to: "a.txt")

        let store = DocumentStore()
        try await store.open(file)

        #expect(store.documents.count == 1)
        #expect(store.activeDocumentID == file)
        #expect(store.activeDocument?.text == "hello")
    }

    @Test func reopeningAFileFocusesTheExistingTab() async throws {
        let temp = try TempDirectory()
        let first = try temp.write("1", to: "a.txt")
        let second = try temp.write("2", to: "b.txt")

        let store = DocumentStore()
        try await store.open(first)
        try await store.open(second)
        try await store.open(first)

        #expect(store.documents.count == 2)
        #expect(store.activeDocumentID == first)
    }

    @Test func closingTheActiveTabFocusesTheOneToItsLeft() async throws {
        let temp = try TempDirectory()
        let a = try temp.write("1", to: "a.txt")
        let b = try temp.write("2", to: "b.txt")
        let c = try temp.write("3", to: "c.txt")

        let store = DocumentStore()
        try await store.open(a)
        try await store.open(b)
        try await store.open(c)
        store.close(c)

        #expect(store.openURLs == [a, b])
        #expect(store.activeDocumentID == b)
    }

    @Test func closingTheOnlyTabLeavesNothingActive() async throws {
        let temp = try TempDirectory()
        let file = try temp.write("1", to: "a.txt")

        let store = DocumentStore()
        try await store.open(file)
        store.close(file)

        #expect(store.hasOpenDocuments == false)
        #expect(store.activeDocumentID == nil)
    }

    @Test func closingAnInactiveTabKeepsTheActiveOne() async throws {
        let temp = try TempDirectory()
        let a = try temp.write("1", to: "a.txt")
        let b = try temp.write("2", to: "b.txt")

        let store = DocumentStore()
        try await store.open(a)
        try await store.open(b)
        store.close(a)

        #expect(store.activeDocumentID == b)
    }

    @Test func refusesToOpenBinaryFiles() async throws {
        let temp = try TempDirectory()
        let file = try temp.write(Data([0x00, 0x01, 0x02]), to: "blob.bin")

        let store = DocumentStore()
        await #expect(throws: TextFileLoader.Failure.notText) {
            try await store.open(file)
        }
        #expect(store.hasOpenDocuments == false)
    }
}

@MainActor
struct OpenDocumentTests {
    @Test func startsClean() async throws {
        let temp = try TempDirectory()
        let file = try temp.write("hello", to: "a.swift")

        let document = OpenDocument(url: file, text: "hello")
        #expect(document.isDirty == false)
        #expect(document.name == "a.swift")
    }

    @Test func becomesDirtyOnEditAndCleanOnSave() async throws {
        let temp = try TempDirectory()
        let file = try temp.write("hello", to: "a.txt")

        let document = OpenDocument(url: file, text: "hello")
        document.text = "hello world"
        #expect(document.isDirty)

        try document.save()
        #expect(document.isDirty == false)
        #expect(try String(contentsOf: file, encoding: .utf8) == "hello world")
    }

    @Test func editingBackToTheSavedContentClearsDirty() async throws {
        let temp = try TempDirectory()
        let file = try temp.write("hello", to: "a.txt")

        let document = OpenDocument(url: file, text: "hello")
        document.text = "changed"
        document.text = "hello"
        #expect(document.isDirty == false)
    }

    @Test func detectsLanguageFromTheFileName() async throws {
        let temp = try TempDirectory()
        let swiftFile = try temp.write("", to: "a.swift")
        let pythonFile = try temp.write("", to: "b.py")

        #expect(OpenDocument(url: swiftFile, text: "").language.id == .swift)
        #expect(OpenDocument(url: pythonFile, text: "").language.id == .python)
    }
}

@MainActor
struct PreviewTabTests {
    @Test func singleClickOpensAPreviewTab() async throws {
        let temp = try TempDirectory()
        let file = try temp.write("1", to: "a.txt")

        let store = DocumentStore()
        try await store.open(file, preview: true)
        #expect(store.isPreview(file))
    }

    @Test func aSecondPreviewReplacesTheFirst() async throws {
        let temp = try TempDirectory()
        let a = try temp.write("1", to: "a.txt")
        let b = try temp.write("2", to: "b.txt")

        let store = DocumentStore()
        try await store.open(a, preview: true)
        try await store.open(b, preview: true)

        #expect(store.openURLs == [b])
        #expect(store.isPreview(b))
    }

    @Test func doubleClickPinsThePreview() async throws {
        let temp = try TempDirectory()
        let a = try temp.write("1", to: "a.txt")
        let b = try temp.write("2", to: "b.txt")

        let store = DocumentStore()
        try await store.open(a, preview: true)
        try await store.open(a, preview: false)
        try await store.open(b, preview: true)

        #expect(store.openURLs == [a, b])
        #expect(store.isPreview(a) == false)
    }

    @Test func aDirtyPreviewIsNeverDiscarded() async throws {
        let temp = try TempDirectory()
        let a = try temp.write("1", to: "a.txt")
        let b = try temp.write("2", to: "b.txt")

        let store = DocumentStore()
        let document = try await store.open(a, preview: true)
        document.text = "edited"
        try await store.open(b, preview: true)

        #expect(store.openURLs == [a, b])
        #expect(store.isPreview(a) == false)
    }

    @Test func closingThePreviewClearsIt() async throws {
        let temp = try TempDirectory()
        let a = try temp.write("1", to: "a.txt")

        let store = DocumentStore()
        try await store.open(a, preview: true)
        store.close(a)
        #expect(store.previewDocumentID == nil)
    }

    @Test func pinnedTabsAccumulate() async throws {
        let temp = try TempDirectory()
        let a = try temp.write("1", to: "a.txt")
        let b = try temp.write("2", to: "b.txt")

        let store = DocumentStore()
        try await store.open(a)
        try await store.open(b)
        #expect(store.openURLs == [a, b])
        #expect(store.previewDocumentID == nil)
    }
}
