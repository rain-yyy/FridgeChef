//
//  MenuTests.swift
//  FridgeChefTests
//

import Foundation
import Testing
@testable import FridgeChef

@MainActor
private func candidate(_ ref: String, _ name: String, quantity: Double = 2, soon: Bool = false) -> MenuPrompt.Candidate {
    MenuPrompt.Candidate(
        ref: ref, itemID: UUID(), name: name, quantity: quantity, unit: .item,
        storage: .fridge, daysLeft: soon ? 1 : 5, isSoon: soon)
}

@MainActor
struct MenuPromptTests {
    let candidates = [
        candidate("i1", "西红柿", soon: true), candidate("i2", "鸡蛋", quantity: 6), candidate("i3", "豆腐", quantity: 0.5),
    ]

    private func json(_ plans: String) -> String { #"{"plans":[\#(plans)]}"# }
    private let planA = #"{"minutes":15,"note":null,"dishes":[{"name":"番茄炒蛋","ingredients":[{"ref":"i1","amount":1},{"ref":"i2","amount":3}],"extras":["盐"],"steps":["炒"]}]}"#
    private let planB = #"{"minutes":10,"note":null,"dishes":[{"name":"豆腐汤","ingredients":[{"ref":"i3","amount":1}],"extras":[],"steps":["煮"]}]}"#

    @Test func candidatesSkipExpiredAndPutUseSoonFirst() {
        let today = Calendar.current.startOfDay(for: .now)
        func day(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: today)! }
        let items = [
            FoodItem(name: "菠菜", category: .vegetable, storage: .fridge, unit: .bunch, addedDate: today, expiryDate: day(4)),
            FoodItem(name: "牛奶", category: .eggDairy, storage: .fridge, unit: .box, addedDate: today, expiryDate: day(-1)),
            FoodItem(name: "五花肉", category: .meat, storage: .freezer, unit: .piece, addedDate: today),
            FoodItem(name: "西红柿", category: .vegetable, storage: .fridge, unit: .head, addedDate: today, expiryDate: day(1)),
        ]
        let result = MenuPrompt.candidates(from: items)
        #expect(result.map(\.name) == ["西红柿", "菠菜", "五花肉"])
        #expect(result.map(\.ref) == ["i1", "i2", "i3"])
        #expect(result.map(\.isSoon) == [true, false, false])
    }

    @Test func parsesAndSortsBySoonItemCount() throws {
        let plans = try MenuPrompt.parse(json("\(planB),\(planA)"), candidates: candidates)
        #expect(plans.map { $0.dishes[0].name } == ["番茄炒蛋", "豆腐汤"])
        #expect(plans[0].soonItemCount == 1)
        #expect(plans[0].dishes[0].ingredients[0].itemID == candidates[0].itemID)
        #expect(plans[0].dishes[0].ingredients[0].wasSoon)
        #expect(plans[0].minutes == 15 && plans[0].note == nil)
    }

    @Test func acceptsCodeFencesAndProse() throws {
        let content = "Here you go:\n```json\n\(json("\(planA),\(planB)"))\n```"
        #expect(try MenuPrompt.parse(content, candidates: candidates).count == 2)
    }

    @Test func dropsUnknownRefsAndRoundsAndCapsAmounts() throws {
        let odd = #"{"minutes":5,"note":"  ","dishes":[{"name":"杂烩","ingredients":[{"ref":"I2","amount":"1.3"},{"ref":"i9","amount":1},{"ref":"i1","amount":0},{"ref":"i3","amount":2}],"extras":["", "油"],"steps":[" 煮 "]}]}"#
        let plans = try MenuPrompt.parse(json("\(odd),\(planB)"), candidates: candidates)
        let dish = try #require(plans.first { $0.dishes[0].name == "杂烩" }).dishes[0]
        #expect(dish.ingredients.map(\.name) == ["鸡蛋", "豆腐"])
        #expect(dish.ingredients.map(\.amount) == [1.5, 0.5])  // 1.3 → 1.5; 2 capped at 0.5 available
        #expect(dish.extras == ["油"] && dish.steps == ["煮"])
        #expect(plans.first { $0.dishes[0].name == "杂烩" }?.note == nil)
    }

