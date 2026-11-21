import Foundation
import Testing

@testable import Larp

struct TextFileLoaderTests {
    private func load(_ data: Data) async throws -> TextFileLoader.Contents {
        let temp = try TempDirectory()
        return try await TextFileLoader.load(try temp.write(data, to: "file.txt"))
    }

    @Test func readsUTF8Text() async throws {
        let contents = try await load(Data("hello — world\n".utf8))
        #expect(contents == .init(text: "hello — world\n", encoding: .utf8))
    }

    @Test func keepsTheByteOrderMarkOutOfTheText() async throws {
        let contents = try await load(TextEncoding.utf8WithBOM.byteOrderMark + Data("hi\n".utf8))
        #expect(contents == .init(text: "hi\n", encoding: .utf8WithBOM))
    }

    /// These used to be refused; before that, mis-decoded and corrupted on save.
    @Test func readsLatin1AsWindows1252() async throws {
        let contents = try await load("café naïve\n".data(using: .isoLatin1)!)
        #expect(contents == .init(text: "café naïve\n", encoding: .windows1252))
    }

    @Test func readsUTF16ByItsByteOrderMark() async throws {
        let little = try await load(Data([0xFF, 0xFE]) + "日本語 ok".data(using: .utf16LittleEndian)!)
        #expect(little == .init(text: "日本語 ok", encoding: .utf16LittleEndian))

        let big = try await load(Data([0xFE, 0xFF]) + "ok".data(using: .utf16BigEndian)!)
        #expect(big == .init(text: "ok", encoding: .utf16BigEndian))
    }

    @Test func rejectsBinaryContent() async throws {
        await #expect(throws: TextFileLoader.Failure.notText) {
            try await load(Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x01]))
        }
    }

    @Test func rejectsFilesOverTheSizeLimit() async throws {
        let byteCount = TextFileLoader.maximumByteCount + 1
        await #expect(throws: TextFileLoader.Failure.tooLarge(byteCount: byteCount)) {
            try await load(Data(repeating: 0x41, count: byteCount))
        }
    }

    @Test func reportsUnreadableFiles() async throws {
        let temp = try TempDirectory()
        await #expect(throws: TextFileLoader.Failure.self) {
            try await TextFileLoader.load(temp.url.appendingPathComponent("absent.txt"))
        }
    }
}
