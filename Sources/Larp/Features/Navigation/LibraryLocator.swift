import CodeEditLanguages
import Foundation

/// Where the libraries a file imports keep their source, for ⌘-click on a
/// name the project doesn't define.
///
/// A stand-in for language servers, which know each library's exact version
/// and location. This reads the file's imports and the project's manifests —
/// a virtualenv, `node_modules`, `go.mod`, `Cargo.lock` — and points at the
/// source those name, so a search stays inside a few packages instead of the
/// whole cache. Java and Kotlin libraries ship as compiled jars and have no
/// source to find.
enum LibraryLocator {
    /// A file or folder to look in for definitions.
    struct Location: Hashable, Sendable {
        let url: URL
        /// False for a Go package, which is exactly one folder.
        let recursive: Bool
    }

    /// Where toolchains and package caches live on this machine.
    struct Environment: Sendable {
        var goRoot: URL?
        var goModCache: URL?
        /// `~/.cargo/registry/src/<index>/` folders, each holding crates.
        var cargoSources: [URL] = []
        /// The Rust standard library's source, from rustup's rust-src.
        var rustLibrary: URL?

        static let current = detect()

        private static func detect() -> Environment {
            let fm = FileManager.default
            let env = ProcessInfo.processInfo.environment
            let home = fm.homeDirectoryForCurrentUser
            func existing(_ paths: [String?]) -> URL? {
                paths.compactMap { $0 }.map { URL(fileURLWithPath: $0, isDirectory: true) }
                    .first { fm.fileExists(atPath: $0.path) }
            }
            func children(_ url: URL) -> [URL] {
                ((try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? [])
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
            }

            var environment = Environment()
            // An app launched from the Dock has no shell PATH or GOROOT, so
            // look where the installers put Go.
            environment.goRoot = existing([
                env["GOROOT"],
                "/opt/homebrew/opt/go/libexec",
                "/usr/local/opt/go/libexec",
                "/usr/local/go",
            ].map { $0.map { $0 + "/src/fmt" } })?
                .deletingLastPathComponent().deletingLastPathComponent()
            environment.goModCache = existing([
                env["GOMODCACHE"],
                env["GOPATH"].map { $0 + "/pkg/mod" },
                home.path + "/go/pkg/mod",
            ])
            let cargoHome = env["CARGO_HOME"] ?? home.path + "/.cargo"
            environment.cargoSources = children(URL(fileURLWithPath: cargoHome + "/registry/src"))
            let toolchains = children(home.appendingPathComponent(".rustup/toolchains"))
            environment.rustLibrary = toolchains
                .map { $0.appendingPathComponent("lib/rustlib/src/rust/library") }
                .last { fm.fileExists(atPath: $0.path) }
            return environment
        }
    }

    /// File extensions worth searching for `language`.
    static func extensions(for language: TreeSitterLanguage) -> Set<String> {
        switch language {
        case .python: ["py", "pyi"]
        case .go: ["go"]
        case .rust: ["rs"]
        case .typescript, .tsx, .javascript, .jsx: ["ts", "tsx", "js", "jsx", "mjs", "cjs", "mts", "cts"]
        default: []
        }
    }

    /// - Parameters:
    ///   - qualifier: what precedes the name, as `http` in `http.Get` or
    ///     `serde_json` in `serde_json::to_string`.
    ///   - root: the project folder; manifests are looked for between the
    ///     file and it.
    static func locations(
        for name: String,
        qualifier: String?,
        in file: URL,
        text: String,
        language: TreeSitterLanguage,
        root: URL?,
        environment: Environment = .current
    ) -> [Location] {
        let folders = enclosingFolders(of: file, root: root)
        switch language {
        case .python:
            return python(name: name, qualifier: qualifier, text: text, folders: folders)
        case .typescript, .tsx, .javascript, .jsx:
            return javascript(name: name, qualifier: qualifier, text: text, folders: folders)
        case .go:
            return go(qualifier: qualifier, text: text, folders: folders, environment: environment)
        case .rust:
            return rust(name: name, qualifier: qualifier, text: text, folders: folders, environment: environment)
        default:
            return []
        }
    }

    // MARK: - Python

