import SwiftUI

struct DateRangeField: View {
    @Binding var from: Date
    @Binding var to: Date
    var onApply: () -> Void = {}

    @State private var showPicker = false

    var body: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundStyle(OuraTheme.Colors.accent)
                Text(rangeLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(OuraTheme.Colors.surfaceSheet)
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
            .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                .stroke(OuraTheme.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            DateRangePickerSheet(initialFrom: from, initialTo: to) { newFrom, newTo in
                from = newFrom
                to = newTo
                onApply()
            }
        }
    }

    private var rangeLabel: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "id_ID")
        fmt.dateFormat = "d MMM"
        let fmtFull = DateFormatter()
        fmtFull.locale = Locale(identifier: "id_ID")
        fmtFull.dateFormat = "d MMM yyyy"
        return "\(fmt.string(from: from)) – \(fmtFull.string(from: to))"
    }
}

struct DateRangePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onApply: (Date, Date) -> Void

    @State private var from: Date
    @State private var to: Date

    private let cal = Calendar.current

    init(initialFrom: Date, initialTo: Date, onApply: @escaping (Date, Date) -> Void) {
        _from = State(initialValue: initialFrom)
        _to = State(initialValue: initialTo)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preset chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("Hari Ini") { applyToday() }
                        chip("7 Hari") { applyDays(7) }
                        chip("30 Hari") { applyDays(30) }
                        chip("Bulan Ini") { applyThisMonth() }
                        chip("Bulan Lalu") { applyLastMonth() }
                        chip("3 Bulan") { applyDays(90) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                Divider().overlay(OuraTheme.Colors.separator)

                // Date picker rows
                VStack(spacing: 0) {
                    HStack {
                        Text("Dari")
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                        Spacer()
                        DatePicker("Dari", selection: $from, in: ...to, displayedComponents: .date)
                            .labelsHidden()
                            .tint(OuraTheme.Colors.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(OuraTheme.Colors.surfaceCard)

                    Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)

                    HStack {
                        Text("Sampai")
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                        Spacer()
                        DatePicker("Sampai", selection: $to, in: from..., displayedComponents: .date)
                            .labelsHidden()
                            .tint(OuraTheme.Colors.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(OuraTheme.Colors.surfaceCard)
                }
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                    .stroke(OuraTheme.Colors.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()
            }
            .background(OuraTheme.Colors.background)
            .navigationTitle("Pilih Periode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terapkan") {
                        onApply(from, to)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func chip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(OuraTheme.Colors.surfaceSheet)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(OuraTheme.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func applyDays(_ days: Int) {
        to = Date()
        from = cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    private func applyThisMonth() {
        let now = Date()
        from = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        to = now
    }

    private func applyLastMonth() {
        let now = Date()
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        to = cal.date(byAdding: .day, value: -1, to: startOfThisMonth) ?? now
        from = cal.date(from: cal.dateComponents([.year, .month], from: to)) ?? to
    }

    private func applyToday() {
        let now = Date()
        from = now
        to = now
    }
}
