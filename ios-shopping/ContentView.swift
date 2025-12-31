//
//  ContentView.swift
//  ios-shopping
//
//  Created by user279407 on 12/11/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Product.isBought, ascending: true),
            NSSortDescriptor(keyPath: \Product.productName, ascending: true)
        ],
        animation: .default)
    private var items: FetchedResults<Product>

    var body: some View {
        NavigationView {
            List {
                ForEach(items) { item in
                    HStack {
                        Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                        NavigationLink {
                            EditOrAddView(passedProduct: item)
                        } label: {
                            Text(item.productName ?? "")
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
                        EditOrAddView(passedProduct: nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TokenStorage())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
