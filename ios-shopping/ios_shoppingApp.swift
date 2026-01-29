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
    
    let persistenceController = PersistenceController.shared

    init() {
        _isAuthorized = State(initialValue: credentialsCheck())
        if isAuthorized {
            let context = persistenceController.container.viewContext
            if let token = tokenStorage.getToken(), !token.isEmpty {
                fetchCategories(context: context, apiURL: apiURL, token: token)
                fetchProducts(context: context, apiURL: apiURL, token: token)
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthorized {
                    ContentView(apiURL: apiURL)
                } else {
                    LoginOrRegisterView(apiURL: apiURL)
                }
            }
            .environmentObject(tokenStorage)
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
