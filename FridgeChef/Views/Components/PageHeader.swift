import SwiftUI

/// Large hand-drawn title at the top of a tab's root page, with an optional doodle and caption.
/// Used instead of the navigation bar's large title so the title can use the bundled font.
struct PageHeader: View {
    let title: LocalizedStringKey
    var icon: ImageResource? = nil
    var caption: Text? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.handwritten(34, relativeTo: .largeTitle))
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            if let icon {
                Image(icon)
                    .resizable()
                    .frame(width: 26, height: 26)
                    .foregroundStyle(Color.ink)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 8)
            if let caption {
                caption
                    .font(.subheadline)
                    .foregroundStyle(Color.cocoa)
            }
        }
    }
}

extension View {
    /// Inline navigation title in the hand-drawn font, for pushed pages.
    func handwrittenInlineTitle(_ title: LocalizedStringResource) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.handwritten(19, relativeTo: .headline))
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}
