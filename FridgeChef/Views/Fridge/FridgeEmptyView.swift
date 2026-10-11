import SwiftUI

/// Shown when there is nothing in the fridge yet.
struct FridgeEmptyView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(.illusEmptyFridge)
                .resizable()
                .scaledToFit()
                .frame(width: 150)
                .accessibilityHidden(true)
            Text("fridge.empty.title")
                .font(.handwritten(24))
                .foregroundStyle(Color.ink)
            Text("fridge.empty.message")
                .font(.subheadline)
                .foregroundStyle(Color.cocoa)
                .multilineTextAlignment(.center)
            Button("fridge.empty.add", action: onAdd)
                .buttonStyle(.primary)
                .padding(.top, 8)
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 40)
    }
}
