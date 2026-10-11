import Foundation

enum QuantityUnit: String, Codable, CaseIterable {
    case piece
    case head
    case item
    case box
    case bunch
    case bag

    var displayName: LocalizedStringResource {
        switch self {
        case .piece: "piece"
        case .head: "head"
        case .item: "item"
        case .box: "box"
        case .bunch: "bunch"
        case .bag: "bag"
        }
    }
}
