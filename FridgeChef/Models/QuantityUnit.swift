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
}
