import Foundation
import Testing

@testable import Larp

struct SymbolIndexTests {
    private func names(in source: String, file: String) async throws -> [String: String] {
        let temp = try TempDirectory()
        let url = try temp.write(source, to: file)
        let index = SymbolIndex()
        await index.update(url)
        let symbols = await index.symbols(in: url)
        return Dictionary(symbols.map { ($0.name, $0.kind.rawValue) }, uniquingKeysWith: { first, _ in first })
    }

    @Test func python() async throws {
        let found = try await names(in: """
            TAX_RATE = 0.08

            class OrderRepository:
                def add(self, order):
                    local = 1

            def calculate_total(items):
                return 0
            """, file: "pricing.py")
        #expect(found["TAX_RATE"] == "constant")
        #expect(found["OrderRepository"] == "class")
        #expect(found["add"] == "function")
        #expect(found["calculate_total"] == "function")
        #expect(found["local"] == nil)
    }

    @Test func go() async throws {
        let found = try await names(in: """
            package stock

            const Limit = 5

            type Store struct{}

            func NewStore() *Store { return nil }

            func (s *Store) Reserve(id string) error { return nil }
            """, file: "stock.go")
        #expect(found["Limit"] == "constant")
        #expect(found["Store"] == "type")
        #expect(found["NewStore"] == "function")
        #expect(found["Reserve"] == "method")
    }

    @Test func java() async throws {
        let found = try await names(in: """
            public interface CardGateway { String charge(String id); }
            public record Payment(String id) {}
            public final class PaymentService {
                public PaymentService() {}
                public Payment charge(String orderId) { return null; }
            }
            """, file: "PaymentService.java")
        #expect(found["CardGateway"] == "type")
        #expect(found["Payment"] == "class")
        #expect(found["PaymentService"] != nil)
        #expect(found["charge"] == "method")
    }

    @Test func rust() async throws {
        let found = try await names(in: """
            mod templates;
            pub struct OrderEvent { pub id: String }
            const LIMIT: i64 = 5;
            pub fn format_cents(cents: i64) -> String { String::new() }
            """, file: "main.rs")
        #expect(found["OrderEvent"] == "type")
        #expect(found["LIMIT"] == "constant")
        #expect(found["format_cents"] == "function")
        #expect(found["templates"] == "type")
    }

    @Test func typescript() async throws {
        let found = try await names(in: """
            export type OrderStatus = "PENDING" | "PAID";
            export interface Order { id: string }
            const BASE_URL = "x";
            export function listOrders(id: string) {}
            class Client { fetch() {} }
            """, file: "client.ts")
        #expect(found["OrderStatus"] == "type")
        #expect(found["Order"] == "type")
        #expect(found["BASE_URL"] == "constant")
        #expect(found["listOrders"] == "function")
        #expect(found["Client"] == "class")
        #expect(found["fetch"] == "method")
    }

    @Test func tsx() async throws {
        let found = try await names(in: """
            export function OrderRow({ order }: { order: Order }) { return <tr />; }
            """, file: "OrderRow.tsx")
        #expect(found["OrderRow"] == "function")
    }

    @Test func swift() async throws {
        let found = try await names(in: """
            enum OrderStatus { case pending, paid }
            struct Order { let id: String }
            protocol Loader {}
            func load() {}
            """, file: "Order.swift")
        #expect(found["OrderStatus"] == "type")
        #expect(found["Order"] == "type")
        #expect(found["Loader"] == "type")
        #expect(found["load"] == "function")
        #expect(found["pending"] == "constant")
    }

    @Test func kotlin() async throws {
        let found = try await names(in: """
            enum class OrderStatus { PENDING, PAID }
            data class Order(val id: String)
            class OrdersRepository { fun ordersFor(id: String): List<Order> = emptyList() }
            """, file: "Order.kt")
        #expect(found["Order"] == "class")
        #expect(found["OrdersRepository"] == "class")
        #expect(found["ordersFor"] == "function")
    }

