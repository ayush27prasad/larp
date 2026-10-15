import Foundation
import Testing

@testable import iKhalacy

struct TextFileLoaderTests {
    @Test func readsUTF8Text() async throws {
        let temp = try TempDirectory()
        let file = try temp.write("hello — world\n", to: "notes.md")

        #expect(try await TextFileLoader.load(file) == .init(text: "hello — world\n", hasByteOrderMark: false))
    }

    @Test func keepsTheByteOrderMarkOutOfTheText() async throws {
        let temp = try TempDirectory()
        let file = try temp.write(TextFileLoader.byteOrderMark + Data("hi\n".utf8), to: "bom.txt")

        #expect(try await TextFileLoader.load(file) == .init(text: "hi\n", hasByteOrderMark: true))
    }

    /// Both used to "succeed" via a UTF-16 fallback, and saving then rewrote
    /// the file as UTF-8 — garbling the Latin-1 one outright.
    @Test(arguments: [
        "café naïve\n".data(using: .isoLatin1)!,
        Data([0xFF, 0xFE]) + "日本語".data(using: .utf16LittleEndian)!,
    ])
    func refusesOtherEncodings(_ data: Data) async throws {
        let temp = try TempDirectory()
        let file = try temp.write(data, to: "legacy.txt")

        await #expect(throws: TextFileLoader.Failure.notUTF8) {
            try await TextFileLoader.load(file)
        }
    }

    @Test func rejectsBinaryContent() async throws {
        let temp = try TempDirectory()
        let file = try temp.write(Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x01]), to: "image.png")

        await #expect(throws: TextFileLoader.Failure.notText) {
            try await TextFileLoader.load(file)
        }
    }

    @Test func rejectsFilesOverTheSizeLimit() async throws {
        let temp = try TempDirectory()
        let byteCount = TextFileLoader.maximumByteCount + 1
        let file = try temp.write(Data(repeating: 0x41, count: byteCount), to: "huge.txt")

        await #expect(throws: TextFileLoader.Failure.tooLarge(byteCount: byteCount)) {
            try await TextFileLoader.load(file)
        }
    }

    @Test func reportsUnreadableFiles() async throws {
        let temp = try TempDirectory()
        let missing = temp.url.appendingPathComponent("absent.txt")

        await #expect(throws: TextFileLoader.Failure.self) {
            try await TextFileLoader.load(missing)
        }
    }
}
