import Foundation

enum Cuisine: String, Codable, CaseIterable, Identifiable {
    case chinese
    case western

    var id: Self { self }

    var displayName: LocalizedStringResource {
        switch self {
        case .chinese: "cuisine.chinese"
        case .western: "cuisine.western"
        }
    }
}

/// One AI menu generation, saved so it survives tab switches and app restarts.
struct MenuResult: Codable, Equatable {
    var cuisine: Cuisine
    var servings: Int
    var createdAt: Date
    /// 2–3 plans, sorted by how many use-soon ingredients they use.
    var plans: [MenuPlan]
}

/// A complete meal option: one or more dishes.
struct MenuPlan: Codable, Equatable, Identifiable {
    var id = UUID()
    var minutes: Int?
    /// E.g. a reminder to thaw a frozen ingredient.
    var note: String?
    var dishes: [Dish]

    /// Distinct use-soon fridge items this plan uses.
    var soonItemCount: Int {
        Set(dishes.flatMap(\.ingredients).filter(\.wasSoon).map(\.itemID)).count
    }

    /// The plan's ingredients merged per fridge item, in first-use order.
    var totalIngredients: [DishIngredient] {
        var order: [UUID] = []
        var merged: [UUID: DishIngredient] = [:]
        for ingredient in dishes.flatMap(\.ingredients) {
            if var existing = merged[ingredient.itemID] {
                existing.amount += ingredient.amount
                merged[ingredient.itemID] = existing
            } else {
                order.append(ingredient.itemID)
                merged[ingredient.itemID] = ingredient
            }
        }
        return order.compactMap { merged[$0] }
    }
}

struct Dish: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var ingredients: [DishIngredient]
    /// Seasonings and other things not tracked in the fridge ("需另备").
    var extras: [String]
    var steps: [String]
}

/// An amount of one fridge item. Name, unit and use-soon state are snapshotted at generation time
/// so the plan still reads correctly if the item is later edited or removed.
struct DishIngredient: Codable, Equatable {
    var itemID: UUID
    var name: String
    var unit: QuantityUnit
    var amount: Double
    var wasSoon: Bool

    var amountText: String {
        unit.amountText(amount)
    }
}