    @Test func locatesTheNameByLineAndColumn() async throws {
        let temp = try TempDirectory()
        let url = try temp.write("x = 1\n\ndef calculate_total(items):\n    pass\n", to: "a.py")
        let index = SymbolIndex()
        await index.update(url)
        let symbol = try #require(await index.definitions(named: "calculate_total").first)
        #expect(symbol.line == 3)
        #expect(symbol.column == 5)
        #expect(symbol.preview == "def calculate_total(items):")
    }

    @Test func rebuildsAcrossFilesAndFindsByName() async throws {
        let temp = try TempDirectory()
        let a = try temp.write("def total():\n    pass\n", to: "a.py")
        let b = try temp.write("func total() {}\n", to: "b.go")
        let index = SymbolIndex()
        await index.rebuild(files: [a, b]) { _, _ in }
        let urls = await index.definitions(named: "total").map(\.url.lastPathComponent).sorted()
        #expect(urls == ["a.py", "b.go"])
    }
}

@MainActor
struct DefinitionNavigatorTests {
    private func symbol(_ name: String, in path: String, line: Int, location: Int) -> SymbolIndex.Symbol {
        SymbolIndex.Symbol(
            name: name, kind: .function, url: URL(fileURLWithPath: path),
            range: NSRange(location: location, length: name.utf16.count),
            line: line, column: 1, preview: "def \(name)():")
    }

    @Test func offersOtherFilesWithTheirLocation() {
        let definition = symbol("calculate_total", in: "/p/pricing.py", line: 40, location: 900)
        let links = DefinitionNavigator.links(
            for: "calculate_total", at: NSRange(location: 10, length: 15),
            in: URL(fileURLWithPath: "/p/routes.py"), among: [definition], root: URL(fileURLWithPath: "/p"))
        #expect(links.count == 1)
        #expect(links[0].url == definition.url)
        #expect(links[0].targetRange.start.line == 40)
        #expect(links[0].documentation == "pricing.py")
    }

    @Test func keepsSameFileJumpsInTheOpenEditorAndListsThemFirst() {
        let here = URL(fileURLWithPath: "/p/a.py")
        let links = DefinitionNavigator.links(
            for: "total", at: NSRange(location: 500, length: 5), in: here,
            among: [symbol("total", in: "/p/b.py", line: 1, location: 4), symbol("total", in: "/p/a.py", line: 2, location: 20)],
            root: nil)
        #expect(links.map(\.url) == [nil, URL(fileURLWithPath: "/p/b.py")])
    }

    @Test func clickingTheDefinitionItselfOffersNothing() {
        let here = URL(fileURLWithPath: "/p/a.py")
        let links = DefinitionNavigator.links(
            for: "total", at: NSRange(location: 20, length: 5), in: here,
            among: [symbol("total", in: "/p/a.py", line: 2, location: 20)], root: nil)
        #expect(links.isEmpty)
    }
}

@MainActor
struct WorkspaceIndexTests {
    @Test func opensAFolderIndexedAndReindexesOnSave() async throws {
        let temp = try TempDirectory()
        try temp.write("def calculate_total(items):\n    return 0\n", to: "app/pricing.py")
        let routes = try temp.write("from .pricing import calculate_total\n", to: "app/routes.py")

        let workspace = Workspace(defaults: UserDefaults(suiteName: "LarpTests-\(UUID().uuidString)")!)
        await workspace.open(folder: temp.url)
        await workspace.indexBuilt()
        #expect(await workspace.symbols.definitions(named: "calculate_total").count == 1)
        #expect(workspace.indexProgress == nil)

        await workspace.openFile(routes)
        workspace.editor.activeDocument?.text = "def apply_coupon(code):\n    pass\n"
        workspace.saveActiveDocument()
        try await Task.sleep(for: .milliseconds(200))
        #expect(await workspace.symbols.definitions(named: "apply_coupon").count == 1)
    }
}
