import SwiftUI

struct NumericInputField: View {
    let label: String
    @Binding var value: Double?
    var placeholder: String = "0"
    var unit: String? = nil
    var testId: String? = nil

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)

            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .focused($isFocused)
                    .accessibilityLabel(label)
                    .accessibilityIdentifier(testId ?? "input-\(label.replacingOccurrences(of: " (cm)", with: "").replacingOccurrences(of: " (gulung)", with: "").replacingOccurrences(of: " (meter)", with: "").replacingOccurrences(of: " (pcs)", with: "").replacingOccurrences(of: " (gram)", with: ""))")
                    .onChange(of: text) { new in
                        let normalized = new.replacingOccurrences(of: ",", with: ".")
                        let filtered = normalized.filter { $0.isNumber || $0 == "." }
                        if filtered != new { text = filtered }
                        value = Double(filtered)
                    }

                if let u = unit {
                    Text(u)
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
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
            if let v = value { text = formatNum(v) }
        }
        .onChange(of: value) { newValue in
            // Sync text when binding changes externally (e.g. switching size tabs).
            // Skip while focused so in-progress decimal input (e.g. "0.") isn't wiped.
            guard !isFocused else { return }
            let formatted = newValue.map { formatNum($0) } ?? ""
            if formatted != text { text = formatted }
        }
    }

    private func formatNum(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(v)
    }
}
