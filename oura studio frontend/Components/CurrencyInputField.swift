import SwiftUI

struct CurrencyInputField: View {
    let label: String
    var caption: String? = nil
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
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                if let caption {
                    Text(caption)
                        .font(.system(size: 11))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
            }

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
        // v3.68-fix: sinkronkan tampilan bila binding berubah dari luar
        // (mis. koreksi harga otomatis pasca-scan). Jangan ganggu saat
        // pengguna sedang mengetik (fokus) agar digit tidak tertimpa.
        .onChange(of: value) { newVal in
            guard !isFocused else { return }
            if let v = newVal, v > 0 {
                let s = String(Int(v))
                if s != digits { digits = s }
            } else if !digits.isEmpty {
                digits = ""
            }
        }
    }
}
