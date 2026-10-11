import SwiftUI

/// Temporary showcase of the visual foundations (step 1); replaced by the fridge page in step 2.
struct StyleGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "fridge.title", icon: .iconFridge, caption: Text(verbatim: "共 9 样"))
                Text(verbatim: "尽快用掉").font(.handwritten(20))

                HStack(spacing: 12) {
                    CategoryBadge(category: .vegetable)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: "西红柿").font(.body.weight(.semibold))
                        Text(verbatim: "冷藏 · 2 颗").font(.subheadline).foregroundStyle(Color.cocoa)
                    }
                    Spacer()
                    ExpiryTag(status: .tomorrow)
                }
                .cardStyle(padding: 12)

                FlowRow {
                    ExpiryTag(status: .expired(days: 1))
                    ExpiryTag(status: .today)
                    ExpiryTag(status: .ok(days: 5))
                    ExpiryTag(status: .frozen)
                }

                HStack(spacing: 10) {
                    ForEach(FoodCategory.allCases) { CategoryBadge(category: $0) }
                }

                Button {} label: {
                    Label { Text(verbatim: "生成菜单") } icon: { Image(.iconSparkle).resizable().frame(width: 20, height: 20) }
                }
                .buttonStyle(.primary)
                HStack {
                    Button {} label: { Text(verbatim: "重新生成") }.buttonStyle(.secondary)
                    Button {} label: { Text(verbatim: "不可用") }.buttonStyle(.primary).disabled(true)
                }

                HStack(spacing: 14) {
                    ForEach([ImageResource.iconAdd, .iconSearch, .iconRetry, .iconChill, .iconUpDown, .iconCheck,
                             .iconBack, .iconForward, .iconEye, .iconEyeSlash], id: \.self) {
                        Image($0).resizable().frame(width: 24, height: 24)
                    }
                }
                .foregroundStyle(Color.ink)

                HStack(alignment: .bottom, spacing: 12) {
                    Image(.illusEmptyFridge).resizable().scaledToFit().frame(width: 90)
                    Image(.illusCooking).resizable().scaledToFit().frame(width: 60)
                    Image(.illusNetworkError).resizable().scaledToFit().frame(width: 70)
                    Image(.illusAIError).resizable().scaledToFit().frame(width: 70)
                    Image(.illusKey).resizable().scaledToFit().frame(width: 34)
                }
            }
            .padding(16)
        }
        .pageBackground()
    }
}

/// Minimal wrapping row for the gallery's tags.
private struct FlowRow: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, point) in zip(subviews, arrange(subviews, width: bounds.width).points) {
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (size: CGSize, points: [CGPoint]) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), points)
    }
}

#Preview {
    NavigationStack { StyleGallery() }
}
