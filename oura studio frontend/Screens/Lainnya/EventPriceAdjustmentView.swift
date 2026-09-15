import SwiftUI

struct EventPriceAdjustmentView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("eventPriceAdjustmentActive") private var isEventActive: Bool = false
    @AppStorage("eventPriceAdjustmentAmount") private var eventAdjustmentAmount: Double = 0.0

    private var adjustmentAmountBinding: Binding<Double?> {
        Binding(
            get: {
                eventAdjustmentAmount == 0 ? nil : eventAdjustmentAmount
            },
            set: { newValue in
                eventAdjustmentAmount = newValue ?? 0.0
            }
        )
    }

    var body: some View {
        Form {
            Section(header: Text("Pengaturan Harga Event")) {
                Toggle(isOn: $isEventActive) {
                    Text("Aktifkan Penyesuaian Harga Event")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                }
                .tint(OuraTheme.Colors.accent)

                CurrencyInputField(label: "Jumlah Penyesuaian Harga (Rp)", value: adjustmentAmountBinding)
                    .disabled(!isEventActive)
                    .opacity(isEventActive ? 1.0 : 0.6)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(OuraTheme.Colors.accent)
                        Text("Informasi")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                    }
                    Text("Penyesuaian harga ini bersifat global dan sementara. Harga semua produk di daftar produk, detail produk, scan QR, dan pencatatan penjualan akan ditambahkan dengan nominal di atas secara otomatis selama toggle aktif.")
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .lineSpacing(4)
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(OuraTheme.Colors.background)
        .navigationTitle("Ubah Harga Event")
        .navigationBarTitleDisplayMode(.inline)
    }
}
