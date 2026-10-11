import Foundation

/// Editable copy of a FoodItem for the add / edit sheet, applying the design spec's expiry rules:
/// - fridge items get an expiry date from the shelf-life preset, recalculated when name, category
///   or added date change, until the user picks a date by hand;
/// - frozen items have no expiry date;
/// - when an existing item moves from freezer to fridge, the expiry is counted from today.
struct ItemDraft {
    /// What the footer under the dates explains.
    enum ExpiryNote: Equatable {
        case frozen
        case edited
        case auto(ShelfLifePreset.Source)
        case thawed(ShelfLifePreset.Source)
    }

    let isEditing: Bool
    /// "Today" for thaw recalculation; injectable for tests.
    let now: Date

    private(set) var name: String
    private(set) var category: FoodCategory
    private(set) var storage: StorageLocation
    var unit: QuantityUnit
    var quantity: Double
    private(set) var addedDate: Date
    private(set) var expiryDate: Date?
    private(set) var expiryEdited = false
    private(set) var thawed = false

    /// A blank draft for adding an item.
    init(now: Date = .now) {
        self.isEditing = false
        self.now = now
        name = ""
        category = .vegetable
        storage = .fridge
        unit = .head
        quantity = 1
        addedDate = now
        recalculateExpiry()
    }

    /// A draft of an existing item. A stored expiry that differs from the preset counts as hand-picked.
    init(editing item: FoodItem, now: Date = .now) {
        self.isEditing = true
        self.now = now
        name = item.name
        category = item.category
        storage = item.storage
        unit = item.unit
        quantity = item.quantity
        addedDate = item.addedDate
        expiryDate = item.expiryDate
        if storage == .fridge, let expiryDate {
            expiryEdited = !Self.sameDay(expiryDate, presetExpiry)
        }
    }

    var canSave: Bool { !trimmedName.isEmpty }

    var source: ShelfLifePreset.Source {
        ShelfLifePreset.source(name: name, category: category)
    }

    var expiryNote: ExpiryNote {
        if storage == .freezer { return .frozen }
        if expiryEdited { return .edited }
        return thawed ? .thawed(source) : .auto(source)
    }

    mutating func setName(_ newValue: String) {
        name = newValue
        recalculateExpiry()
    }

    mutating func setCategory(_ newValue: FoodCategory) {
        category = newValue
        recalculateExpiry()
    }

    mutating func setAddedDate(_ newValue: Date) {
        addedDate = newValue
        recalculateExpiry()
    }

    mutating func setStorage(_ newValue: StorageLocation) {
        guard newValue != storage else { return }
        storage = newValue
        if newValue == .freezer {
            expiryDate = nil
        } else {
            thawed = isEditing
            expiryEdited = false
            recalculateExpiry()
        }
    }

    mutating func setExpiryDate(_ newValue: Date) {
        expiryDate = newValue
        expiryEdited = true
    }

    mutating func resetExpiry() {
        expiryEdited = false
        recalculateExpiry()
    }

    /// After "save and add another": keep category, storage and unit; clear the rest.
    mutating func prepareNextItem() {
        name = ""
        quantity = 1
        addedDate = now
        expiryEdited = false
        thawed = false
        recalculateExpiry()
    }

    func makeItem() -> FoodItem {
        FoodItem(
            name: trimmedName, category: category, storage: storage, unit: unit,
            quantity: quantity, addedDate: addedDate, expiryDate: expiryDate)
    }

    func apply(to item: FoodItem) {
        item.name = trimmedName
        item.category = category
        item.storage = storage
        item.unit = unit
        item.quantity = quantity
        item.addedDate = addedDate
        item.expiryDate = storage == .fridge ? expiryDate : nil
    }

    // MARK: - Private

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var presetExpiry: Date? {
        ShelfLifePreset.expiryDate(
            name: name, category: category, storage: storage, startDate: thawed ? now : addedDate)
    }

    private mutating func recalculateExpiry() {
        guard storage == .fridge, !expiryEdited else { return }
        expiryDate = presetExpiry
    }

    private static func sameDay(_ a: Date, _ b: Date?) -> Bool {
        guard let b else { return false }
        return Calendar.current.isDate(a, inSameDayAs: b)
    }
}
