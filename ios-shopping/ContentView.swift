import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var tokenStorage: TokenStorage

    let apiURL: String

    @State private var payTotal: Double = 0
    @State private var payPaid: Double = 0
    @State private var payRemaining: Double = 0
    @State private var payMessage: String = ""

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Product.isBought, ascending: true),
            NSSortDescriptor(keyPath: \Product.productName, ascending: true)
        ],
        animation: .default)
    private var items: FetchedResults<Product>

    func fetchPaySummary() {
        payMessage = ""

        guard let token = tokenStorage.getToken(), !token.isEmpty else {
            payMessage = "No token."
            return
        }

        let config = URLSessionConfiguration.default
        let finalURL = apiURL + "auth/pay"
        
        var request = URLRequest(url: URL(string: finalURL)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: config)
        let dispatch = DispatchGroup()

        var responseData: Data?
        var statusCode: Int?
        var networkError: Error?

        dispatch.enter()
        let task = session.dataTask(with: request) { data, response, err in
            defer { dispatch.leave() }
            networkError = err
            responseData = data
            statusCode = (response as? HTTPURLResponse)?.statusCode
        }

        task.resume()
        dispatch.wait()

        if let networkError {
            payMessage = "Network error: \(networkError.localizedDescription)"
            return
        }

        guard let code = statusCode else {
            payMessage = "No HTTP response."
            return
        }

        guard let data = responseData else {
            payMessage = "No data."
            return
        }

        guard code == 200 else {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["message"] as? String {
                payMessage = "Server: \(msg) (\(code))"
            } else {
                payMessage = "Request failed (\(code))."
            }
            return
        }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            payMessage = "Bad JSON."
            return
        }

        payTotal = (obj["total"] as? Double) ?? Double(obj["total"] as? Int ?? 0)
        payPaid = (obj["paid"] as? Double) ?? Double(obj["paid"] as? Int ?? 0)
        payRemaining = (obj["remaining"] as? Double) ?? Double(obj["remaining"] as? Int ?? 0)
    }

    var body: some View {
        NavigationView {
            List {
                Section("Payment") {
                    Text("Total: \(payTotal, specifier: "%.2f")")
                    Text("Paid: \(payPaid, specifier: "%.2f")")
                    Text("Remaining: \(payRemaining, specifier: "%.2f")")

                    if !payMessage.isEmpty {
                        Text(payMessage)
                    }

                    NavigationLink {
                        PaymentView(apiURL: apiURL, defaultAmount: payRemaining)
                    } label: {
                        Text("Open payment form")
                    }

                    Button("Refresh payment summary") {
                        fetchPaySummary()
                    }
                }


                ForEach(items) { item in
                    HStack {
                        Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                        NavigationLink {
                            EditOrAddView(passedProduct: item, apiURL: apiURL)
                        } label: {
                            Text(item.productName ?? "")
                            Text("x\(item.quantity)")
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Shopping list")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        EditOrAddView(passedProduct: nil, apiURL: apiURL)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                fetchPaySummary()
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
                if let token = tokenStorage.getToken(), !token.isEmpty {
                    syncProductsToServer(
                        context: viewContext,
                        apiURL: apiURL,
                        token: token
                    )
                }
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

#Preview {
    ContentView(apiURL: "http://74.91.113.214:800/")
        .environmentObject(TokenStorage())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
