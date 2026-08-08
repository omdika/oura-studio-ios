import SwiftUI

struct OuraDatePickerField: View {
    let label: String
    @Binding var date: Date
    var allowFuture: Bool = false

    @State private var showingPicker = false

    private var displayText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Button { showingPicker = true } label: {
                HStack {
                    Text(displayText)
                        .font(.system(size: 15))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(OuraTheme.Colors.surfaceSheet)
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                        .stroke(OuraTheme.Colors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingPicker) {
            pickerSheet
        }
    }

    private var pickerSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pilih Tanggal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                Button { showingPicker = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(OuraTheme.Colors.surfaceSheet)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(OuraTheme.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            Group {
                if allowFuture {
                    DatePicker("", selection: $date, displayedComponents: .date)
                } else {
                    DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                }
            }
            .datePickerStyle(.graphical)
            .tint(OuraTheme.Colors.accent)
            .padding(.horizontal, 8)

            Spacer()
        }
        .background(OuraTheme.Colors.background)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
