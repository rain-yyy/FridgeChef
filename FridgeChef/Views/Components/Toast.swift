import SwiftUI

extension EnvironmentValues {
    /// Shows a short message above the tab bar (set up by RootView).
    @Entry var showToast: (String) -> Void = { _ in }
}

/// Ink capsule with cream text, shown for a moment near the bottom of the screen.
struct ToastView: View {
    let message: String

    var body: some View {
        Text(verbatim: message)
            .font(.subheadline)
            .foregroundStyle(Color.cream)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.ink, in: Capsule())
            .accessibilityAddTraits(.isStaticText)
    }
}