    private static func python(name: String, qualifier: String?, text: String, folders: [URL]) -> [Location] {
        // `import a.b as c` binds c (or a); `from a.b import x` binds x.
        var imports: [(package: String, binds: [String])] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let line = line.trimmingCharacters(in: .whitespaces)
            if let match = firstMatch(#"^from\s+([\w.]+)\s+import\s+\(?([^#)]*)"#, in: line) {
                guard !match[0].hasPrefix(".") else { continue }
                let binds = match[1].split(separator: ",").map {
                    $0.split(separator: " ").last.map(String.init) ?? ""
                }
                imports.append((topLevel(match[0], separator: "."), binds))
            } else if let match = firstMatch(#"^import\s+([^#]+)"#, in: line) {
                for part in match[0].split(separator: ",") {
                    let words = part.split(separator: " ").map(String.init)
                    guard let module = words.first else { continue }
                    let bound = words.count == 3 ? words[2] : topLevel(module, separator: ".")
                    imports.append((topLevel(module, separator: "."), [bound]))
                }
            }
        }
        let wanted = qualifier ?? name
        var packages = imports.filter { $0.binds.contains(wanted) || $0.binds.contains("*") }.map(\.package)
        if packages.isEmpty { packages = imports.map(\.package) }

        let fm = FileManager.default
        var roots: [URL] = []
        for folder in folders {
            for venvName in [".venv", "venv", "env"] {
                let venv = folder.appendingPathComponent(venvName)
                let config = venv.appendingPathComponent("pyvenv.cfg")
                guard let cfg = try? String(contentsOf: config, encoding: .utf8) else { continue }
                let lib = venv.appendingPathComponent("lib")
                for version in (try? fm.contentsOfDirectory(atPath: lib.path)) ?? [] where version.hasPrefix("python") {
                    roots.append(lib.appendingPathComponent(version).appendingPathComponent("site-packages"))
                    // The standard library sits beside the interpreter the
                    // venv was made from: <home>/../lib/pythonX.Y.
                    if let home = firstMatch(#"(?m)^home\s*=\s*(.+)$"#, in: cfg)?.first {
                        roots.append(URL(fileURLWithPath: home.trimmingCharacters(in: .whitespaces))
                            .deletingLastPathComponent()
                            .appendingPathComponent("lib").appendingPathComponent(version))
                    }
                }
            }
        }
        return unique(packages.flatMap { package in
            roots.flatMap { root in
                [
                    Location(url: root.appendingPathComponent(package), recursive: true),
                    Location(url: root.appendingPathComponent(package + ".py"), recursive: false),
                    Location(url: root.appendingPathComponent(package + ".pyi"), recursive: false),
                ]
            }
        }.filter { fm.fileExists(atPath: $0.url.path) })
    }

    // MARK: - JavaScript and TypeScript

    private static func javascript(name: String, qualifier: String?, text: String, folders: [URL]) -> [Location] {
        // (what the statement binds, the module specifier)
        var imports: [(clause: String, module: String)] = []
        for match in allMatches(#"import\s+([^;]*?)\s+from\s+['"]([^'"]+)['"]"#, in: text) {
            imports.append((match[0], match[1]))
        }
        for match in allMatches(#"(?:const|let|var)\s+([^=]+?)\s*=\s*require\(\s*['"]([^'"]+)['"]\s*\)"#, in: text) {
            imports.append((match[0], match[1]))
        }
        // Only packages: relative imports are project files, already indexed.
        imports = imports.filter { !$0.module.hasPrefix(".") && !$0.module.hasPrefix("/") }
        let wanted = qualifier ?? name
        var modules = imports.filter { containsWord(wanted, in: $0.clause) }.map(\.module)
        if modules.isEmpty { modules = imports.map(\.module) }

        let packages = modules.map { module -> String in
            let parts = module.split(separator: "/").map(String.init)
            return module.hasPrefix("@") && parts.count > 1 ? parts[0] + "/" + parts[1] : parts[0]
        }
        let fm = FileManager.default
        let nodeModules = folders.map { $0.appendingPathComponent("node_modules") }
            .filter { fm.fileExists(atPath: $0.path) }
        return unique(packages.flatMap { package in
            // Types for an untyped package live in @types, @scope/x as scope__x.
            let typesName = package.hasPrefix("@")
                ? String(package.dropFirst()).replacingOccurrences(of: "/", with: "__") : package
            return nodeModules.flatMap { modules in
                [
                    Location(url: modules.appendingPathComponent(package), recursive: true),
                    Location(url: modules.appendingPathComponent("@types/" + typesName), recursive: true),
                ]
            }
        }.filter { fm.fileExists(atPath: $0.url.path) })
    }

