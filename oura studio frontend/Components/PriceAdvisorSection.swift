import SwiftUI

struct PriceAdvisorSection: View {
    let hpp: HPPBreakdown
    let itemLabel: String
    let onApply: (Double) -> Void

    @State private var isExpanded = false
    @State private var marginText = "40"
    @State private var feeText = "0"
    @State private var didSave = false

    private var margin: Double { Double(marginText.replacingOccurrences(of: ",", with: ".")) ?? 40 }
    private var fee: Double { Double(feeText.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private var suggestedPrice: Double {
        let deduction = (margin + fee) / 100.0
        guard deduction < 1.0, hpp.total > 0 else { return 0 }
        return ceil(hpp.total / (1 - deduction))
    }

    private var resultingMarginPct: Double {
        guard suggestedPrice > 0 else { return 0 }
        return (suggestedPrice - hpp.total) / suggestedPrice * 100
    }

    private var resultingMarkupPct: Double {
        guard hpp.total > 0, suggestedPrice > hpp.total else { return 0 }
        return (suggestedPrice - hpp.total) / hpp.total * 100
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.20))
                    Text("Price Advisor")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    Spacer()
                    if suggestedPrice > 0, !isExpanded {
                        Text("~\(suggestedPrice.rupiahFormatted)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(OuraTheme.Colors.accent)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .padding(.horizontal, OuraTheme.Spacing.cardPad)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    HStack {
                        Text("Target Margin (%)")
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("40", text: $marginText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 56)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                            Text("%")
                                .font(.system(size: 13))
                                .foregroundStyle(OuraTheme.Colors.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    HStack {
                        Text("Fee Marketplace (%)")
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("0", text: $feeText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 56)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                            Text("%")
                                .font(.system(size: 13))
                                .foregroundStyle(OuraTheme.Colors.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if suggestedPrice > 0 {
                        VStack(spacing: 5) {
                            priceRow("Harga Saran", value: suggestedPrice.rupiahFormatted + "/pcs", bold: true)
                            priceRow("Margin Aktual", value: String(format: "%.1f%%", resultingMarginPct))
                            priceRow("Markup", value: String(format: "%.1f%%", resultingMarkupPct))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(OuraTheme.Colors.accentLight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if suggestedPrice > 0 {
                        Button {
                            guard !didSave else { return }
                            onApply(suggestedPrice)
                            withAnimation { didSave = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { isExpanded = false; didSave = false }
                            }
                        } label: {
                            Group {
                                if didSave {
                                    Label("Harga Disimpan", systemImage: "checkmark")
                                } else {
                                    Text("Gunakan Harga Ini")
                                }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(OuraTheme.Colors.accentGradient)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                            .opacity(didSave ? 0.7 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .disabled(didSave)
                    }
                }
                .padding(.horizontal, OuraTheme.Spacing.cardPad)
                .padding(.bottom, 12)
            }
        }
    }

    private func priceRow(_ label: String, value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: bold ? .bold : .medium))
                .foregroundStyle(bold ? OuraTheme.Colors.accent : OuraTheme.Colors.textPrimary)
        }
    }
}