    @Test func fewerThanTwoUsablePlansIsABadResponse() {
        let noIngredients = #"{"minutes":5,"note":null,"dishes":[{"name":"空气","ingredients":[{"ref":"i9","amount":1}],"extras":[],"steps":[]}]}"#
        #expect(throws: AIError.badResponse) { try MenuPrompt.parse(json(planA), candidates: candidates) }
        #expect(throws: AIError.badResponse) { try MenuPrompt.parse(json("\(planA),\(noIngredients)"), candidates: candidates) }
        #expect(throws: AIError.badResponse) { try MenuPrompt.parse("sorry, I can't", candidates: candidates) }
    }

    @Test func keepsAtMostThreePlans() throws {
        let plans = try MenuPrompt.parse(json([planA, planB, planA, planB].joined(separator: ",")), candidates: candidates)
        #expect(plans.count == 3)
    }

    @Test func totalIngredientsMergesAcrossDishes() {
        let id = UUID()
        let egg = DishIngredient(itemID: id, name: "鸡蛋", unit: .item, amount: 1, wasSoon: false)
        let plan = MenuPlan(dishes: [
            Dish(name: "a", ingredients: [egg], extras: [], steps: []),
            Dish(name: "b", ingredients: [egg], extras: [], steps: []),
        ])
        #expect(plan.totalIngredients.map(\.amount) == [2])
    }
}

@MainActor
struct AIErrorTests {
    @Test func mapsHTTPStatuses() {
        #expect(AIError.from(status: 401, message: "User not found.") == .invalidKey)
        #expect(AIError.from(status: 402, message: nil) == .insufficientCredits)
        #expect(AIError.from(status: 400, message: "x/y is not a valid model ID") == .modelUnavailable)
        #expect(AIError.from(status: 429, message: nil) == .rateLimited)
        #expect(AIError.from(status: 500, message: "boom") == .server("boom"))
    }
}

/// Serves canned responses to URLSession so the client can be tested offline.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var respond: ((URLRequest) -> Result<(Int, String), URLError>)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        switch Self.respond?(request) ?? .failure(URLError(.unknown)) {
        case .success(let (status, body)):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}

