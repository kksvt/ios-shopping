//
//  ios_shoppingTests.swift
//  ios-shoppingTests
//
//  Created by user279407 on 1/29/26.
//

import Foundation
import Testing

//make sure to run the entire test suite, as they depend on the globalToken
struct ios_shoppingTests {

    let apiURL = "http://74.91.113.214:800/"
    let email = "user@email.com"
    let pwd = "passwordypassword"
    
    static var globalToken: String?
    
    private func sendRequestAndGetJSON(
        method: String,
        url: String,
        token: String? = nil,
        body: [String: Any]? = nil
    ) async -> (code: Int?, dict: [String: Any]?, array: [[String: Any]]?, raw: Data?) {

        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method

        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode

            var dict: [String: Any]?
            var array: [[String: Any]]?

            let any = try? JSONSerialization.jsonObject(with: data)
            if let d = any as? [String: Any] { dict = d }
            if let a = any as? [[String: Any]] { array = a }

            return (code, dict, array, data)
        } catch {
            return (nil, nil, nil, nil)
        }
    }

    private func registerFreshUser() async -> (
        email: String, pwd: String, token: String, code:
            Int?, dict: [String: Any]?, array: [[String: Any]]?, raw: Data?) {
        let email = "user@email.com"
        let pwd = "passwordypassword"

        let res = await sendRequestAndGetJSON(
            method: "POST",
            url: apiURL + "register",
            body: ["email": email, "pwd": pwd]
        )

        let token = (res.dict?["token"] as? String) ?? ""
        
        ios_shoppingTests.globalToken = token
                
        return (email, pwd, token, res.code, res.dict, res.array, res.raw)
    }
    
    @Test func test00_clearServerDb() async {
        let response = await sendRequestAndGetJSON(method: "DELETE", url: apiURL + "test/wipe")
        #expect(response.code == 201)
    }

    @Test func test01_registerUserAndCheckAuth() async {
        let userData = await registerFreshUser()
        
        #expect(userData.code == 201)
        #expect(userData.dict != nil)

        #expect(!userData.token.isEmpty)
        #expect(userData.token.split(separator: ".").count == 3)
        
        let authCheck = await sendRequestAndGetJSON(method: "GET", url: apiURL + "auth/check", token: ios_shoppingTests.globalToken)
        
        #expect(authCheck.code == 200)
        #expect((authCheck.dict?["message"] as? String) == "ok")
    }

    @Test func test02_loginAndGetProductsAndCategories() async {

        let login = await sendRequestAndGetJSON(
            method: "POST",
            url: apiURL + "login",
            body: ["email": email, "pwd": pwd]
        )

        #expect(login.code == 201)
        #expect(login.dict != nil)

        let token = (login.dict?["token"] as? String) ?? ""
        #expect(!token.isEmpty)

        let products = login.dict?["products"] as? [[String: Any]]
        #expect(products != nil)

        let categories = login.dict?["categories"] as? [[String: Any]]
        #expect(categories != nil)

        #expect((products?.count ?? 0) > 0)
        #expect((categories?.count ?? 0) > 0)
    }

    @Test func test03_productFields() async {
        let products = await sendRequestAndGetJSON(method: "GET", url: apiURL + "auth/products", token: ios_shoppingTests.globalToken)

        #expect(products.code == 200)
        #expect(products.array != nil)

        let firstProduct = products.array?.first

        #expect(firstProduct?["price"] != nil)
        #expect(firstProduct?["isPaid"] != nil)
        #expect((firstProduct?["name"] as? String) != nil)
        #expect((firstProduct?["category"] as? String) != nil)
    }

    @Test func test04_putProductsAndCheckChanges() async {
        let responseOne = await sendRequestAndGetJSON(method: "GET", url: apiURL + "auth/products", token: ios_shoppingTests.globalToken)
        var products = responseOne.array ?? []
        var firstProduct = products[0]

        let name = (firstProduct["name"] as? String) ?? ""
        let category = (firstProduct["category"] as? String) ?? ""

        firstProduct["isPaid"] = true
        firstProduct["isBought"] = true
        firstProduct["quantity"] = 1337

        products[0] = firstProduct

        let put = await sendRequestAndGetJSON(
            method: "PUT",
            url: apiURL + "auth/products",
            token: ios_shoppingTests.globalToken,
            body: ["products": products]
        )

        let responseTwo = await sendRequestAndGetJSON(method: "GET", url: apiURL + "auth/products", token: ios_shoppingTests.globalToken)
        let match = responseTwo.array?.first(where: {
            (($0["name"] as? String) ?? "") == name &&
            (($0["category"] as? String) ?? "") == category
        })

        #expect(responseOne.code == 200)
        #expect((responseOne.array?.count ?? 0) > 0)
        #expect(put.code == 201)
        #expect(responseTwo.code == 200)
        #expect(match != nil)
        #expect((match?["isBought"] as? Bool) == true)
        #expect((match?["isPaid"] as? Bool) == false) //the quantity changes - the server should force isPaid to false
        #expect((match?["quantity"] as? Int) == 1337)
    }

    @Test func test05_payment() async {
        let responseOne = await sendRequestAndGetJSON(method: "GET", url: apiURL + "auth/products", token: ios_shoppingTests.globalToken)
        
        #expect(responseOne.code == 200)
        #expect((responseOne.array?.count ?? 0) > 0)
        
        var products = responseOne.array ?? []
        
        for i in products.indices {
            if i > 1 {
                products[i]["isPaid"] = true
            } else {
                products[i]["isBought"] = true
                products[i]["isPaid"] = false
                products[i]["price"] = 101.0
                products[i]["quantity"] = 7331
            }
        }

        let put = await sendRequestAndGetJSON(
            method: "PUT",
            url: apiURL + "auth/products",
            token: ios_shoppingTests.globalToken,
            body: ["products": products]
        )
        
        #expect(put.code == 201)
        
        let responseOneAndAHalf = await sendRequestAndGetJSON(method: "GET", url: apiURL + "auth/products", token: ios_shoppingTests.globalToken)
        
        #expect(responseOneAndAHalf.code == 200)
        #expect((responseOneAndAHalf.array?.count ?? 0) > 0)
        
        for i in products.indices {
            if i > 1 {
                #expect((products[i]["isPaid"] as? Bool ?? false) == true)
            } else {
                #expect((products[i]["isPaid"] as? Bool ?? false) == false)
            }
        }
        
        products = responseOne.array ?? []

        let responseGetPay = await sendRequestAndGetJSON(method: "GET", url: apiURL + "auth/pay", token: ios_shoppingTests.globalToken)
        
        #expect(responseGetPay.code == 200)
        
        let remainingCost = ((responseGetPay.dict?["remaining"] as? Double) ?? 0)
        let halfExpectedCost = 101.0 * 7331.0
        let expectedCost = halfExpectedCost * 2.0
        
        #expect(remainingCost == expectedCost)
        
        let pay = await sendRequestAndGetJSON(
            method: "POST",
            url: apiURL + "auth/pay",
            token: ios_shoppingTests.globalToken,
            body: ["amount": halfExpectedCost, "card_id": "1111"]
        )
        
        #expect(pay.code == 200)

        let responseTwo = await sendRequestAndGetJSON(method: "GET", url: apiURL + "auth/pay", token: ios_shoppingTests.globalToken)
        let remainingCostTwo = ((responseTwo.dict?["remaining"] as? Double) ?? 0)

        #expect(remainingCostTwo < remainingCost)
        #expect(remainingCostTwo == halfExpectedCost)
    }
}
