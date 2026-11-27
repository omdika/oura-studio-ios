import SwiftUI

/// Layar scanner + cart hitungan untuk satu sesi stok opname.
/// Kamera di atas, cart hitungan di bawah.
struct StokOpnameScannerView: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let session: StockOpnameSession

    @State private var items: [StockOpnameItem] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var showingNewProduct = false
    @State private var navigatingToReconcile = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Placeholder kamera QR — integrate dengan QRScannerSheet
                VStack(spacing: 0) {
                    cameraPlaceholder

                    // Cart hitungan (inline di bawah)
                    cartSection
                }
                .background(OuraTheme.Colors.background)
            }
            .navigationTitle("Scan & Hitung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Tambah Produk") {
                        showingNewProduct = true
                    }
                    .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
            .sheet(isPresented: $showingNewProduct) {
                StokOpnameNewProductSheet(sessionId: session.id)
                    .environmentObject(api)
            }
            .navigationDestination(isPresented: $navigatingToReconcile) {
                StokOpnameReconcileView(session: session, items: items)
                    .environmentObject(api)
            }
            .task {
                await loadItems()
            }
            .alert("Error", isPresented: .constant(errorMsg != nil)) {
                Button("OK") { errorMsg = nil }
            } message: {
                Text(errorMsg ?? "")
            }
        }
    }

    private var cameraPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(OuraTheme.Colors.accent)
            Text("Kamera QR")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
            Text("Arahkan kamera ke QR code produk untuk menambah ke hitungan.")
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Integrasikan QRScannerSheet di sini") {
                // Placeholder — integrasikan DataScannerViewController seperti QRScannerSheet
            }
            .font(.system(size: 13))
            .foregroundStyle(OuraTheme.Colors.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(OuraTheme.Colors.accentLight.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .background(OuraTheme.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var cartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Hitungan Fisik (\(items.count) item)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                if !items.isEmpty {
                    Button("Lanjut Review") {
                        navigatingToReconcile = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(OuraTheme.Colors.accentGradient)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cart")
                        .font(.system(size: 32))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                    Text("Belum ada produk yang dihitung")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    Text("Scan QR produk atau tambah produk manual untuk memulai.")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
            } else {
                List {
                    ForEach(items) { item in
                        stockOpnameItemRow(item)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(OuraTheme.Colors.background)
            }
        }
        .background(OuraTheme.Colors.background)
    }

    private func stockOpnameItemRow(_ item: StockOpnameItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Text("Stok sistem: \(Int(item.systemStockQtySnapshot)) pcs")
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    // decrement
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(OuraTheme.Colors.border)
                }
                .buttonStyle(.plain)
                .disabled(item.scannedQty <= 0)

                Text("\(Int(item.scannedQty))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .frame(minWidth: 30, alignment: .center)

                Button {
                    Task { await incrementQty(item) }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { await deleteItem(item) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(OuraTheme.Colors.dangerText)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .listRowBackground(OuraTheme.Colors.surfaceCard)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func incrementQty(_ item: StockOpnameItem) async {
        do {
            let updated = try await api.addStockOpnameItem(
                sessionId: session.id,
                productSizeId: item.productSizeId,
                scannedQty: 1,
                note: nil
            )
            await MainActor.run {
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    items[idx] = updated
                }
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

    private func deleteItem(_ item: StockOpnameItem) async {
        do {
            try await api.deleteStockOpnameItem(sessionId: session.id, itemId: item.id)
            await MainActor.run {
                items.removeAll { $0.id == item.id }
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

    private func loadItems() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let sessionDetail = try await api.getStockOpnameSession(id: session.id)
            await MainActor.run {
                items = sessionDetail.items ?? []
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
