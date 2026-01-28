//
//  ios_shoppingApp.swift
//  ios-shopping
//
//  Created by user279407 on 12/11/25.
//

import SwiftUI
import CoreData

@main
struct ios_shoppingApp: App {
    @StateObject private var tokenStorage = TokenStorage()
    @State private var isAuthorized: Bool = false
    
    let apiURL = "http://74.91.113.214:800/"
    
    func credentialsCheck() -> Bool {
        let config = URLSessionConfiguration.default
        let finalURL = apiURL + "auth/check"
        
        var request = URLRequest(url: URL(string: finalURL)!)
        
        if let token = tokenStorage.getToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            return false
        }
        
        let session = URLSession(configuration: config)
        let dispatch = DispatchGroup()
        
        var status = false
        
        let task = session.dataTask(with: request, completionHandler: {(data, response, err) in
            guard err == nil else {
                dispatch.leave()
                return
            }
            
            guard let http = response as? HTTPURLResponse else {
                dispatch.leave()
                return
            }
            
            status = (http.statusCode == 200)
            dispatch.leave()
            
        })
        
        dispatch.enter()
        task.resume()
        dispatch.wait()
        return status
    }
    
    func fetchProducts() {
        let context = persistenceController.container.viewContext
        let config = URLSessionConfiguration.default
        let finalURL = apiURL + "auth/products"
        
        var request = URLRequest(url: URL(string: finalURL)!)
        
        if let token = tokenStorage.getToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("No token")
            return
        }
        
        let session = URLSession(configuration: config)
        let dispatch = DispatchGroup()
        
        let task = session.dataTask(with: request, completionHandler: {(data, response, err) in
            guard err == nil else {
                print("Error: \(String(describing: err))")
                dispatch.leave()
                return
            }
            
            guard data != nil else {
                print("Query returns no data.")
                dispatch.leave()
                return
            }	
            
            do {
                let readableData = try JSONSerialization.jsonObject(with: data!)
                
                guard let array = readableData as? [[String: Any]] else {
                    print("Couldn't convert to array data")
                    return
                }
                
                let categories = (try? context.fetch(Category.fetchRequest())) ?? []
                
                for fetchedProd in array {
                    let name = fetchedProd["name"] as? String
                    let quantity = fetchedProd["quantity"] as? Int16
                    let note = fetchedProd["note"] as? String
                    let checkIfExists: NSFetchRequest<Product> = Product.fetchRequest()
                    //todo: improve upon this. ideally, we'd store some ids, but
                    //coredata doesnt seem to have an autoincrement option?
                    checkIfExists.predicate = NSPredicate(format: "productName == %@ AND quantity == %@ AND note == %@", name!, NSNumber(value: quantity!), note!)
                    
                    let exists = try context.fetch(checkIfExists).first != nil
                    if exists {
                        print("Product \(name!) with quantity \(quantity!) already exists")
                        continue
                    }
                    
                    let bought = fetchedProd["isBought"] as? Bool
                    let categoryString = fetchedProd["category"] as? String
                
                    guard let categoryMatch = categories.first(where: { category in
                        category.categoryName == categoryString
                    }) else {
                        print("Couldn't match \(String(describing: categoryString)) to any categories. Skipping.")
                        continue
                    }
                    
                    let product = Product(context: context)
                    product.productName = name
                    product.quantity = quantity!
                    product.note = note
                    product.isBought = bought!
                    product.relationship = categoryMatch
                    
                    print("Adding product \(name!) with quantity \(quantity!)")

                   // let category = Category(context: context)
                   // category.categoryName = name!
                }
                
                if context.hasChanges {
                    do {
                        try context.save()
                    } catch {
                        let nsError = error as NSError
                        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                    }
                }
                dispatch.leave()
                
            } catch {
                print("Error: \(error))")
                dispatch.leave()
                return
            }
            
        })
        
        dispatch.enter()
        task.resume()
        dispatch.wait()
        print("Fetching products has finished")
    }

    
    func fetchCategories() {
        let context = persistenceController.container.viewContext
        let config = URLSessionConfiguration.default
        let finalURL = apiURL + "auth/categories"
        
        var request = URLRequest(url: URL(string: finalURL)!)
        
        if let token = tokenStorage.getToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("No token")
            return
        }
        
        let session = URLSession(configuration: config)
        let dispatch = DispatchGroup()
        
        let task = session.dataTask(with: request, completionHandler: {(data, response, err) in
            guard err == nil else {
                print("Error: \(err)")
                dispatch.leave()
                return
            }
            
            guard data != nil else {
                print("Query returns no data.")
                dispatch.leave()
                return
            }
            
            do {
                let readableData = try JSONSerialization.jsonObject(with: data!)
                
                guard let array = readableData as? [[String: Any]] else {
                    print("Couldn't convert to array data")
                    return
                }
            
                
                for fetchedCat in array {
                    let name = fetchedCat["name"] as? String
                    let checkIfExists: NSFetchRequest<Category> = Category.fetchRequest()
                    checkIfExists.predicate = NSPredicate(format: "categoryName == %@", name!)
                    
                    let exists = try context.fetch(checkIfExists).first != nil
                    if exists {
                        print("Category \(name!) already exists")
                        continue
                    }

                    let category = Category(context: context)
                    category.categoryName = name!
                }
                
                if context.hasChanges {
                    do {
                        try context.save()
                    } catch {
                        let nsError = error as NSError
                        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                    }
                }
                dispatch.leave()
                
            } catch {
                print("Error: \(error)")
                dispatch.leave()
                return
            }
            
        })
        
        dispatch.enter()
        task.resume()
        dispatch.wait()
        print("Fetching categories has finished")
    }
    
    let persistenceController = PersistenceController.shared

    init() {
        _isAuthorized = State(initialValue: credentialsCheck())
        if isAuthorized {
            fetchCategories()
            fetchProducts()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthorized {
                    ContentView()
                } else {
                    LoginOrRegisterView(apiURL: apiURL)
                }
            }
            .environmentObject(tokenStorage)
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
