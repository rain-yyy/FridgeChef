import Foundation

/// One fridge item on the "confirm deduction" sheet.
struct DeductionRow: Identifiable, Equatable {
    /// Items left with less than this after deducting are removed from the fridge.
    static let removalThreshold = 0.25
    static let step = 0.5

    let itemID: UUID
    let name: String
    let unit: QuantityUnit
    /// What is in the fridge now.
    let available: Double
    /// How much to deduct (0.5 steps, between 0.5 and `available`).
    private(set) var amount: Double
    var isOn = true

    var id: UUID { itemID }

    init(itemID: UUID, name: String, unit: QuantityUnit, available: Double, amount: Double) {
        self.itemID = itemID
        self.name = name
        self.unit = unit
        self.available = available
        self.amount = min(max(amount, Self.step), available)
    }

    var remaining: Double { max(available - amount, 0) }
    var willRemove: Bool { isOn && remaining < Self.removalThreshold }
    var canIncrease: Bool { amount < available }
    var canDecrease: Bool { amount > min(Self.step, available) }

    mutating func increase() { amount = min(amount + Self.step, available) }
    mutating func decrease() { amount = max(amount - Self.step, min(Self.step, available)) }
}

enum Deduction {
    struct Summary: Equatable {
        var deducted: Int
        var removed: Int
    }

    /// What happens to one item: a new quantity, or nil to remove it.
    struct Change: Equatable {
        let itemID: UUID
        let newQuantity: Double?
    }

    /// Rows for a plan: its ingredients merged per item, matched to what is in the fridge now.
    /// Items deleted since the menu was generated are skipped; names and units come from the current item.
    static func rows(for plan: MenuPlan, items: [FoodItem]) -> [DeductionRow] {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return plan.totalIngredients.compactMap { ingredient in
            guard let item = byID[ingredient.itemID], item.quantity > 0 else { return nil }
            return DeductionRow(
                itemID: item.id, name: item.name, unit: item.unit,
                available: item.quantity, amount: ingredient.amount)
        }
    }

    static func changes(for rows: [DeductionRow]) -> [Change] {
        rows.filter(\.isOn).map { row in
            Change(itemID: row.itemID, newQuantity: row.willRemove ? nil : row.remaining)
        }
    }

    static func summary(of rows: [DeductionRow]) -> Summary {
        Summary(deducted: rows.filter(\.isOn).count, removed: rows.filter(\.willRemove).count)
    }

    /// Updates quantities and removes used-up items. Returns what was done.
    @discardableResult
    static func apply(_ rows: [DeductionRow], to items: [FoodItem], remove: (FoodItem) -> Void) -> Summary {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for change in changes(for: rows) {
            guard let item = byID[change.itemID] else { continue }
            if let quantity = change.newQuantity {
                item.quantity = quantity
            } else {
                remove(item)
            }
        }
        return summary(of: rows)
    }
}
