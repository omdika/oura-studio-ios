import SwiftUI
import VisionKit

/// Layar scanner + cart hitungan untuk satu sesi stok opname.
/// Kamera QR live di atas, cart hitungan di bawah.
struct StokOpnameScannerView: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let session: StockOpnameSession

    @State private var items: [StockOpnameItem] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var showingNewProduct = false
    @State private var navigatingToReconcile = false
    @State private var isScannerActive = true
    @State private var lastScanMessage: String?
    @State private var isProcessingScan = false

    private let cache = QRProductCache.shared

    var body: some View {
        VStack(spacing: 0) {
            cameraSection
            cartSection
        }
        .background(OuraTheme.Colors.background)
        .navigationTitle("Scan & Hitung")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Tutup") { dismiss() }
                    .foregroundStyle(OuraTheme.Colors.accent)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Tambah Manual") {
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
            await cache.preload(api: api, force: true)
            await loadItems()
        }
        .alert("Error", isPresented: .constant(errorMsg != nil)) {
            Button("OK") { errorMsg = nil }
        } message: {
            Text(errorMsg ?? "")
        }
    }

    // MARK: - Camera Section

    private var cameraSection: some View {
        ZStack(alignment: .bottom) {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerRepresentable(isActive: isScannerActive) { raw in
                    Task { await handleScan(raw) }
                }
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                    Text("Kamera tidak tersedia")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    Text("Gunakan \"Tambah Manual\" untuk menambah produk.")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OuraTheme.Colors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
            }

            // Scan status overlay
            if let msg = lastScanMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.7))
                    .clipShape(Capsule())
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: lastScanMessage)
            }

            if isProcessingScan {
                ProgressView()
                    .tint(.white)
                    .padding(8)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
                    .padding(.bottom, 12)
            }
        }
        .frame(height: 240)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Cart Section

    private var cartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Progress Header (Sudah vs Belum Dicek)
            let totalUniqueProducts = max(cache.totalUniqueProductNamesCount, 1)
            let scannedUniqueProducts = Set(items.compactMap { item in
                cache.lookup(item.productSizeId)?.productName
            }).count
            let totalCatalog = max(cache.count, items.count)
            let scannedCount = items.count
            let progressPct = totalCatalog > 0 ? Double(scannedCount) / Double(totalCatalog) : 0.0
            let totalScannedQty = items.reduce(0.0) { $0 + $1.scannedQty }
            let totalSystemQtyFromCache = cache.totalStockQty
            let totalSystemQty = totalSystemQtyFromCache > 0 ? totalSystemQtyFromCache : items.reduce(0.0) { $0 + $1.systemStockQtySnapshot }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress Hitung Fisik")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Spacer()
                    Text("\(Int(progressPct * 100))% Selesai")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(OuraTheme.Colors.accent)
                }

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(OuraTheme.Colors.border.opacity(0.3))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(OuraTheme.Colors.accentGradient)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progressPct))), height: 6)
                    }
                }
                .frame(height: 6)

                // Stats badges
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Spacer()
                        Text("Total Produk: Aktual \(scannedUniqueProducts) vs Sistem \(totalUniqueProducts)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                    }
                    HStack {
                        Spacer()
                        Text("Total Stok: Fisik \(Int(totalScannedQty)) vs Sistem \(Int(totalSystemQty))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(14)
            .background(OuraTheme.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
            .padding(.horizontal, 16)
            .padding(.top, 8)

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
                    Text("Scan QR produk atau tambah manual untuk memulai.")
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

    // MARK: - Item Row

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
                    Task { await decrementQty(item) }
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

    // MARK: - QR Scan Handler

    private func handleScan(_ raw: String) async {
        guard !isProcessingScan else { return }

        guard let parsed = cache.parseQR(raw) else {
            ScanFeedback.error()
            showScanMessage("❌ QR tidak dikenali")
            return
        }

        isProcessingScan = true
        defer { isProcessingScan = false }

        let productSizeId = parsed.id

        // Lookup product name from cache for feedback
        let productName = cache.lookup(productSizeId)?.productName ?? "Produk"
        let sizeLabel = cache.lookup(productSizeId)?.sizeLabel ?? ""
        let displayName = sizeLabel.isEmpty ? productName : "\(productName) – \(sizeLabel)"

        do {
            let updatedItem = try await api.addStockOpnameItem(
                sessionId: session.id,
                productSizeId: productSizeId,
                scannedQty: 1,
                note: nil
            )

            await MainActor.run {
                // Update or insert item in list
                if let idx = items.firstIndex(where: { $0.productSizeId == productSizeId }) {
                    items[idx] = updatedItem
                } else {
                    items.insert(updatedItem, at: 0)
                }
            }

            ScanFeedback.success()
            let qty = Int(updatedItem.scannedQty)
            showScanMessage("✅ \(displayName) → \(qty) pcs")
        } catch {
            ScanFeedback.error()
            if let apiErr = error as? APIError {
                showScanMessage("❌ \(apiErr.errorDescription ?? "Gagal")")
            } else {
                showScanMessage("❌ \(error.localizedDescription)")
            }
        }
    }

    private func showScanMessage(_ msg: String) {
        withAnimation { lastScanMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                if lastScanMessage == msg { lastScanMessage = nil }
            }
        }
    }

    // MARK: - CRUD Actions

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

    private func decrementQty(_ item: StockOpnameItem) async {
        let newQty = max(0, item.scannedQty - 1)
        do {
            let updated = try await api.addStockOpnameItem(
                sessionId: session.id,
                productSizeId: item.productSizeId,
                scannedQty: newQty - item.scannedQty,
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
