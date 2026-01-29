//
//  ServerCalls.swift
//  ios-shopping
//
//  Created by user279407 on 1/29/26.
//

import CoreData

func syncProductsToServer(
    context: NSManagedObjectContext,
    apiURL: String,
    token: String
) -> String {

    let req: NSFetchRequest<Product> = Product.fetchRequest()
    let allProducts: [Product]
    do {
        allProducts = try context.fetch(req)
    } catch {
        return "Local fetch failed."
    }

    var productsJSON: [[String: Any]] = []
    for p in allProducts {
        let catName = p.relationship?.categoryName ?? ""
        productsJSON.append([
            "name": p.productName ?? "",
            "quantity": Int(p.quantity),
            "note": p.note ?? "",
            "isBought": p.isBought,
            "category": catName,
            "isPaid": p.isPaid,
            "price": p.price
        ])
    }

    let finalURL = apiURL + "auth/products"
    var request = URLRequest(url: URL(string: finalURL)!)
    request.httpMethod = "PUT"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let body: [String: Any] = ["products": productsJSON]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    let session = URLSession(configuration: .default)
    let dispatch = DispatchGroup()

    var statusCode: Int?
    var responseData: Data?

    dispatch.enter()
    session.dataTask(with: request) { data, response, err in
        if err != nil {
            dispatch.leave()
            return
        }
        responseData = data
        statusCode = (response as? HTTPURLResponse)?.statusCode
        dispatch.leave()
    }.resume()

    dispatch.wait()

    guard let code = statusCode else {
        return "No server response."
    }

    if code == 200 || code == 201 {
        return "Synced."
    }

    if let data = responseData,
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let msg = obj["message"] as? String {
        return "Server: \(msg) (\(code))"
    }

    return "Sync failed (\(code))"
}

func productsFromJSON(
    context: NSManagedObjectContext,
    array: [[String: Any]]
) {
    
    let existing: [Product]
     do {
         existing = try context.fetch(Product.fetchRequest())
     } catch {
         print("Fetch local products failed")
         return
     }

     for p in existing {
         //this is obviously not ideal, but we dont really have a reliable way of matching a fetched products with local products
         //since theres no id.
         context.delete(p)
     }
    
    let categories = (try? context.fetch(Category.fetchRequest())) ?? []
    
    do {
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
            let price = fetchedProd["price"] as? Double
            let paid = fetchedProd["isPaid"] as? Bool
            
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
            product.isPaid = paid!
            product.price = price!
            
            print("Adding product \(name!) with quantity \(quantity!)")
        }
    } catch {
        print("Error: \(error)")
        return
    }
    
    if context.hasChanges {
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

func fetchProducts(
    context: NSManagedObjectContext,
    apiURL: String,
    token: String
) {
    let config = URLSessionConfiguration.default
    let finalURL = apiURL + "auth/products"
    
    var request = URLRequest(url: URL(string: finalURL)!)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
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
            
            productsFromJSON(context: context, array: array)
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


func fetchCategories(
    context: NSManagedObjectContext,
    apiURL: String,
    token: String
) {
    let config = URLSessionConfiguration.default
    let finalURL = apiURL + "auth/categories"
    
    var request = URLRequest(url: URL(string: finalURL)!)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
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
