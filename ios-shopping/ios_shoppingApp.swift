//
//  ios_shoppingApp.swift
//  ios-shopping
//
//  Created by user279407 on 12/11/25.
//

import SwiftUI

@main
struct ios_shoppingApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
