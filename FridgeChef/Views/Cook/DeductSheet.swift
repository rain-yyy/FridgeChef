import SwiftUI
import SwiftData

/// "确认扣减": what the plan used, adjustable per item, before it is taken out of the fridge.
struct DeductSheet: View {
    let plan: MenuPlan
    let planLabel: LocalizedStringResource
    let onConfirmed: (Deduction.Summary) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [FoodItem]
    @State private var rows: [DeductionRow]?

    var body: some View {
        NavigationStack {
            let rows = rows ?? []
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(rows.isEmpty ? "deduct.empty" : "deduct.intro \(String(localized: planLabel))")
                        .font(.subheadline)
                        .foregroundStyle(Color.cocoa)
                        .lineSpacing(3)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)
                    ForEach(rows.indices, id: \.self) { index in
                        DeductRowCard(row: binding(index))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(Color.cream.ignoresSafeArea())
            .handwrittenInlineTitle("deduct.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { confirmBar(rows) }
        }
        .tint(Color.ink)
        .onAppear {
            if self.rows == nil { self.rows = Deduction.rows(for: plan, items: items) }
        }
        #if DEBUG
        // For simulator checks: `-debugCookPath confirm` confirms the default amounts after a moment.
        .task {
            guard UserDefaults.standard.string(forKey: "debugCookPath") == "confirm" else { return }
            try? await Task.sleep(for: .seconds(1.5))
            onConfirmed(Deduction.apply(rows ?? [], to: items) { modelContext.delete($0) })
        }
        #endif
    }

    private func confirmBar(_ rows: [DeductionRow]) -> some View {
        let summary = Deduction.summary(of: rows)
        return Button {
            if summary.deducted == 0 {
                dismiss()
            } else {
                let done = Deduction.apply(rows, to: items) { modelContext.delete($0) }
                onConfirmed(done)
            }
        } label: {
            Group {
                if summary.deducted == 0 {
                    Text("deduct.skip")
                } else if summary.removed > 0 {
                    Text("deduct.confirm.remove \(summary.deducted) \(summary.removed)")
                } else {
                    Text("deduct.confirm \(summary.deducted)")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(
            LinearGradient(stops: [.init(color: Color.cream.opacity(0), location: 0), .init(color: Color.cream, location: 0.3)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func binding(_ index: Int) -> Binding<DeductionRow> {
        Binding(get: { rows![index] }, set: { rows![index] = $0 })
    }
}

/// One item: checkbox, name and stock, −/+ amount, and what will be left.
private struct DeductRowCard: View {
    @Binding var row: DeductionRow

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 10) {
                Button { row.isOn.toggle() } label: {
                    Image(.iconCheck)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.onPastel)
                        .opacity(row.isOn ? 1 : 0)
                        .frame(width: 28, height: 28)
                        .background(row.isOn ? Color.honey : Color.paper, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ink, lineWidth: 2))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, -8)
                .accessibilityLabel(Text("deduct.toggle \(row.name)"))
                .accessibilityAddTraits(row.isOn ? .isSelected : [])

                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: row.name).font(.body.weight(.semibold))
                    Text("deduct.have \(amountText(row.available))")
                        .font(.footnote)
                        .foregroundStyle(Color.cocoa)
                }
                Spacer(minLength: 6)

                HStack(spacing: 6) {
                    stepButton("−", label: "deduct.less", enabled: row.isOn && row.canDecrease) { row.decrease() }
                    Text(verbatim: "−\(amountText(row.amount))")
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                        .frame(minWidth: 54)
                    stepButton("+", label: "deduct.more", enabled: row.isOn && row.canIncrease) { row.increase() }
                }
            }

            HStack(spacing: 6) {
                if row.willRemove {
                    Text("deduct.willRemove")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.onPastel)
                        .padding(.horizontal, 9)
                        .frame(minHeight: 24)
                        .background(Color.expired, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.ink, lineWidth: 1.5))
                }
                Group {
                    if !row.isOn {
                        Text("deduct.after.skipped")
                    } else if row.willRemove {
                        Text("deduct.after.removed")
                    } else {
                        Text("deduct.after.left \(amountText(row.remaining))")
                    }
                }
                .font(.footnote)
                .foregroundStyle(Color.cocoa)
            }
        }
        .foregroundStyle(Color.ink)
        .padding(14)
        .background(Color.paper, in: RoundedRectangle(cornerRadius: Metrics.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius)
            .strokeBorder(row.isOn ? Color.ink : Color.hairline, lineWidth: Metrics.cardStroke))
        .opacity(row.isOn ? 1 : 0.6)
        .animation(.easeOut(duration: 0.15), value: row)
    }

    private func amountText(_ value: Double) -> String {
        "\(value.formatted()) \(String(localized: row.unit.displayName))"
    }

    private func stepButton(_ symbol: String, label: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: symbol)
                .font(.title3)
                .foregroundStyle(enabled ? Color.ink : Color.disabledText)
                .frame(width: 36, height: 36)
                .background(Color.controlFill, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text(label))
    }
}

#Preview {
    let container = PreviewData.container()
    let store = PreviewData.menuStore(for: container)
    return DeductSheet(plan: store.result!.plans[0], planLabel: MenuPlan.label(at: 0)) { _ in }
        .modelContainer(container)
}
