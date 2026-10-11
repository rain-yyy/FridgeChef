import Foundation
import SwiftData

@Model
final class FoodItem {
    /// Stable identity; saved menu plans refer to items by it.
    var id: UUID = UUID()
    var name: String
    // Stored as raw strings: enums are unreliable inside #Predicate.
    var categoryRaw: String
    var storageRaw: String
    var unitRaw: String
    var quantity: Double
    var addedDate: Date
    var expiryDate: Date?

    var category: FoodCategory {
        get { FoodCategory(rawValue: categoryRaw) ?? .vegetable }
        set { categoryRaw = newValue.rawValue }
    }

    var storage: StorageLocation {
        get { StorageLocation(rawValue: storageRaw) ?? .fridge }
        set { storageRaw = newValue.rawValue }
    }

    var unit: QuantityUnit {
        get { QuantityUnit(rawValue: unitRaw) ?? .item }
        set { unitRaw = newValue.rawValue }
    }

    var expiryStatus: ExpiryStatus {
        ExpiryStatus(storage: storage, daysLeft: daysLeft)
    }

    /// Whole days until expiry (negative if expired); nil when there is no expiry date.
    var daysLeft: Int? {
        guard let expiryDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let expiry = calendar.startOfDay(for: expiryDate)
        return calendar.dateComponents([.day], from: today, to: expiry).day
    }

    init(
        name: String,
        category: FoodCategory,
        storage: StorageLocation,
        unit: QuantityUnit,
        quantity: Double = 1,
        addedDate: Date = .now,
        expiryDate: Date? = nil
    ) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.storageRaw = storage.rawValue
        self.unitRaw = unit.rawValue
        self.quantity = quantity
        self.addedDate = addedDate
        self.expiryDate = expiryDate ?? ShelfLifePreset.expiryDate(
            name: name, category: category, storage: storage, startDate: addedDate)
    }
}
