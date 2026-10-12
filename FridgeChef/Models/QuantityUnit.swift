import Foundation

enum QuantityUnit: String, Codable, CaseIterable, Identifiable {
    case piece
    case head
    case item
    case box
    case bunch
    case bag

    var id: Self { self }

    var displayName: LocalizedStringResource {
        switch self {
        case .piece: "unit.piece"
        case .head: "unit.head"
        case .item: "unit.item"
        case .box: "unit.box"
        case .bunch: "unit.bunch"
        case .bag: "unit.bag"
        }
    }

    /// Plural name for English ("pieces"); the same word as `displayName` in Chinese.
    var pluralName: LocalizedStringResource {
        switch self {
        case .piece: "unit.piece.plural"
        case .head: "unit.head.plural"
        case .item: "unit.item.plural"
        case .box: "unit.box.plural"
        case .bunch: "unit.bunch.plural"
        case .bag: "unit.bag.plural"
        }
    }

    /// "2 颗" / "1 piece" / "0.5 pieces": singular only for exactly 1.
    func amountText(_ amount: Double) -> String {
        "\(amount.formatted()) \(String(localized: amount == 1 ? displayName : pluralName))"
    }
}
