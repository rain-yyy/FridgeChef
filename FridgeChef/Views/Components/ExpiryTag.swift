import SwiftUI


// 过期状态拓展，加入颜色和图标
extension ExpiryStatus {
    /// Pastel fill for the tag; nil means the neutral "ok" style.
    var tint: Color? {
        switch self {
        case .expired: .expired
        case .today, .tomorrow, .soon: .soon
        case .frozen: .frozen
        case .ok, .unknown: nil
        }
    }

    var icon: ImageResource? {
        switch self {
        case .today, .tomorrow, .soon: .iconSoon
        case .frozen: .iconFrozen
        default: nil
        }
    }
}

/// Capsule label for an item's expiry: color + text (+ icon for soon / frozen).
struct ExpiryTag: View {
    let status: ExpiryStatus

    var body: some View {
        let tint = status.tint
        HStack(spacing: 3) {
            if let icon = status.icon {
                Image(icon)
                    .resizable()
                    .frame(width: 15, height: 15)
            }
            Text(status.label)
        }
        .font(.footnote.weight(tint == nil ? .regular : .semibold))
        .foregroundStyle(tint == nil ? Color.cocoa : Color.onPastel)
        .padding(.leading, status.icon == nil ? 11 : 7)
        .padding(.trailing, 11)
        .frame(minHeight: 28)
        .background(tint ?? Color.paper, in: Capsule())
        .overlay(Capsule().strokeBorder(tint == nil ? Color.weakStroke : Color.ink, lineWidth: 1.5))
        .fixedSize()
    }
}

#Preview {
    VStack(alignment: .leading) {
        ExpiryTag(status: .expired(days: 1))
        ExpiryTag(status: .tomorrow)
        ExpiryTag(status: .ok(days: 5))
        ExpiryTag(status: .frozen)
    }
    .padding()
    .background(Color.cream)
}
