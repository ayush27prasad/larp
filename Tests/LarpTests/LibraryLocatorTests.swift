import Foundation
import Testing

@testable import Larp

struct LibraryLocatorTests {
    private func paths(_ locations: [LibraryLocator.Location], under root: URL) -> [String] {
        locations.map { String($0.url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1)) }
    }

    @Test func pythonFindsImportedPackageInTheVenv() throws {
        let temp = try TempDirectory()
        try temp.write("home = /usr/bin\n", to: "svc/.venv/pyvenv.cfg")
        try temp.write("def get(url): ...\n", to: "svc/.venv/lib/python3.12/site-packages/httpx/_api.py")
        try temp.write("class APIRouter: ...\n", to: "svc/.venv/lib/python3.12/site-packages/fastapi/routing.py")
        let file = try temp.write("""
            import httpx
            from fastapi import APIRouter, Depends
            """, to: "svc/app/main.py")

        let routerLocations = LibraryLocator.locations(
            for: "APIRouter", qualifier: nil, in: file, text: try String(contentsOf: file, encoding: .utf8),
            language: .python, root: temp.url)
        #expect(paths(routerLocations, under: temp.url) == ["svc/.venv/lib/python3.12/site-packages/fastapi"])

        let getLocations = LibraryLocator.locations(
            for: "get", qualifier: "httpx", in: file, text: try String(contentsOf: file, encoding: .utf8),
            language: .python, root: temp.url)
        #expect(paths(getLocations, under: temp.url) == ["svc/.venv/lib/python3.12/site-packages/httpx"])
    }

    @Test func javascriptFindsPackageAndItsTypes() throws {
        let temp = try TempDirectory()
        try temp.write("export function useState() {}\n", to: "web/node_modules/react/index.js")
        try temp.write("export function useState<S>(s: S): S;\n", to: "web/node_modules/@types/react/index.d.ts")
        try temp.write("export const x = 1\n", to: "web/node_modules/lodash/index.js")
        let text = """
            import { useState } from 'react';
            import _ from "lodash";
            import { api } from './api';
            """
        let file = try temp.write(text, to: "web/src/App.tsx")
        let locations = LibraryLocator.locations(
            for: "useState", qualifier: nil, in: file, text: text, language: .tsx, root: temp.url)
        #expect(paths(locations, under: temp.url) == ["web/node_modules/react", "web/node_modules/@types/react"])
    }

    @Test func goResolvesStandardLibraryAndModuleCache() throws {
        let temp = try TempDirectory()
        try temp.write("package http\n", to: "goroot/src/net/http/server.go")
        try temp.write("package chi\n", to: "modcache/github.com/go-chi/chi/v5@v5.0.12/chi.go")
        try temp.write("package burntsushi\n", to: "modcache/github.com/!burnt!sushi/toml@v1.3.2/decode.go")
        try temp.write("""
            module example.com/inventory

            require (
                github.com/go-chi/chi/v5 v5.0.12
                github.com/BurntSushi/toml v1.3.2 // indirect
            )
            """, to: "svc/go.mod")
        let text = """
            package main

            import (
                "net/http"
                "github.com/go-chi/chi/v5"
                toml "github.com/BurntSushi/toml"
            )
            """
        let file = try temp.write(text, to: "svc/cmd/main.go")
        let environment = LibraryLocator.Environment(
            goRoot: temp.url.appendingPathComponent("goroot"),
            goModCache: temp.url.appendingPathComponent("modcache"))

        func resolve(_ qualifier: String?) -> [String] {
            paths(LibraryLocator.locations(
                for: "X", qualifier: qualifier, in: file, text: text, language: .go,
                root: temp.url, environment: environment), under: temp.url)
        }
        #expect(resolve("http") == ["goroot/src/net/http"])
        #expect(resolve("chi") == ["modcache/github.com/go-chi/chi/v5@v5.0.12"])
        #expect(resolve("toml") == ["modcache/github.com/!burnt!sushi/toml@v1.3.2"])
        // Unqualified Go names belong to the file's own package.
        #expect(resolve(nil).isEmpty)
    }

    @Test func rustUsesTheLockedCrateVersion() throws {
        let temp = try TempDirectory()
        try temp.write("pub fn to_string() {}\n", to: "registry/index/serde_json-1.0.100/src/lib.rs")
        try temp.write("pub fn to_string() {}\n", to: "registry/index/serde_json-1.0.120/src/lib.rs")
        try temp.write("""
            [[package]]
            name = "serde_json"
            version = "1.0.100"
            """, to: "svc/Cargo.lock")
        let text = "use serde_json::Value;\nfn main() { serde_json::to_string(); }\n"
        let file = try temp.write(text, to: "svc/src/main.rs")
        let environment = LibraryLocator.Environment(cargoSources: [temp.url.appendingPathComponent("registry/index")])
        let locations = LibraryLocator.locations(
            for: "to_string", qualifier: "serde_json", in: file, text: text, language: .rust,
            root: temp.url, environment: environment)
        #expect(paths(locations, under: temp.url) == ["registry/index/serde_json-1.0.100/src"])
    }

    @Test func goPackageNames() {
        #expect(LibraryLocator.goPackageName("net/http") == "http")
        #expect(LibraryLocator.goPackageName("github.com/go-chi/chi/v5") == "chi")
        #expect(LibraryLocator.goPackageName("gopkg.in/yaml.v3") == "yaml")
    }

    @Test func qualifierBeforeAName() {
        let text = "x := http.Get(u); serde_json::to_string(v); plain()" as NSString
        #expect(DefinitionNavigator.qualifier(before: text.range(of: "Get"), in: text) == "http")
        #expect(DefinitionNavigator.qualifier(before: text.range(of: "to_string"), in: text) == "serde_json")
        #expect(DefinitionNavigator.qualifier(before: text.range(of: "plain"), in: text) == nil)
    }

    @Test func indexFindsLibraryDefinitionsOnDemand() async throws {
        let temp = try TempDirectory()
        try temp.write("package http\n\nfunc Get(url string) {}\n\nfunc (c *Client) Get(url string) {}\n",
                       to: "net/http/client.go")
        try temp.write("package http\n\nfunc Post() {}\n", to: "net/http/post.go")
        try temp.write("package http\n\nfunc Get() {}\n", to: "net/http/client_test.go")
        let index = SymbolIndex()
        let found = await index.libraryDefinitions(
            named: "Get",
            in: [.init(url: temp.url.appendingPathComponent("net/http"), recursive: false)],
            extensions: ["go"])
        #expect(found.count == 2)
        #expect(Set(found.map(\.kind)) == [.function, .method])
        #expect(found.allSatisfy { $0.url.lastPathComponent == "client.go" })
    }

    @MainActor
    @Test func filesOutsideTheProjectOpenReadOnly() async throws {
        let project = try TempDirectory()
        let library = try TempDirectory()
        let own = try project.write("x = 1\n", to: "main.py")
        let outside = try library.write("y = 2\n", to: "lib.py")
        let store = DocumentStore()
        store.projectRoot = project.url
        let ownDocument = try await store.open(own)
        let libraryDocument = try await store.open(outside)
        #expect(!ownDocument.isReadOnly)
        #expect(libraryDocument.isReadOnly)

        libraryDocument.text = "changed"
        try libraryDocument.save()
        #expect(try String(contentsOf: outside, encoding: .utf8) == "y = 2\n")
    }

    @Test func treeSkipsVirtualenvs() async throws {
        let temp = try TempDirectory()
        try temp.write("", to: ".venv/pyvenv.cfg")
        try temp.write("", to: "app/main.py")
        let tree = try await FileTreeLoader.load(root: temp.url)
        #expect(tree.root.children?.map(\.name) == ["app"])
    }
}
