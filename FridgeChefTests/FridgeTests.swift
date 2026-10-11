//
//  FridgeTests.swift
//  FridgeChefTests
//

import Foundation
import Testing
@testable import FridgeChef

@MainActor
private func item(
    _ name: String, _ category: FoodCategory = .vegetable, _ storage: StorageLocation = .fridge,
    daysLeft: Int? = 5
) -> FoodItem {
    let today = Calendar.current.startOfDay(for: .now)
    let expiry = daysLeft.map { Calendar.current.date(byAdding: .day, value: $0, to: today)! }
    return FoodItem(name: name, category: category, storage: storage, unit: .item, addedDate: today, expiryDate: expiry)
}

@MainActor
struct FridgeSectionsTests {

    private func names(_ section: FridgeSection) -> [String] { section.items.map(\.name) }

    @Test func urgentGroupComesFirstAndHoldsExpiredAndSoonFridgeItems() {
        let items = [
            item("菠菜", daysLeft: 4), item("牛奶", .eggDairy, daysLeft: -1), item("西红柿", daysLeft: 1),
            item("鸡胸肉", .meat, daysLeft: 2), item("五花肉", .meat, .freezer, daysLeft: nil),
        ]
        let sections = FridgeSections.build(items, filter: .all, query: "")
        #expect(sections.map(\.kind) == [.urgent, .category(.meat), .category(.vegetable)])
        #expect(names(sections[0]) == ["牛奶", "西红柿", "鸡胸肉"])
        #expect(names(sections[1]) == ["五花肉"])
    }

    @Test func groupsSortByDaysLeftWithFrozenLast() {
        let items = [
            item("饺子", .semiPrepared, .freezer, daysLeft: nil), item("豆腐", .semiPrepared, daysLeft: 9),
            item("火腿", .semiPrepared, daysLeft: 3),
        ]
        let sections = FridgeSections.build(items, filter: .all, query: "")
        #expect(names(sections[0]) == ["火腿", "豆腐", "饺子"])
    }

    @Test func filterAndSearch() {
        let items = [item("西红柿"), item("番茄酱", .semiPrepared), item("冻西红柿", .vegetable, .freezer, daysLeft: nil)]
        let frozen = FridgeSections.build(items, filter: .freezer, query: "")
        #expect(frozen.flatMap(\.items).map(\.name) == ["冻西红柿"])

        let search = FridgeSections.build(items, filter: .fridge, query: " 西红 ")
        #expect(search.flatMap(\.items).map(\.name) == ["西红柿"])

        #expect(FridgeSections.build(items, filter: .all, query: "牛肉").isEmpty)
    }
}

@MainActor
struct ItemDraftTests {
    private let now = Calendar.current.startOfDay(for: .now)

    private func days(_ draft: ItemDraft, from start: Date) -> Int? {
        draft.expiryDate.map { Calendar.current.dateComponents([.day], from: start, to: $0).day! }
    }

    @Test func newDraftUsesCategoryDefaultAndFollowsCategoryAndName() {
        var draft = ItemDraft(now: now)
        #expect(!draft.canSave)
        #expect(days(draft, from: now) == 5)
        #expect(draft.expiryNote == .auto(.category(days: 5)))

        draft.setCategory(.meat)
        #expect(days(draft, from: now) == 3)

        draft.setName("鸡蛋")
        #expect(days(draft, from: now) == 21)
        #expect(draft.expiryNote == .auto(.name(days: 21)))
        #expect(draft.canSave)
    }

    @Test func handPickedExpirySticksUntilReset() {
        var draft = ItemDraft(now: now)
        let picked = Calendar.current.date(byAdding: .day, value: 10, to: now)!
        draft.setExpiryDate(picked)
        draft.setCategory(.meat)
        #expect(draft.expiryDate == picked)
        #expect(draft.expiryNote == .edited)

        draft.resetExpiry()
        #expect(days(draft, from: now) == 3)
    }

    @Test func freezerHidesExpiryAndAddModeCountsFromAddedDate() {
        var draft = ItemDraft(now: now)
        let added = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        draft.setAddedDate(added)
        draft.setStorage(.freezer)
        #expect(draft.expiryDate == nil)
        #expect(draft.expiryNote == .frozen)

        draft.setStorage(.fridge)
        #expect(days(draft, from: added) == 5)
        #expect(draft.expiryNote == .auto(.category(days: 5)))
    }

    @Test func thawingAnExistingItemCountsFromToday() {
        let frozen = item("五花肉", .meat, .freezer, daysLeft: nil)
        frozen.addedDate = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        var draft = ItemDraft(editing: frozen, now: now)
        draft.setStorage(.fridge)
        #expect(days(draft, from: now) == 3)
        #expect(draft.expiryNote == .thawed(.category(days: 3)))

        draft.apply(to: frozen)
        #expect(frozen.storage == .fridge)
        #expect(frozen.daysLeft == 3)
    }

    @Test func editingDetectsHandPickedExpiry() {
        let preset = item("胡萝卜", daysLeft: 5)
        #expect(ItemDraft(editing: preset, now: now).expiryNote == .auto(.category(days: 5)))

        let custom = item("胡萝卜", daysLeft: 12)
        #expect(ItemDraft(editing: custom, now: now).expiryNote == .edited)
    }

    @Test func prepareNextItemKeepsCategoryStorageAndUnit() {
        var draft = ItemDraft(now: now)
        draft.setName("牛排")
        draft.setCategory(.meat)
        draft.setStorage(.freezer)
        draft.unit = .piece
        draft.quantity = 3
        draft.prepareNextItem()
        #expect(draft.name.isEmpty)
        #expect(draft.quantity == 1)
        #expect(draft.category == .meat && draft.storage == .freezer && draft.unit == .piece)
        #expect(draft.expiryDate == nil)
    }

    @Test func savedNameIsTrimmed() {
        var draft = ItemDraft(now: now)
        draft.setName("  西红柿\n")
        #expect(draft.makeItem().name == "西红柿")
    }
}
