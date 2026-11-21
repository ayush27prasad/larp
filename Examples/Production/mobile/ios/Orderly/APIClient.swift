import Foundation

struct APIClient {
    var baseURL = URL(string: "http://localhost:8080")!
    var session = URLSession.shared

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    func orders(for customerId: String) async throws -> [Order] {
        var components = URLComponents(url: baseURL.appending(path: "orders"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "customer_id", value: customerId)]
        let (data, _) = try await session.data(from: components.url!)
        return try decoder.decode([Order].self, from: data)
    }
}
