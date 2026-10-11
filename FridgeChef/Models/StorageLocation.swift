import Foundation

enum StorageLocation: String, Codable, CaseIterable {
    case fridge
    case freezer

    var displayName: LocalizedStringResource {
        switch self {
        case .fridge: "Fridge"
        case .freezer: "Freezer"
        }
    }
}
