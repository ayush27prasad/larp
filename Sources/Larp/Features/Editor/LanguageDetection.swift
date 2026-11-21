import CodeEditLanguages
import Foundation

/// Picks the grammar for a file.
///
/// CodeEditLanguages knows the common extensions. For everyday files it leaves
/// as plain text, a close grammar is borrowed instead: a Makefile's recipes and
/// a `.env` file read fine as shell, and XML is tags like HTML. Approximate
/// highlighting beats none.
enum LanguageDetection {
    static func language(for url: URL, prefix: String) -> CodeLanguage {
        let detected = CodeLanguage.detectLanguageFrom(url: url, prefixBuffer: prefix)
        guard detected.id == .plainText else { return detected }
        return fallback(for: url) ?? detected
    }

    static func fallback(for url: URL) -> CodeLanguage? {
        let name = url.lastPathComponent.lowercased()

        if name == "dockerfile" || name.hasPrefix("dockerfile.") || name.hasSuffix(".dockerfile") {
            return .dockerfile
        }
        if ["makefile", "gnumakefile"].contains(name) || name == ".env" || name.hasPrefix(".env.")
            || [".bashrc", ".zshrc", ".profile", ".zprofile", ".bash_profile", ".zshenv"].contains(name) {
            return .bash
        }

        switch url.pathExtension.lowercased() {
        case "mk": return .bash
        case "xml", "plist", "svg", "xib", "storyboard", "xcscheme", "entitlements": return .html
        case "jsonc", "json5", "geojson": return .json
        case "ini", "cfg", "conf": return .toml
        case "mjs", "cjs": return .javascript
        case "mts", "cts": return .typescript
        default: return nil
        }
    }

    /// What the status bar calls the language.
    static func displayName(of language: CodeLanguage) -> String {
        switch language.id {
        case .plainText: "Plain Text"
        case .cpp: "C++"
        case .cSharp: "C#"
        case .objc: "Objective-C"
        case .tsx: "TypeScript JSX"
        case .jsx: "JavaScript JSX"
        case .typescript: "TypeScript"
        case .javascript: "JavaScript"
        case .json: "JSON"
        case .yaml: "YAML"
        case .toml: "TOML"
        case .html: "HTML"
        case .css: "CSS"
        case .sql: "SQL"
        case .php: "PHP"
        default: language.id.rawValue.prefix(1).uppercased() + language.id.rawValue.dropFirst()
        }
    }
}
