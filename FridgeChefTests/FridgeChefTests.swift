//
//  FridgeChefTests.swift
//  FridgeChefTests
//

import Foundation
import Testing
@testable import FridgeChef

@MainActor
struct ExpiryStatusTests {

    @Test(arguments: [
        (-1, ExpiryStatus.expired(days: 1)),
        (0, .today),
        (1, .tomorrow),
        (2, .soon(days: 2)),
        (3, .ok(days: 3)),
    ])
    func fridgeStatus(daysLeft: Int, expected: ExpiryStatus) {
        #expect(ExpiryStatus(storage: .fridge, daysLeft: daysLeft) == expected)
    }

    @Test func frozenIgnoresDays() {
        #expect(ExpiryStatus(storage: .freezer, daysLeft: nil) == .frozen)
        #expect(ExpiryStatus(storage: .freezer, daysLeft: -5) == .frozen)
    }

    @Test func urgency() {
        #expect(ExpiryStatus.expired(days: 1).isUrgent)
        #expect(!ExpiryStatus.expired(days: 1).isSoon)
        #expect(ExpiryStatus.today.isSoon)
        #expect(ExpiryStatus.soon(days: 2).isUrgent)
        #expect(!ExpiryStatus.ok(days: 3).isUrgent)
        #expect(!ExpiryStatus.frozen.isUrgent)
    }
}

@MainActor
struct ShelfLifePresetTests {

    @Test func nameMatchIsTrimmedAndCaseInsensitive() {
        #expect(ShelfLifePreset.source(name: " Tomato\n", category: .vegetable) == .name(days: 7))
        #expect(ShelfLifePreset.source(name: "鸡蛋", category: .eggDairy) == .name(days: 21))
    }

    @Test(arguments: [
        (FoodCategory.meat, 3), (.semiPrepared, 5), (.vegetable, 5), (.eggDairy, 7),
    ])
    func categoryDefaults(category: FoodCategory, days: Int) {
        #expect(ShelfLifePreset.source(name: "未知食材", category: category) == .category(days: days))
    }

    @Test func frozenHasNoExpiry() {
        #expect(ShelfLifePreset.expiryDate(
            name: "牛肉", category: .meat, storage: .freezer, startDate: .now) == nil)
    }

    @Test func foodItemComputesExpiryWhenOmitted() {
        let start = Calendar.current.startOfDay(for: .now)
        let item = FoodItem(name: "鸡胸肉", category: .meat, storage: .fridge, unit: .piece, addedDate: start)
        #expect(item.daysLeft == 3)
        #expect(item.expiryStatus == .ok(days: 3))

        let frozen = FoodItem(name: "五花肉", category: .meat, storage: .freezer, unit: .piece)
        #expect(frozen.expiryDate == nil)
        #expect(frozen.expiryStatus == .frozen)
    }
}

@MainActor
struct QuantityUnitTests {
    @Test func amountTextUsesSingularOnlyForExactlyOne() {
        let en = Locale(identifier: "en")
        func text(_ unit: QuantityUnit, _ amount: Double) -> String {
            let name = amount == 1 ? unit.displayName : unit.pluralName
            var resource = name
            resource.locale = en
            return "\(amount.formatted()) \(String(localized: resource))"
        }
        #expect(text(.piece, 1) == "1 piece")
        #expect(text(.piece, 2) == "2 pieces")
        #expect(text(.box, 0.5) == "0.5 boxes")
        #expect(QuantityUnit.bunch.amountText(1).hasPrefix("1 "))
    }
}
