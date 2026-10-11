import SwiftUI

/// v3.70: Daftar penuh stok habis (read-only). Dibuka dari "Lihat semua" di Beranda.
/// v3.71: row tappable — tap dismiss sheet lalu `onSelect` (parent resolve + push detail).
struct StockOutAllSheet: View {
    let alerts: [LowStockAlert]
    var onSelect: ((LowStockAlert) -> Void)? = nil
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [LowStockAlert] {
        guard !query.isEmpty else { return alerts }
        let q = query.lowercased()
        return alerts.filter {
            $0.productName.lowercased().contains(q) ||
            $0.sizeLabel.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { alert in
                Button {
                    dismiss()
                    onSelect?(alert)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(OuraTheme.Colors.dangerText)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.productName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                                .lineLimit(1)
                            Text("Ukuran \(alert.sizeLabel) · 0 pcs tersisa")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(OuraTheme.Colors.dangerText)
                        }
                        Spacer()
                        OuraTag(text: "Habis", color: OuraTheme.Colors.dangerText, bg: OuraTheme.Colors.dangerBg)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("stok-habis-item-\(alert.productSizeId.uuidString)")
                .accessibilityLabel("Buka detail \(alert.productName) ukuran \(alert.sizeLabel)")
            }
            .searchable(text: $query, prompt: "Cari produk / ukuran")
            .navigationTitle("Stok Habis (\(alerts.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }
}