    // MARK: - Go

    private static func go(qualifier: String?, text: String, folders: [URL], environment: Environment) -> [Location] {
        // Another package's names are always qualified in Go; an unqualified
        // name is this package's own, which the project index covers.
        guard let qualifier else { return [] }
        var imports: [(alias: String?, path: String)] = []
        var specs: [String] = []
        for block in allMatches(#"(?s)import\s*\((.*?)\)"#, in: text) {
            specs += block[0].split(whereSeparator: \.isNewline).map(String.init)
        }
        specs += allMatches(#"(?m)^import\s+(\w+\s+)?("[^"]+")"#, in: text).map { $0.joined(separator: " ") }
        for spec in specs {
            guard let match = firstMatch(#"^\s*(\w+|\.)?\s*"([^"]+)""#, in: spec) else { continue }
            imports.append((match[0].isEmpty ? nil : match[0], match[1]))
        }
        let paths = imports.filter { ($0.alias ?? goPackageName($0.path)) == qualifier }.map(\.path)

        let fm = FileManager.default
        let goMod = folders.map { $0.appendingPathComponent("go.mod") }.first { fm.fileExists(atPath: $0.path) }
        let requires = goMod.flatMap { try? String(contentsOf: $0, encoding: .utf8) }.map(goRequires) ?? [:]

        return unique(paths.compactMap { path -> Location? in
            // A standard library path has no domain in its first element.
            if !(path.split(separator: "/").first ?? "").contains(".") {
                return environment.goRoot.map {
                    Location(url: $0.appendingPathComponent("src/" + path), recursive: false)
                }
            }
            if let vendor = goMod?.deletingLastPathComponent().appendingPathComponent("vendor/" + path),
               fm.fileExists(atPath: vendor.path) {
                return Location(url: vendor, recursive: false)
            }
            guard let module = requires.keys.filter({ path == $0 || path.hasPrefix($0 + "/") })
                    .max(by: { $0.count < $1.count }),
                  let version = requires[module], let cache = environment.goModCache
            else { return nil }
            let rest = String(path.dropFirst(module.count))
            return Location(
                url: cache.appendingPathComponent(goEscape(module) + "@" + version + rest),
                recursive: false)
        }.filter { fm.fileExists(atPath: $0.url.path) })
    }

    /// The name a Go import path is used by: its last element, minus a major
    /// version suffix (`chi/v5`) or a gopkg.in one (`yaml.v3`).
    static func goPackageName(_ path: String) -> String {
        var parts = path.split(separator: "/").map(String.init)
        if parts.count > 1, let last = parts.last, last.wholeMatch(of: /v\d+/) != nil { parts.removeLast() }
        let last = parts.last ?? path
        return last.replacing(/\.v\d+$/, with: "").replacingOccurrences(of: "-", with: "_")
    }

    /// Module path → version, from go.mod's require lines.
    static func goRequires(_ goMod: String) -> [String: String] {
        var requires: [String: String] = [:]
        var inBlock = false
        for raw in goMod.split(whereSeparator: \.isNewline) {
            let line = raw.split(separator: "//").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
            if line.hasPrefix("require (") { inBlock = true; continue }
            if inBlock && line == ")" { inBlock = false; continue }
            let words = line.split(separator: " ").map(String.init)
            if inBlock, words.count >= 2 {
                requires[words[0]] = words[1]
            } else if words.first == "require", words.count >= 3 {
                requires[words[1]] = words[2]
            }
        }
        return requires
    }

    /// The module cache spells capitals as `!` plus the lower-case letter.
    static func goEscape(_ path: String) -> String {
        path.map { $0.isUppercase ? "!" + $0.lowercased() : String($0) }.joined()
    }

    // MARK: - Rust

    private static func rust(
        name: String, qualifier: String?, text: String, folders: [URL], environment: Environment
    ) -> [Location] {
        // The crate is the first element of a path: `serde_json::to_string`,
        // or of the `use` that brought the name or its qualifier in.
        var crates: [String] = []
        for use in allMatches(#"(?s)\buse\s+([^;]+);"#, in: text) {
            let path = use[0]
            if containsWord(qualifier ?? name, in: path), let crate = path.split(separator: ":").first {
                crates.append(crate.trimmingCharacters(in: .whitespaces))
            }
        }
        if let qualifier { crates.append(qualifier) }
        crates = crates.filter { !["crate", "self", "super", "Self"].contains($0) }

        let fm = FileManager.default
        let lock = folders.map { $0.appendingPathComponent("Cargo.lock") }.first { fm.fileExists(atPath: $0.path) }
        let versions = lock.flatMap { try? String(contentsOf: $0, encoding: .utf8) }.map(cargoLockVersions) ?? [:]

        return unique(crates.flatMap { crate -> [Location] in
            if ["std", "core", "alloc"].contains(crate) {
                return environment.rustLibrary.map {
                    [Location(url: $0.appendingPathComponent(crate + "/src"), recursive: true)]
                } ?? []
            }
            return environment.cargoSources.compactMap { registry -> Location? in
                let dirs = (try? fm.contentsOfDirectory(atPath: registry.path)) ?? []
                let candidates = dirs.filter { dir in
                    guard let dash = dir.lastIndex(of: "-") else { return false }
                    return dir[..<dash].replacingOccurrences(of: "-", with: "_") == crate
                }
                let pinned = versions[crate].flatMap { version in
                    candidates.first { $0.hasSuffix("-" + version) }
                }
                guard let dir = pinned ?? candidates.max(by: versionOrder) else { return nil }
                return Location(url: registry.appendingPathComponent(dir + "/src"), recursive: true)
            }
        }.filter { fm.fileExists(atPath: $0.url.path) })
    }

    /// Crate name, with `-` as `_` the way code spells it, → locked version.
    static func cargoLockVersions(_ lock: String) -> [String: String] {
        var versions: [String: String] = [:]
        for package in lock.components(separatedBy: "[[package]]") {
            guard let name = firstMatch(#"(?m)^name\s*=\s*"([^"]+)""#, in: package)?.first,
                  let version = firstMatch(#"(?m)^version\s*=\s*"([^"]+)""#, in: package)?.first
            else { continue }
            versions[name.replacingOccurrences(of: "-", with: "_")] = version
        }
        return versions
    }

    private static func versionOrder(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: .numeric) == .orderedAscending
    }

    // MARK: - Helpers

    /// The file's folder and each one above it up to the project root, or a
    /// few levels for a file outside any project.
    static func enclosingFolders(of file: URL, root: URL?) -> [URL] {
        var folders: [URL] = []
        var folder = file.deletingLastPathComponent().standardizedFileURL
        let root = root?.standardizedFileURL
        let inside = root.map { folder.path == $0.path || folder.path.hasPrefix($0.path + "/") } ?? false
        for _ in 0..<12 {
            folders.append(folder)
            if inside, folder.path == root?.path { break }
            let parent = folder.deletingLastPathComponent()
            if parent.path == folder.path { break }
            folder = parent
        }
        return folders
    }

    private static func topLevel(_ module: String, separator: Character) -> String {
        String(module.split(separator: separator).first ?? Substring(module))
    }

    private static func containsWord(_ word: String, in text: String) -> Bool {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func unique(_ locations: [Location]) -> [Location] {
        var seen = Set<Location>()
        return locations.filter { seen.insert($0).inserted }
    }

    /// Capture groups of the first match; an unmatched group is "".
    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        allMatches(pattern, in: text, limit: 1).first
    }

    private static func allMatches(_ pattern: String, in text: String, limit: Int = .max) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let string = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: string.length)).prefix(limit).map { match in
            (1..<match.numberOfRanges).map {
                let range = match.range(at: $0)
                return range.location == NSNotFound ? "" : string.substring(with: range)
            }
        }
    }
}
