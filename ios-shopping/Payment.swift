//
//  Payment.swift
//  ios-shopping
//
//  Created by user279407 on 1/29/26.
//

import SwiftUI

struct PaymentView: View {
    @EnvironmentObject private var tokenStorage: TokenStorage
    @Environment(\.managedObjectContext) private var viewContext
    
    let apiURL: String
    let defaultAmount: Double

    @State private var cardNumber: String
    @State private var amountText: String
    @State private var srvMessage: String

    init(apiURL: String, defaultAmount: Double) {
        self.apiURL = apiURL //init is now explicit (as we have to initialize amountText)
        self.defaultAmount = defaultAmount
        _amountText = State(initialValue: String(format: "%.2f", defaultAmount))
        _cardNumber = State(initialValue: "")
        _srvMessage = State(initialValue: "")
    }

    func pay() {
        srvMessage = ""

        guard let token = tokenStorage.getToken(), !token.isEmpty else {
            srvMessage = "No token."
            return
        }

        guard let amount = Double(amountText), amount > 0 else {
            srvMessage = "Invalid amount."
            return
        }

        let finalURL = apiURL + "auth/pay"
        var request = URLRequest(url: URL(string: finalURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "amount": amount,
            "card_id": cardNumber
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let dispatch = DispatchGroup()
        let session = URLSession(configuration: .default)

        var statusCode: Int?
        var responseData: Data?
        var networkError: Error?

        let task = session.dataTask(with: request) { data, response, err in
            if err != nil {
                networkError = err
                dispatch.leave()
                return
            }

            responseData = data
            statusCode = (response as? HTTPURLResponse)?.statusCode
            dispatch.leave()
        }

        dispatch.enter()
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

        if code == 200 {
            srvMessage = "Ok."
            return
        }

        if let data = responseData,
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let msg = obj["message"] as? String {
            srvMessage = "Server: \(msg) (\(code))"
        } else {
            srvMessage = "Payment failed (\(code))."
        }
    }

    var body: some View {
        Form {
            Section("Card") {
                TextField("Card number: ", text: $cardNumber)
                    .keyboardType(.numberPad)
            }

            Section("Amount") {
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
            }

            if !srvMessage.isEmpty {
                Section("Status") {
                    Text(srvMessage)
                }
            }

            Section {
                Button("Pay") {
                    pay()
                }
                .font(.headline)
                .disabled(cardNumber.count < 4 || amountText.isEmpty)
            }
        }
        .navigationTitle("Payment")
    }
}
