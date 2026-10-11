import Foundation

/// How close an item is to expiring; drives the tag text, color and icon.
enum ExpiryStatus: Equatable {
    case expired(days: Int)
    case today
    case tomorrow
    case soon(days: Int)
    case ok(days: Int)
    case frozen
    /// A fridge item without an expiry date (should not normally happen).
    case unknown

    /// Fridge items at most this many days from expiry count as "use soon".
    static let soonThreshold = 2

    init(storage: StorageLocation, daysLeft: Int?) {
        guard storage == .fridge else { self = .frozen; return }
        guard let days = daysLeft else { self = .unknown; return }
        switch days {
        case ..<0: self = .expired(days: -days)
        case 0: self = .today
        case 1: self = .tomorrow
        case ...Self.soonThreshold: self = .soon(days: days)
        default: self = .ok(days: days)
        }
    }

    var isExpired: Bool {
        if case .expired = self { return true }
        return false
    }

    /// Expiring within the threshold, not yet expired.
    var isSoon: Bool {
        switch self {
        case .today, .tomorrow, .soon: true
        default: false
        }
    }

    /// Belongs in the fridge page's "use soon" group (expired included).
    var isUrgent: Bool { isExpired || isSoon }

    var label: LocalizedStringResource {
        switch self {
        case .expired(let days): "expiry.expired \(days)"
        case .today: "expiry.today"
        case .tomorrow: "expiry.tomorrow"
        case .soon(let days), .ok(let days): "expiry.daysLeft \(days)"
        case .frozen: "expiry.frozen"
        case .unknown: "expiry.unknown"
        }
    }
}
