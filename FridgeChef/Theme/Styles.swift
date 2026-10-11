import SwiftUI

enum Metrics {
    static let cardRadius: CGFloat = 18
    static let cardStroke: CGFloat = 2
    static let buttonRadius: CGFloat = 16
    static let buttonHeight: CGFloat = 52
    static let hardShadow: CGFloat = 3
}

extension View {
    /// Paper card with a rounded ink outline.
    func cardStyle(padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .background(Color.paper, in: RoundedRectangle(cornerRadius: Metrics.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius).strokeBorder(Color.ink, lineWidth: Metrics.cardStroke))
    }

    /// Cream page background behind lists and scroll views.
    func pageBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.cream.ignoresSafeArea())
    }
}

/// Honey button with an ink outline and a hard 3pt drop shadow.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, prominent: true)
    }
}

/// Paper button with an ink outline, no shadow.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, prominent: false)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

private struct StyledButton: View {
    let configuration: ButtonStyleConfiguration
    let prominent: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.buttonRadius)
        let pressed = configuration.isPressed
        let shadow = prominent && isEnabled ? Metrics.hardShadow : 0
        configuration.label
            .font(.handwritten(20, relativeTo: .headline))
            .foregroundStyle(isEnabled ? (prominent ? Color.onPastel : Color.ink) : Color.disabledText)
            .padding(.horizontal, 24)
            .frame(minHeight: Metrics.buttonHeight)
            .background(isEnabled ? (prominent ? Color.honey : Color.paper) : Color.controlFill, in: shape)
            .overlay(shape.strokeBorder(isEnabled ? Color.ink : Color.disabledStroke, lineWidth: 2))
            .offset(x: pressed ? shadow : 0, y: pressed ? shadow : 0)
            .background(shape.fill(Color.ink).offset(x: shadow, y: shadow))
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}
