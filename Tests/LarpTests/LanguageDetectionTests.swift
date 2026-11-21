import CodeEditLanguages
import Foundation
import Testing

@testable import Larp

struct LanguageDetectionTests {
    /// The detected language's name, since its enum isn't Sendable enough for test arguments.
    private func language(_ name: String) -> String {
        LanguageDetection.language(for: URL(fileURLWithPath: "/project/\(name)"), prefix: "").id.rawValue
    }

    @Test(arguments: [
        ("README.md", "markdown"), ("app.yaml", "yaml"), ("flags.json", "json"),
        ("settings.toml", "toml"), ("pricing.py", "python"), ("stock.go", "go"), ("Payment.java", "java"),
        ("main.rs", "rust"), ("App.tsx", "tsx"), ("client.ts", "typescript"), ("index.html", "html"),
        ("app.css", "css"), ("Order.swift", "swift"), ("Order.kt", "kotlin"), ("V1__init.sql", "sql"),
        ("deploy.sh", "bash"),
    ])
    func detectsCommonFiles(_ name: String, _ expected: String) {
        #expect(language(name) == expected)
    }

    @Test(arguments: [
        ("Makefile", "bash"), (".env", "bash"), (".env.example", "bash"), (".zshrc", "bash"),
        ("Dockerfile", "dockerfile"), ("Dockerfile.dev", "dockerfile"), ("pom.xml", "html"),
        ("Info.plist", "html"), ("tsconfig.jsonc", "json"), ("setup.cfg", "toml"), ("vite.config.mjs", "javascript"),
    ])
    func borrowsAGrammarForEverydayFilesItDoesNotKnow(_ name: String, _ expected: String) {
        #expect(language(name) == expected)
    }

    @Test func leavesUnknownFilesAsPlainText() {
        #expect(language("notes.unknownext") == "plainText")
    }
}

@MainActor
struct MarkdownDocumentTests {
    @Test func markdownOpensAsAPreview() {
        let document = OpenDocument(url: URL(fileURLWithPath: "/p/README.md"), text: "# Hi")
        #expect(document.isMarkdown)
        #expect(document.showsPreview)
    }

    @Test func otherFilesOpenAsSource() {
        let document = OpenDocument(url: URL(fileURLWithPath: "/p/main.py"), text: "x = 1")
        #expect(document.isMarkdown == false)
        #expect(document.showsPreview == false)
    }

    @Test func remembersCRLFLineEndings() {
        #expect(OpenDocument(url: URL(fileURLWithPath: "/p/a.txt"), text: "a\r\nb").usesCRLF)
        #expect(OpenDocument(url: URL(fileURLWithPath: "/p/a.txt"), text: "a\nb").usesCRLF == false)
    }
}
