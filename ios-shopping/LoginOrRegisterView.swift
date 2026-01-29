//
//  LoginOrRegisterView.swift
//  ios-shopping
//
//  Created by user279407 on 12/31/25.
//

import SwiftUI

struct LoginOrRegisterView: View {
    @EnvironmentObject private var tokenStorage: TokenStorage
    
    let apiURL: String
    
    @State private var email: String = ""
    @State private var pwd: String = ""
    
    @State private var isRegister: Bool = false
    @State private var srvMessage: String = ""
    
    @State private var gotoContent: Bool = false
    
    func submit() {
        srvMessage = ""
        
        var finalURL = apiURL
        if isRegister {
            finalURL += "register"
        } else {
            finalURL += "login"
        }
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)

        var request = URLRequest(url: URL(string: finalURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": email,
            "pwd": pwd
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            srvMessage = "Couldn't encode JSON."
            return
        }

        let dispatch = DispatchGroup()

        var statusCode: Int?
        var responseData: Data?
        var networkError: Error?

        dispatch.enter()
        let task = session.dataTask(with: request) { data, response, err in
            defer { dispatch.leave() }

            networkError = err
            responseData = data
            statusCode = (response as? HTTPURLResponse)?.statusCode
        }

        task.resume()
        dispatch.wait()

        if let networkError {
            srvMessage = "Network error: \(networkError)"
            return
        }

        guard let code = statusCode else {
            srvMessage = "No HTTP response."
            return
        }

        guard let data = responseData else {
            srvMessage = "No data."
            return
        }

        if code != 200 && code != 201 {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["message"] as? String {
                srvMessage = "Server: \(msg) (\(code))"
            } else {
                srvMessage = "Request failed (\(code))."
            }
            return
        }

        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let token = obj["token"] as? String,
            !token.isEmpty
        else {
            srvMessage = "Couldn't parse token."
            return
        }

        tokenStorage.setToken(token: token)
        srvMessage = "Success."
        
        if let token = tokenStorage.getToken(), !token.isEmpty {
            let context = PersistenceController.shared.container.viewContext
            fetchCategories(context: context, apiURL: apiURL, token: token)
            fetchProducts(context: context, apiURL: apiURL, token: token)
        }
        
        gotoContent = true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Mode") {
                    Toggle("Register", isOn: $isRegister)
                }

                Section("Credentials") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)

                    SecureField("Password", text: $pwd)
                }

                if srvMessage != "" {
                    Section("Status") {
                        Text(srvMessage)
                    }
                }

                Section {
                    Button(isRegister ? "Register" : "Login") {
                        submit()
                    }
                    .font(.headline)
                    .disabled(email.isEmpty || pwd.isEmpty)

                    if tokenStorage.getToken() != nil {
                        Button("Clear stored token") {
                            tokenStorage.logout()
                            srvMessage = "Token cleared."
                        }
                    }
                }
            }
            .navigationTitle(isRegister ? "Register" : "Login")
            .navigationDestination(isPresented: $gotoContent) {
                ContentView(apiURL: apiURL)
            }
        }
    }
}
#Preview {
    LoginOrRegisterView(apiURL:"localhost")
        .environmentObject(TokenStorage())
}
