import SwiftUI

struct ProdukListView: View {
    @EnvironmentObject private var api: APIService

    @State private var products: [Product] = []
    @State private var allSizes: [ProductSizeDetail] = []
    @State private var isLoading = true
    @State private var searchText: String = ""
    @State private var showAddProduct = false
    @State private var showQRScanner = false
    @State private var showQRGenerator = false
    // Set right after "Simpan Tanpa Resep" creates a product with no price/stock/HPP yet — drives
    // an auto-navigation into ProdukDetailView so the user can pick which size(s) to fill in.
    @State private var newlyCreatedProduct: Product?

    private var filtered: [Product] {
        let active = products.filter { !$0.isArchived }
        guard !searchText.isEmpty else { return active }
        let q = searchText.lowercased()
        return active.filter { product in
            product.name.localizedCaseInsensitiveContains(q) ||
            product.sku.localizedCaseInsensitiveContains(q) ||
            allSizes
                .filter { $0.productId == product.id }
                .contains {
                    $0.sizeLabel.localizedCaseInsensitiveContains(q) ||
                    ($0.fabricVariantName?.localizedCaseInsensitiveContains(q) ?? false)
                }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    emptyView
                } else {
                    productList
                }
            }
            .background(OuraTheme.Colors.background)

            OuraFAB { showAddProduct = true }
                .padding(.trailing, OuraTheme.Spacing.horizontal)
                .padding(.bottom, 20)
        }
        .navigationTitle("Produk")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Cari produk atau bahan...")
        .task { await load() }
        .refreshable { await load() }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showQRScanner = true } label: {
                    Image(systemName: "qrcode.viewfinder")
                }
                .foregroundStyle(OuraTheme.Colors.accent)
                Button { showQRGenerator = true } label: {
                    Image(systemName: "qrcode")
                }
                .foregroundStyle(OuraTheme.Colors.accent)
            }
        }
        .sheet(isPresented: $showAddProduct, onDismiss: { Task { await load() } }) {
            TambahProdukLengkapSheet(onCreatedWithoutRecipe: { newlyCreatedProduct = $0 })
        }
        .sheet(item: $newlyCreatedProduct, onDismiss: { Task { await load() } }) { product in
            NavigationStack {
                ProdukDetailView(product: product)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Tutup") { newlyCreatedProduct = nil }
                                .foregroundStyle(OuraTheme.Colors.accent)
                        }
                    }
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerSheet(mode: .stockInOnly)
                .environmentObject(api)
        }
        .sheet(isPresented: $showQRGenerator) {
            QRGeneratorView()
                .environmentObject(api)
        }
    }

    private var productList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(filtered) { product in
                    let sizes = allSizes.filter { $0.productId == product.id && !$0.isArchived }
                    ProductGroupRow(
                        product: product,
                        sizes: sizes,
                        onProductChanged: { Task { await load() } }
                    )
                }
            }
            .padding(.horizontal, OuraTheme.Spacing.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .background(OuraTheme.Colors.background)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 40))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
            Text(searchText.isEmpty ? "Belum ada produk" : "Produk tidak ditemukan")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            if searchText.isEmpty {
                Text("Tambah produk untuk mulai mencatat penjualan")
                    .font(.system(size: 13))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        isLoading = true
        async let p = api.getProducts()
        async let s = api.getAllProductSizes()
        products = (try? await p) ?? []
        allSizes = (try? await s) ?? []
        isLoading = false
    }
}

// MARK: - Product group row

private struct ProductGroupRow: View {
    let product: Product
    let sizes: [ProductSizeDetail]
    let onProductChanged: () -> Void

    private struct SizeGroup: Identifiable {
        let sizeLabel: String
        let variants: [ProductSizeDetail]
        var id: String { sizeLabel }
        var totalStock: Int { variants.reduce(0) { $0 + $1.currentStockQty } }
        // Falls back to all variants when none have a fabric variant name (e.g. a size created
        // without a resep) -- filtering to only fabric variants would leave this empty, silently
        // zeroing out lowestPrice/isAnyHabis/isAnyMenipis below even when the size does have data.
        // Matches ProdukSizeGroup.displayVariants in ProdukDetailView.swift.
        var displayVariants: [ProductSizeDetail] {
            let withFabric = variants.filter { $0.fabricVariantName != nil }
            return withFabric.isEmpty ? variants : withFabric
        }
        var isAnyHabis: Bool { displayVariants.contains { $0.currentStockQty == 0 } }
        var isAnyMenipis: Bool { displayVariants.contains { $0.isLowStock && $0.currentStockQty > 0 } }
        var lowestPrice: Double? { displayVariants.compactMap { $0.sellingPrice }.min() }
        // Flags a size that's completely unconfigured — no stock and no price set on any variant —
        // e.g. right after "Simpan Tanpa Resep" before the user has filled anything in.
        var needsSetup: Bool { totalStock == 0 && lowestPrice == nil }
    }

    private var groups: [SizeGroup] {
        Dictionary(grouping: sizes, by: \.sizeLabel)
            .map { label, variants in
                SizeGroup(
                    sizeLabel: label,
                    variants: variants.sorted { $0.displayLabel < $1.displayLabel }
                )
            }
            .sorted { $0.sizeLabel < $1.sizeLabel }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header → ProdukDetailView (product management)
            NavigationLink(destination: ProdukDetailView(product: product, onProductChanged: onProductChanged)) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                        Text(product.sku)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(OuraTheme.Colors.border)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .padding(OuraTheme.Spacing.cardPad)
            }
            .buttonStyle(.plain)

            if !groups.isEmpty {
                Divider().overlay(OuraTheme.Colors.separator)
                    .padding(.horizontal, OuraTheme.Spacing.cardPad)

                VStack(spacing: 0) {
                    ForEach(groups) { group in
                        // Each size label row → ProdukSizeGroupView (fabric variants)
                        NavigationLink(destination: ProdukSizeGroupView(product: product, sizeLabel: group.sizeLabel)) {
                            HStack(spacing: 10) {
                                HStack(spacing: 6) {
                                    Rectangle()
                                        .fill(OuraTheme.Colors.border)
                                        .frame(width: 2, height: 14)
                                        .clipShape(Capsule())
                                    Text(group.sizeLabel)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                                    if group.needsSetup {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(OuraTheme.Colors.warningText)
                                    }
                                    if group.isAnyHabis {
                                        OuraTag(text: "Habis",
                                                color: OuraTheme.Colors.dangerText,
                                                bg: OuraTheme.Colors.dangerBg)
                                    } else if group.isAnyMenipis {
                                        OuraTag(text: "Menipis",
                                                color: OuraTheme.Colors.warningText,
                                                bg: OuraTheme.Colors.warningBg)
                                    }
                                    if group.displayVariants.count > 1 {
                                        Text("\(group.displayVariants.count) varian")
                                            .font(.system(size: 11))
                                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    if let price = group.lowestPrice {
                                        Text(price.rupiahFormatted)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                                    } else {
                                        Text("Belum ada harga")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(OuraTheme.Colors.warningText)
                                    }
                                    Text("\(group.totalStock) pcs")
                                        .font(.system(size: 11))
                                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                                }
                            }
                            .padding(.horizontal, OuraTheme.Spacing.cardPad)
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)

                        if group.id != groups.last?.id {
                            Divider()
                                .padding(.leading, OuraTheme.Spacing.cardPad + 18)
                                .overlay(OuraTheme.Colors.separator)
                        }
                    }
                }
            }
        }
        .ouraCard()
    }
}

