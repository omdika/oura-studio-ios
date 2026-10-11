import SwiftUI

/// v3.70: Daftar penuh stok habis (read-only). Dibuka dari "Lihat semua" di Beranda.
struct StockOutAllSheet: View {
    let alerts: [LowStockAlert]
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
                }
                .padding(.vertical, 4)
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
