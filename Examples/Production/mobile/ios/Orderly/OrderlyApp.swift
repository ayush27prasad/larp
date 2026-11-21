import SwiftUI

@main
struct OrderlyApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                OrdersView(customerId: "cus_demo")
            }
        }
    }
}
