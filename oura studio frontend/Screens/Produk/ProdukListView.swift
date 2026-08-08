import SwiftUI

struct ProdukListView: View {
    @EnvironmentObject private var api: APIService

    @State private var products: [Product] = []
    @State private var allSizes: [ProductSizeDetail] = []
    @State private var isLoading = true
    @State private var searchText: String = ""
    @State private var showAddProduct = false

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
        .sheet(isPresented: $showAddProduct, onDismiss: { Task { await load() } }) {
            AddProductSheet()
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
        var isAnyHabis: Bool { variants.contains { $0.currentStockQty == 0 } }
        var isAnyMenipis: Bool { variants.contains { $0.isLowStock && $0.currentStockQty > 0 } }
        var lowestPrice: Double? { variants.compactMap { $0.sellingPrice }.min() }
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
                                    if group.isAnyHabis {
                                        OuraTag(text: "Habis",
                                                color: OuraTheme.Colors.dangerText,
                                                bg: OuraTheme.Colors.dangerBg)
                                    } else if group.isAnyMenipis {
                                        OuraTag(text: "Menipis",
                                                color: OuraTheme.Colors.warningText,
                                                bg: OuraTheme.Colors.warningBg)
                                    }
                                    if group.variants.count > 1 {
                                        Text("\(group.variants.count) varian")
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

// MARK: - Add product sheet

private struct AddProductSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    @State private var productName: String = ""
    @State private var sku: String = ""
    @State private var selectedSizes: [String] = ["Free Size"]
    @State private var isSaving = false
    @State private var errorMsg: String?
    @State private var showCustomSizeAlert = false
    @State private var customSizeInput = ""

    private let presets: [(label: String, sizes: [String])] = [
        ("Free Size", ["Free Size"]),
        ("XS – XL",  ["XS", "S", "M", "L", "XL"]),
        ("S – XXL",  ["S", "M", "L", "XL", "XXL"]),
    ]

    private var canSave: Bool {
        !productName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !sku.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedSizes.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Batal") { dismiss() }
                    .foregroundStyle(OuraTheme.Colors.accent)
                Spacer()
                Text("Tambah Produk")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                Button("Simpan") { Task { await save() } }
                    .foregroundStyle(canSave ? OuraTheme.Colors.accent : OuraTheme.Colors.textDisabled)
                    .disabled(!canSave || isSaving)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().overlay(OuraTheme.Colors.separator)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Nama produk
                    fieldGroup(label: "Nama Produk") {
                        TextField("contoh: Scrunchie Mini", text: $productName)
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                            .autocorrectionDisabled()
                            .onChange(of: productName) { _, val in
                                sku = Self.autoSKU(from: val)
                            }
                            .inputFieldStyle()
                    }

                    // SKU
                    fieldGroup(label: "Kode SKU") {
                        TextField("contoh: SCRMINI", text: $sku)
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .inputFieldStyle()
                        Text("Kode unik singkat untuk produk ini. Tidak bisa diubah setelah dibuat.")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }

                    // Ukuran
                    fieldGroup(label: "Ukuran") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presets, id: \.label) { preset in
                                    let isActive = preset.sizes == selectedSizes
                                    Button { selectedSizes = preset.sizes } label: {
                                        Text(preset.label)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(isActive ? OuraTheme.Colors.accent : OuraTheme.Colors.textSecondary)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(isActive ? OuraTheme.Colors.accentLight : OuraTheme.Colors.surfaceSheet)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(
                                                isActive ? OuraTheme.Colors.accent.opacity(0.4) : OuraTheme.Colors.border,
                                                lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .animation(.easeInOut(duration: 0.15), value: selectedSizes)
                                }
                            }
                        }

                        if !selectedSizes.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(selectedSizes, id: \.self) { size in
                                        HStack(spacing: 5) {
                                            Text(size)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                                            Button {
                                                selectedSizes.removeAll { $0 == size }
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.leading, 10).padding(.trailing, 8).padding(.vertical, 6)
                                        .background(OuraTheme.Colors.surfaceCard)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(OuraTheme.Colors.border, lineWidth: 1))
                                    }
                                }
                            }
                        }

                        Button { showCustomSizeAlert = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                                Text("Ukuran Kustom").font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(OuraTheme.Colors.accent)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(OuraTheme.Colors.accentLight)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(OuraTheme.Colors.accent.opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Text("Bisa tambah ukuran lain nanti di detail produk.")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }

                    if let err = errorMsg {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.dangerText)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(OuraTheme.Colors.dangerBg)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                    }
                }
                .padding(16)
            }

            VStack(spacing: 0) {
                Divider().overlay(OuraTheme.Colors.separator)
                Button { Task { await save() } } label: {
                    HStack {
                        if isSaving { ProgressView().tint(.white) }
                        else { Text("Buat Produk").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white) }
                    }
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(canSave ? OuraTheme.Colors.accentGradient : LinearGradient(colors: [OuraTheme.Colors.border], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                }
                .buttonStyle(.plain)
                .disabled(!canSave || isSaving)
                .padding(16)
            }
            .background(OuraTheme.Colors.background)
        }
        .background(OuraTheme.Colors.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert("Ukuran Kustom", isPresented: $showCustomSizeAlert) {
            TextField("contoh: 2XL, 32, One Size", text: $customSizeInput)
                .autocorrectionDisabled()
            Button("Tambah") {
                let label = customSizeInput.trimmingCharacters(in: .whitespaces)
                customSizeInput = ""
                guard !label.isEmpty, !selectedSizes.contains(label) else { return }
                selectedSizes.append(label)
            }
            Button("Batal", role: .cancel) { customSizeInput = "" }
        }
    }

    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }

    private static func autoSKU(from name: String) -> String {
        String(name.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
    }

    private func save() async {
        isSaving = true; defer { isSaving = false }
        do {
            let product = try await api.createProduct(
                name: productName.trimmingCharacters(in: .whitespaces),
                sku: sku.trimmingCharacters(in: .whitespaces).isEmpty ? nil : sku.trimmingCharacters(in: .whitespaces))
            for size in selectedSizes {
                _ = try await api.createProductSize(sku: product.sku, sizeLabel: size)
            }
            dismiss()
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }
}

// MARK: - TextField style helper

private extension View {
    func inputFieldStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(OuraTheme.Colors.surfaceSheet)
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                    .stroke(OuraTheme.Colors.border, lineWidth: 1)
            )
    }
}
