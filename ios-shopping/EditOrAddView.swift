import SwiftUI
import CoreData

struct EditOrAddView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State var currentProduct: Product?
    @State var productName: String
    @State var isBought: Bool
    @State var quantity: Int16
    @State var note: String
    
    @State private var selectedCategory: NSManagedObjectID?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.categoryName, ascending: true)],
        animation: .default)
    private var categories: FetchedResults<Category>
    
    init(passedProduct: Product?) {
        if let p = passedProduct {
            _currentProduct = State(initialValue: p)
            _productName = State(initialValue: p.productName ?? "")
            _isBought = State(initialValue: p.isBought)
            _quantity = State(initialValue: p.quantity)
            _note = State(initialValue: p.note ?? "")
            _selectedCategory = State(initialValue: p.relationship?.objectID)
        }
        else {
            _productName = State(initialValue: "")
            _isBought = State(initialValue: false)
            _quantity = State(initialValue: 1)
            _note = State(initialValue: "")
            _selectedCategory = State(initialValue: nil)
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
                
                Section("Status") {
                    Toggle("Purchased", isOn: $isBought)
                }
                
                Section() {
                    Button("Save", action: saveProduct)
                        .font(.headline)
                }
            }
        }
    }
}

#Preview {
    EditOrAddView(passedProduct: nil)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
