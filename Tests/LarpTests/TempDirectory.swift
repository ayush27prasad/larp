import Foundation

/// A throwaway directory tree for filesystem tests.
struct TempDirectory: ~Copyable {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LarpTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    @discardableResult
    func makeDirectory(_ path: String) throws -> URL {
        let target = url.appendingPathComponent(path, isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        return target
    }

    @discardableResult
    func write(_ contents: Data, to path: String) throws -> URL {
        let target = url.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: target)
        return target
    }

    @discardableResult
    func write(_ contents: String, to path: String) throws -> URL {
        try write(Data(contents.utf8), to: path)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
