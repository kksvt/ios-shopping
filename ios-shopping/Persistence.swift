//
//  Persistence.swift
//  ios-shopping
//
//  Created by user279407 on 12/11/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    private struct ProductFixture {
        let productName: String
        let note: String
        let isBought: Bool
        let quantity: Int16
        let categoryName: String
    }
    
    private static let productFixtures: [ProductFixture] = [
        ProductFixture(productName: "Milk", note: "", isBought: false, quantity: 1, categoryName: "Dairy"),
        ProductFixture(productName: "Carrots", note: "", isBought: false, quantity: 5, categoryName: "Vegetables"),
        ProductFixture(productName: "Apples", note: "", isBought: true,  quantity: 6, categoryName: "Fruits"),
        ProductFixture(productName: "Shampoo", note: "", isBought: false, quantity: 1, categoryName: "Hygiene"),
        ProductFixture(productName: "Cola", note: "1.5L bottle", isBought: true, quantity: 2, categoryName: "Beverages")
    ]
    
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        let categories = (try? viewContext.fetch(Category.fetchRequest())) ?? []
        for fixture in productFixtures {
            let product = Product(context: viewContext)
            product.productName = fixture.productName
            product.note = fixture.note
            product.isBought = fixture.isBought
            product.quantity = fixture.quantity
            
            let cat = categories.first(where: { category in
                category.categoryName == fixture.categoryName
            })
            
            if cat != nil {
                product.relationship = cat
            }
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ios_shopping")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        //homework 4: this is now fetched from a server
        //add default categories
        /*let count = (try? container.viewContext.count(for: Category.fetchRequest())) ?? 0
        if count == 0 {
            let hardcodedCategories = ["Vegetables", "Dairy", "Beverages", "Meat", "Fruits", "Electronics", "Hygiene"]
            for category in hardcodedCategories {
                let categoryData = Category(context: container.viewContext)
                categoryData.categoryName = category
            }
            do {
                try container.viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }*/
    }
}
