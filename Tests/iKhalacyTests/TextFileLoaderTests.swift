import Foundation
import Testing

@testable import iKhalacy

struct TextFileLoaderTests {
    @Test func readsUTF8Text() async throws {
        let temp = try TempDirectory()
        let file = try temp.write("hello — world\n", to: "notes.md")

        #expect(try await TextFileLoader.load(file) == "hello — world\n")
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
