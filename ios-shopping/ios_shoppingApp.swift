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
    let apiURL = "http://74.91.113.214:800/"
    
    func fetchCategories(url: String) { //returns true if at least one category was inserted
        let context = persistenceController.container.viewContext
        let config = URLSessionConfiguration.default
        let finalURL = url + "categories"
        
        let request = URLRequest(url: URL(string: finalURL)!)
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
                print("Error: \(error))")
                dispatch.leave()
                return
            }
            
        })
        
        dispatch.enter()
        task.resume()
        dispatch.wait()
        print("DONE")
    }
    
    let persistenceController = PersistenceController.shared

    init() {
        fetchCategories(url: apiURL)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
