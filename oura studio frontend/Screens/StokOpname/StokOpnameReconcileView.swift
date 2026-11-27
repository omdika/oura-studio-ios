import SwiftUI

/// Layar reconciliation: review stok sistem vs fisik vs variansi sebelum disimpan.
struct StokOpnameReconcileView: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let session: StockOpnameSession
    let items: [StockOpnameItem]

    @State private var isSaving = false
    @State private var navigatingToResult = false
    @State private var errorMsg: String?

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total Item")
                    Spacer()
                    Text("\(items.count)")
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                }
                HStack {
                    Text("Total Variansi (pcs)")
                    Spacer()
                    Text("\(totalVariansiQty, specifier: "%+d")")
                        .foregroundStyle(totalVariansiQty >= 0 ? .green : .red)
                        .font(.system(size: 15, weight: .semibold))
                }
                HStack {
                    Text("Dampak Finansial (est.)")
                    Spacer()
                    Text("\(totalVariansiValue, specifier: "%.0f") Rp")
                        .foregroundStyle(totalVariansiValue >= 0 ? .green : .red)
                        .font(.system(size: 15, weight: .semibold))
                }
            } header: {
                OuraSectionHeader(title: "Ringkasan")
            }

            Section {
                ForEach(items) { item in
                    reconcileRow(item)
                }
            } header: {
                OuraSectionHeader(title: "Detail per Varian")
            } footer: {
                if hasLargeVariansi {
                    Text("⚠️ Ada variansi yang mencolok (melebihi 5 pcs). Periksa kembali sebelum menyimpan.")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                }
            }

            if !items.isEmpty {
                Section {
                    Button {
                        Task { await complete() }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Simpan & Selesai")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canSave ? OuraTheme.Colors.accentGradient : LinearGradient(colors: [OuraTheme.Colors.border], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave || isSaving)
                }
                .listRowBackground(OuraTheme.Colors.background)
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }
        }
        .scrollContentBackground(.hidden)
        .background(OuraTheme.Colors.background)
        .navigationTitle("Review Hitungan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Batal") {
                    dismiss()
                }
                .foregroundStyle(OuraTheme.Colors.accent)
            }
        }
        .navigationDestination(isPresented: $navigatingToResult) {
            StokOpnameResultView(session: session)
                .environmentObject(api)
        }
        .alert("Error", isPresented: .constant(errorMsg != nil)) {
            Button("OK") { errorMsg = nil }
        } message: {
            Text(errorMsg ?? "")
        }
    }

    private func reconcileRow(_ item: StockOpnameItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                Text(item.varianceQty >= 0 ? "+\(Int(item.varianceQty))" : "\(Int(item.varianceQty))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(item.varianceQty >= 0 ? .green : .red)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stok Sistem")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                    Text("\(Int(item.systemStockQtySnapshot)) pcs")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jumlah Fisik")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                    Text("\(Int(item.scannedQty)) pcs")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(OuraTheme.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))

            if abs(item.varianceQty) > 5 {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text("Variansi besar — verifikasi kembali hitungan fisik")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(OuraTheme.Colors.surfaceCard)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var totalVariansiQty: Int {
        items.reduce(0) { $0 + Int($1.varianceQty) }
    }

    private var totalVariansiValue: Double {
        Double(totalVariansiQty) * 50000
    }

    private var hasLargeVariansi: Bool {
        items.contains { abs($0.varianceQty) > 5 }
    }

    private var canSave: Bool {
        !items.isEmpty && items.contains { $0.varianceQty != 0 }
    }

    private func complete() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let _ = try await api.completeStockOpnameSession(sessionId: session.id)
            await MainActor.run {
                navigatingToResult = true
            }
        } catch {
            await MainActor.run {
                if let apiErr = error as? APIError {
                    errorMsg = apiErr.errorDescription
                } else {
                    errorMsg = error.localizedDescription
                }
            }
        }
    }
}
