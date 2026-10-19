import SwiftUI

// MARK: — Dari Resep discovery model

private struct ResepProductInfo: Identifiable {
    let sku: String
    let name: String
    let sizes: [ProductSizeDetail]

    var id: String { sku }
    var totalStock: Int { sizes.reduce(0) { $0 + $1.currentStockQty } }
    var uniqueSizeLabels: String {
        var seen = Set<String>()
        var labels: [String] = []
        for s in sizes where !seen.contains(s.sizeLabel) {
            seen.insert(s.sizeLabel)
            labels.append(s.sizeLabel)
        }
        return labels.isEmpty ? "Tanpa ukuran" : labels.joined(separator: " · ")
    }
}

// MARK: — Resep Stock Picker Sheet

struct ResepStockPickerSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    private enum LoadState {
        case loading
        case loaded
        case empty
        case error(String)
    }

    @State private var state: LoadState = .loading
    @State private var products: [ResepProductInfo] = []
    @State private var searchText = ""
    @State private var selectedProduct: ResepProductInfo? = nil

    private var filteredProducts: [ResepProductInfo] {
        searchText.isEmpty
            ? products
            : products.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(OuraTheme.Colors.separator)
            content
        }
        .background(OuraTheme.Colors.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await load() }
        .sheet(item: $selectedProduct) { product in
            TambahStokDariResepSheet(product: product) {
                Task { await load() }
            }
            .environmentObject(api)
        }
    }

    private var header: some View {
        HStack {
            Button("Batal") { dismiss() }
                .foregroundStyle(OuraTheme.Colors.accent)
            Spacer()
            Text("Tambah Stok dari Resep")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
            Spacer()
            Text("Batal").foregroundStyle(.clear)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            VStack(spacing: 10) {
                ProgressView()
                Text("Memuat resep…")
                    .font(.system(size: 13))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundStyle(OuraTheme.Colors.warningText)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                Button { Task { await load() } } label: {
                    Text("Coba Lagi")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.accent)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(OuraTheme.Colors.accentLight)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            VStack(spacing: 8) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 28))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                Text("Belum ada produk dengan resep.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Text("Buat resep terlebih dahulu di tab Produksi.")
                    .font(.system(size: 13))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            loadedContent
        }
    }

    private var loadedContent: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 12) {
                    if filteredProducts.isEmpty {
                        Text("Tidak ada produk cocok")
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredProducts.enumerated()), id: \.element.id) { idx, product in
                                if idx > 0 {
                                    Divider()
                                        .overlay(OuraTheme.Colors.separator)
                                        .padding(.leading, 12)
                                }
                                row(product)
                            }
                        }
                        .background(OuraTheme.Colors.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                                .stroke(OuraTheme.Colors.border, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .font(.system(size: 14))
            TextField("Cari produk dari resep...", text: $searchText)
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(OuraTheme.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                .stroke(OuraTheme.Colors.border, lineWidth: 0.75)
        )
    }

    private func row(_ product: ResepProductInfo) -> some View {
        Button { selectedProduct = product } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Text(product.uniqueSizeLabels)
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                Spacer()
                if product.totalStock == 0 {
                    OuraTag(text: "Belum ada stok", color: OuraTheme.Colors.warningText, bg: OuraTheme.Colors.warningBg)
                } else {
                    OuraTag(text: "Stok: \(product.totalStock) pcs")
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(product.totalStock == 0 ? 1.0 : 0.55)
    }

    private func load() async {
        state = .loading
        do {
            let specs = try await api.getPatternSpecs()
            let activeSpecs = specs.filter { $0.isActive }
            let uniqueSkus = Array(Set(activeSpecs.map { $0.productSku }))

            var result: [ResepProductInfo] = []
            for sku in uniqueSkus {
                let name = activeSpecs.first { $0.productSku == sku }?.productName ?? sku
                let sizes = (try? await api.getProductSizes(sku: sku)) ?? []
                // Only include sizes that have an active spec — avoids calling stock-adjustments
                // on base/orphan sizes that the backend no longer resolves for this product.
                let specSizeIds = Set(activeSpecs.filter { $0.productSku == sku }.map { $0.productSizeId })
                result.append(ResepProductInfo(sku: sku, name: name, sizes: sizes.filter { !$0.isArchived && specSizeIds.contains($0.id) }))
            }

            products = result.sorted {
                if ($0.totalStock == 0) != ($1.totalStock == 0) { return $0.totalStock == 0 }
                return $0.name < $1.name
            }
            state = products.isEmpty ? .empty : .loaded
        } catch let e as APIError {
            state = .error(e.errorDescription ?? "Gagal memuat resep.")
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

// MARK: — Tambah Stok Dari Resep Sheet

private struct TambahStokDariResepSheet: View {
    let product: ResepProductInfo
    let onDone: () -> Void

    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    @State private var qtys: [UUID: Int] = [:]
    @State private var isSaving = false
    @State private var errorMsg: String?

    private var hasAnyQty: Bool { qtys.values.contains { $0 > 0 } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Batal") { dismiss() }
                    .foregroundStyle(OuraTheme.Colors.accent)
                Spacer()
                Text("Tambah Stok")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                Button("Simpan") { Task { await save() } }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(hasAnyQty && !isSaving ? OuraTheme.Colors.accent : OuraTheme.Colors.textDisabled)
                    .disabled(!hasAnyQty || isSaving)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            Divider().overlay(OuraTheme.Colors.separator)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Text("Masukkan jumlah unit yang ingin ditambahkan ke stok per ukuran.")
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            List {
                Section {
                    ForEach(product.sizes) { size in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(size.displayLabel)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                                Text("Stok saat ini: \(size.currentStockQty) pcs")
                                    .font(.system(size: 12))
                                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                            }
                            Spacer()
                            HStack(spacing: 10) {
                                Button {
                                    let cur = qtys[size.id] ?? 0
                                    if cur > 0 { qtys[size.id] = cur - 1 }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(OuraTheme.Colors.accent)
                                        .frame(width: 30, height: 30)
                                        .background(OuraTheme.Colors.accentLight)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                Text("\(qtys[size.id] ?? 0)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                                    .frame(minWidth: 32)
                                    .multilineTextAlignment(.center)

                                Button {
                                    qtys[size.id] = (qtys[size.id] ?? 0) + 1
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(OuraTheme.Colors.accent)
                                        .frame(width: 30, height: 30)
                                        .background(OuraTheme.Colors.accentLight)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                }
                .listSectionSeparatorTint(OuraTheme.Colors.separator)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(OuraTheme.Colors.background)

            if let err = errorMsg {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundStyle(OuraTheme.Colors.dangerText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OuraTheme.Colors.dangerBg)
            }
        }
        .background(OuraTheme.Colors.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        errorMsg = nil
        do {
            for (sizeId, qty) in qtys where qty > 0 {
                _ = try await api.adjustStock(sku: product.sku, sizeId: sizeId, qty: qty, reason: "adjustment")
            }
            onDone()
            dismiss()
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }
}