@MainActor
@Suite(.serialized)
struct OpenRouterClientTests {
    private func client() -> OpenRouterClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return OpenRouterClient(apiKey: "test-key", model: "a/b", session: URLSession(configuration: configuration))
    }

    private func result(_ respond: @escaping (URLRequest) -> Result<(Int, String), URLError>) async -> Result<String, AIError> {
        StubURLProtocol.respond = respond
        defer { StubURLProtocol.respond = nil }
        do throws(AIError) {
            return .success(try await client().complete([ChatMessage(role: .user, content: "hi")]))
        } catch {
            return .failure(error)
        }
    }

    @Test func returnsContentAndSendsAuth() async {
        var authorization: String?
        let outcome = await result { request in
            authorization = request.value(forHTTPHeaderField: "Authorization")
            return .success((200, #"{"choices":[{"message":{"content":"{\"plans\":[]}"}}]}"#))
        }
        #expect(outcome == .success(#"{"plans":[]}"#))
        #expect(authorization == "Bearer test-key")
    }

    @Test func mapsFailures() async {
        #expect(await result { _ in .failure(URLError(.notConnectedToInternet)) } == .failure(.network))
        #expect(await result { _ in .success((401, #"{"error":{"message":"User not found.","code":401}}"#)) } == .failure(.invalidKey))
        #expect(await result { _ in .success((200, #"{"error":{"message":"overloaded","code":502}}"#)) } == .failure(.server("overloaded")))
        #expect(await result { _ in .success((200, #"{"choices":[{"message":{"content":null}}]}"#)) } == .failure(.badResponse))
        #expect(await result { _ in .success((200, "not json")) } == .failure(.badResponse))
    }
}

@MainActor
struct MenuStoreTests {
    @Test func savedResultIsLoadedByANewStore() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("menu-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let ingredient = DishIngredient(itemID: UUID(), name: "西红柿", unit: .head, amount: 1.5, wasSoon: true)
        let result = MenuResult(
            cuisine: .western, servings: 3, createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            plans: [MenuPlan(minutes: 20, note: "解冻", dishes: [Dish(name: "汤", ingredients: [ingredient], extras: ["盐"], steps: ["煮"])])])

        MenuStore(fileURL: url).save(result)
        #expect(MenuStore(fileURL: url).result == result)
        #expect(MenuStore(fileURL: nil).result == nil)
    }
}

@MainActor
struct DeductionTests {
    private func row(available: Double, amount: Double) -> DeductionRow {
        DeductionRow(itemID: UUID(), name: "鸡蛋", unit: .item, available: available, amount: amount)
    }

    @Test func amountIsClampedAndSteppedByHalf() {
        var r = row(available: 2, amount: 5)
        #expect(r.amount == 2 && !r.canIncrease)
        r.decrease(); r.decrease(); r.decrease(); r.decrease()
        #expect(r.amount == 0.5 && !r.canDecrease)
        r.increase()
        #expect(r.amount == 1 && r.remaining == 1)

        let small = row(available: 0.3, amount: 1)
        #expect(small.amount == 0.3 && !small.canDecrease && !small.canIncrease)
    }

    @Test func removalThresholdIsAQuarter() {
        #expect(row(available: 1, amount: 1).willRemove)                // 0 left
        #expect(row(available: 0.7, amount: 0.5).willRemove)            // 0.2 left
        #expect(!row(available: 0.75, amount: 0.5).willRemove)          // 0.25 left stays
        var off = row(available: 1, amount: 1)
        off.isOn = false
        #expect(!off.willRemove)
    }

    @Test func rowsMergePlanIngredientsAndSkipMissingItems() {
        let egg = FoodItem(name: "鸡蛋", category: .eggDairy, storage: .fridge, unit: .item, quantity: 6)
        let gone = UUID()
        let plan = MenuPlan(dishes: [
            Dish(name: "a", ingredients: [
                DishIngredient(itemID: egg.id, name: "鸡蛋", unit: .item, amount: 1, wasSoon: false),
                DishIngredient(itemID: gone, name: "已删", unit: .item, amount: 1, wasSoon: false),
            ], extras: [], steps: []),
            Dish(name: "b", ingredients: [
                DishIngredient(itemID: egg.id, name: "鸡蛋", unit: .item, amount: 2, wasSoon: false),
            ], extras: [], steps: []),
        ])
        let rows = Deduction.rows(for: plan, items: [egg])
        #expect(rows.map(\.name) == ["鸡蛋"])
        #expect(rows[0].amount == 3 && rows[0].available == 6)
    }

    @Test func applyUpdatesRemovesAndSkipsUnchecked() {
        let egg = FoodItem(name: "鸡蛋", category: .eggDairy, storage: .fridge, unit: .item, quantity: 6)
        let milk = FoodItem(name: "牛奶", category: .eggDairy, storage: .fridge, unit: .box, quantity: 1)
        let tofu = FoodItem(name: "豆腐", category: .semiPrepared, storage: .fridge, unit: .box, quantity: 1)
        var tofuRow = DeductionRow(itemID: tofu.id, name: "豆腐", unit: .box, available: 1, amount: 1)
        tofuRow.isOn = false
        let rows = [
            DeductionRow(itemID: egg.id, name: "鸡蛋", unit: .item, available: 6, amount: 2),
            DeductionRow(itemID: milk.id, name: "牛奶", unit: .box, available: 1, amount: 1),
            tofuRow,
        ]
        var removed: [String] = []
        let summary = Deduction.apply(rows, to: [egg, milk, tofu]) { removed.append($0.name) }
        #expect(summary == .init(deducted: 2, removed: 1))
        #expect(egg.quantity == 4)
        #expect(removed == ["牛奶"])
        #expect(tofu.quantity == 1)
    }
}
