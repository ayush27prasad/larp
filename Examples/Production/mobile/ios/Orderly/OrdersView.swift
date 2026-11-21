import SwiftUI

struct OrdersView: View {
    let customerId: String
    var client = APIClient()

    @State private var orders: [Order] = []
    @State private var error: String?

    var body: some View {
        List(orders) { order in
            HStack {
                VStack(alignment: .leading) {
                    Text(order.id).font(.headline)
                    Text(order.status.rawValue.capitalized).foregroundStyle(.secondary)
                }
                Spacer()
                Text(order.formattedTotal).monospacedDigit()
            }
        }
        .overlay {
            if let error { ContentUnavailableView("Couldn't load orders", systemImage: "wifi.slash", description: Text(error)) }
        }
        .navigationTitle("Orders")
        .task {
            do { orders = try await client.orders(for: customerId) }
            catch { self.error = error.localizedDescription }
        }
    }
}
