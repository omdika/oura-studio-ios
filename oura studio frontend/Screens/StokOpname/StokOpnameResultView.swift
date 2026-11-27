import SwiftUI

/// Layar hasil kompak stok opname setelah sesi diselesaikan.
struct StokOpnameResultView: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let session: StockOpnameSession

    @State private var sessionDetail: StockOpnameSession?
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading && sessionDetail == nil {
                ProgressView("Memuat…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let items = sessionDetail?.items ?? []
                ScrollView {
                    VStack(spacing: 20) {
                        // Status header
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 24))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stok Opname Selesai")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                                Text(session.completedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 13))
                                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(OuraTheme.Colors.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                        .padding(.horizontal, 16)

                        // Total variansi
                        HStack(spacing: 16) {
                            statCard(title: "Total Item", value: "\(session.itemCount)")
                            statCard(title: "Penyesuaian ditulis", value: "\(items.filter { $0.varianceQty != 0 }.count)")
                            statCard(title: "Total Variansi (pcs)", value: "\(totalVariansiQty(items), specifier: "%+d")", color: totalVariansiQty(items) >= 0 ? .green : .red)
                        }
                        .padding(.horizontal, 16)

                        // Daftar penyesuaian ledger
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Penyesuaian Stok yang Disimpan")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                                    .padding(.horizontal, 16)

                                ForEach(items.filter { $0.varianceQty != 0 }) { item in
                                    adjustmentRow(item)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Tombol kembali
                        Button {
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Kembali ke Daftar Sesi")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(OuraTheme.Colors.accentGradient)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                        Spacer(minLength: 20)
                    }
                    .padding(.top, 8)
                }
                .background(OuraTheme.Colors.background)
            }
        }
        .navigationTitle("Hasil Opname")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Selesai") {
                    dismiss()
                }
                .foregroundStyle(OuraTheme.Colors.accent)
            }
        }
        .task {
            await loadDetail()
        }
    }

    private func adjustmentRow(_ item: StockOpnameItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Text("SKU: \(item.productSku ?? "-")")
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.varianceQty >= 0 ? "+\(Int(item.varianceQty))" : "\(Int(item.varianceQty))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(item.varianceQty >= 0 ? .green : .red)
                Text("disimpan ke ledger")
                    .font(.system(size: 11))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
        }
        .padding(12)
        .background(OuraTheme.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
    }

    private func statCard(title: String, value: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(color ?? OuraTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(OuraTheme.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
    }

    private func totalVariansiQty(_ items: [StockOpnameItem]) -> Int {
        items.reduce(0) { $0 + Int($1.varianceQty) }
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let detail = try await api.getStockOpnameSession(id: session.id)
            await MainActor.run {
                sessionDetail = detail
            }
        } catch {
            // Ignore error, use session passed in
        }
    }
}
