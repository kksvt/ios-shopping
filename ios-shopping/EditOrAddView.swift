import SwiftUI
import CoreData

struct EditOrAddView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var tokenStorage: TokenStorage

    let apiURL: String

    @State var currentProduct: Product?
    @State var productName: String
    @State var isBought: Bool
    @State var quantity: Int16
    @State var note: String
    @State var price: Double
    @State var isPaid: Bool

    @State private var selectedCategory: NSManagedObjectID?
    @State private var srvMessage: String = ""

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.categoryName, ascending: true)],
        animation: .default)
    private var categories: FetchedResults<Category>

    init(passedProduct: Product?, apiURL: String) {
        self.apiURL = apiURL //init is now explicit, we have to assign to this

        if let p = passedProduct {
            _currentProduct = State(initialValue: p)
            _productName = State(initialValue: p.productName ?? "")
            _isBought = State(initialValue: p.isBought)
            _quantity = State(initialValue: p.quantity)
            _note = State(initialValue: p.note ?? "")
            _selectedCategory = State(initialValue: p.relationship?.objectID)
            _price = State(initialValue: p.price)
            _isPaid = State(initialValue: p.isPaid)
        } else {
            _productName = State(initialValue: "")
            _isBought = State(initialValue: false)
            _quantity = State(initialValue: 1)
            _note = State(initialValue: "")
            _selectedCategory = State(initialValue: nil)
            _price = State(initialValue: 0)
            _isPaid = State(initialValue: false)
        }
    }

    private func saveProduct() {
        withAnimation {
            if currentProduct == nil {
                currentProduct = Product(context: viewContext)
            }

            currentProduct?.productName = productName
            currentProduct?.note = note
            currentProduct?.isBought = isBought
            currentProduct?.quantity = quantity
            currentProduct?.isPaid = isPaid
            currentProduct?.price = price

            if let selectedCategory,
               let category = categories.first(where: { $0.objectID == selectedCategory }) {
                currentProduct?.relationship = category
            } else {
                currentProduct?.relationship = nil
            }

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }

        if let token = tokenStorage.getToken(), !token.isEmpty {
            srvMessage = syncProductsToServer(
                context: viewContext,
                apiURL: apiURL,
                token: token
            )
        } else {
            srvMessage = "No token."
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories) { category in
                            Text(category.categoryName!)
                                .tag(category.objectID as NSManagedObjectID?)
                        }
                    }
                    .onAppear {
                        if currentProduct == nil, selectedCategory == nil {
                            selectedCategory = categories.first?.objectID
                        }
                    }
                }

                Section("Product") {
                    TextField("Name", text: $productName)
                    TextField("Note", text: $note)
                }

                Section("Quantity") {
                    Stepper("\(quantity)", value: $quantity, in: 1...99)
                }
                
                Section("Price") {
                    Text("Unit: \(price, specifier: "%.2f")")
                    Text("Total: \(price * Double(quantity), specifier: "%.2f")")
                }

                Section("Status") {
                    Toggle("In Cart", isOn: $isBought) //mismatch, but its almost 5 am
                }

                if !srvMessage.isEmpty {
                    Section("Server") {
                        Text(srvMessage)
                    }
                }

                Section {
                    Button("Save", action: saveProduct)
                        .font(.headline)
                }
            }
        }
    }
}
