import SwiftUI

struct CurrencyInputField: View {
    let label: String
    @Binding var value: Double?

    @State private var digits: String = ""
    @FocusState private var isFocused: Bool

    private var displayText: String {
        guard !digits.isEmpty, let num = Double(digits) else { return "" }
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.groupingSeparator = "."
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: num)) ?? digits
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)

            HStack(spacing: 4) {
                Text("Rp")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)

                TextField("0", text: Binding(
                    get: { displayText },
                    set: { newVal in
                        let raw = newVal.filter { $0.isNumber }
                        digits = raw
                        value = raw.isEmpty ? nil : Double(raw)
                    }
                ))
                .keyboardType(.numberPad)
                .font(.system(size: 15))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
                .focused($isFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(OuraTheme.Colors.surfaceSheet)
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                    .stroke(isFocused ? OuraTheme.Colors.accent : OuraTheme.Colors.border, lineWidth: 1)
            )
        }
        .onAppear {
            if let v = value, v > 0 { digits = String(Int(v)) }
        }
    }
}
