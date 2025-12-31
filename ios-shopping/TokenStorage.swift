//
//  TokenStorage.swift
//  ios-shopping
//
//  Created by user279407 on 12/31/25.
//

import Foundation
import SwiftUI

@MainActor
final class TokenStorage: ObservableObject {
    @Published var token: String?

    init() {
        token = UserDefaults.standard.string(forKey: "authToken")
    }

    func getToken() -> String? {
        return token;
    }

    func setToken(token: String) {
        self.token = token
        UserDefaults.standard.set(token, forKey: "authToken")
    }

    func logout() {
        token = nil
        UserDefaults.standard.removeObject(forKey: "authToken")
    }
}
