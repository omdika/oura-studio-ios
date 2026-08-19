import SwiftUI

struct BahanDetailView: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let material: Material

    @State private var purchases: [MaterialPurchase] = []
    @State private var usageEntries: [MaterialUsageEntry] = []
    @State private var allProducts: [Product] = []
    @State private var isLoading = true
    @State private var showTambah = false
    @State private var editingPurchase: MaterialPurchase? = nil
    @State private var navigatingProduct: Product? = nil
    @State private var localFabricFamily: String? = nil
    @State private var showFamilyPicker = false

    // MARK: - Derived

    private var avgCostLabel: String {
        let val = material.currentAvgCost
        let unit = material.category == .fabric ? "/m" : "/\(material.usageUnit)"
        return "avg \(val.rupiahFormatted)\(unit)"
    }

    private var totalRemainingCm: Double? {
        guard !isLoading, !purchases.isEmpty else { return nil }
        let withRemaining = purchases.compactMap { $0.remainingLengthCm }
        guard !withRemaining.isEmpty else { return nil }
        return withRemaining.reduce(0, +)
    }

    private var stockMovements: [StockMovement] {
        var moves: [StockMovement] = []
        for p in purchases {
            moves.append(StockMovement(
                date: p.purchasedAt,
                description: "Pembelian\(p.supplierName.map { " dari \($0)" } ?? "")",
                delta: "+\(purchaseQtyDisplay(p))",
                isPositive: true,
                productSku: nil
            ))
        }
        for u in usageEntries {
            moves.append(StockMovement(
                date: u.date,
                description: u.description,
                delta: String(format: "-%.0f cm", u.deductedCm),
                isPositive: false,
                productSku: u.productSku
            ))
        }
        return moves.sorted { $0.date < $1.date }
    }

    private func purchaseQtyDisplay(_ p: MaterialPurchase) -> String {
        if let l = p.lengthCm, let w = p.widthCm {
            return String(format: "%.0f × %.0f cm", w, l)
        }
        if let q = p.qty { return String(format: "%g \(material.purchaseUnit)", q) }
        return "-"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            detailTopBar
            Divider().overlay(OuraTheme.Colors.separator)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        OuraTag(text: material.category.displayName, color: categoryColor, bg: categoryBg)
                        if material.category == .fabric {
                            if let family = localFabricFamily {
                                Button { showFamilyPicker = true } label: {
                                    Text(family)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                                        .padding(.horizontal, 9).padding(.vertical, 5)
                                        .background(OuraTheme.Colors.surfaceCard)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(OuraTheme.Colors.border, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button { showFamilyPicker = true } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                                        Text("Jenis").font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                                    .padding(.horizontal, 9).padding(.vertical, 5)
                                    .background(OuraTheme.Colors.surfaceSheet)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(OuraTheme.Colors.border, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Spacer()
                        if let sisa = totalRemainingCm {
                            let sisaLabel = String(format: "Sisa %.0f cm", sisa)
                            Text(sisaLabel)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(sisa > 0 ? OuraTheme.Colors.greenAccent : OuraTheme.Colors.dangerText)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(sisa > 0 ? OuraTheme.Colors.greenBg : OuraTheme.Colors.dangerBg)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    addButton
                        .padding(.horizontal, OuraTheme.Spacing.horizontal)
                        .padding(.bottom, 24)

                    purchasesSection
                        .padding(.horizontal, OuraTheme.Spacing.horizontal)
                        .padding(.bottom, 24)

                    if !stockMovements.isEmpty {
                        pergerakanStokSection
                            .padding(.horizontal, OuraTheme.Spacing.horizontal)
                            .padding(.bottom, 32)
                    }
                }
            }
        }
        .background(OuraTheme.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
        .task { localFabricFamily = material.fabricFamily; await loadPurchases() }
        .sheet(isPresented: $showFamilyPicker) {
            FabricFamilyPickerSheet(currentFamily: localFabricFamily) { newFamily in
                Task {
                    if let updated = try? await api.patchMaterial(
                        id: material.id,
                        PatchMaterialRequest(fabricFamily: newFamily)
                    ) {
                        localFabricFamily = updated.fabricFamily
                    }
                }
            }
            .environmentObject(api)
        }
        .sheet(isPresented: $showTambah, onDismiss: { Task { await loadPurchases() } }) {
            TambahPembelianSheet(preselectedMaterial: material)
        }
        .sheet(item: $editingPurchase) { purchase in
            EditPembelianSheet(
                material: material,
                purchase: purchase,
                onUpdated: { updated in
                    if let idx = purchases.firstIndex(where: { $0.id == updated.id }) {
                        purchases[idx] = updated
                    }
                },
                onDeleted: { [purchaseId = purchase.id] in
                    purchases.removeAll { $0.id == purchaseId }
                }
            )
        }
        .sheet(item: $navigatingProduct) { product in
            ProdukDetailView(product: product)
                .environmentObject(api)
        }
    }

    // MARK: - Top bar

    private var detailTopBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.accent)
                    .frame(width: 34, height: 34)
                    .background(OuraTheme.Colors.accentLight)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(material.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(avgCostLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(OuraTheme.Colors.accentLight)
                .clipShape(Capsule())
        }
        .padding(.horizontal, OuraTheme.Spacing.horizontal)
        .padding(.vertical, 10)
        .background(OuraTheme.Colors.background)
    }

    // MARK: - Add button (outlined pill)

    private var addButton: some View {
        Button { showTambah = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Tambah Pembelian")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(OuraTheme.Colors.accent)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .overlay(
                Capsule()
                    .stroke(OuraTheme.Colors.accent, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Purchases section

    private var purchasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OuraSectionHeader(title: "Riwayat Pembelian")

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if purchases.isEmpty {
                Text("Belum ada pembelian tercatat")
                    .font(.system(size: 14))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .ouraCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(purchases.enumerated()), id: \.element.id) { idx, purchase in
                        Button { editingPurchase = purchase } label: {
                            PurchaseRow(purchase: purchase, material: material)
                        }
                        .buttonStyle(.plain)
                        if idx < purchases.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                                .overlay(OuraTheme.Colors.separator)
                        }
                    }
                }
                .ouraCard()
            }
        }
    }

    // MARK: - Pergerakan Stok section

    private var pergerakanStokSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OuraSectionHeader(title: "Pergerakan Stok")

            VStack(spacing: 0) {
                ForEach(Array(stockMovements.enumerated()), id: \.offset) { idx, move in
                    movementRow(move)
                    if idx < stockMovements.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                            .overlay(OuraTheme.Colors.separator)
                    }
                }
            }
            .ouraCard()
        }
    }

    private func movementRow(_ move: StockMovement) -> some View {
        let content = HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(move.description)
                    .font(.system(size: 14))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Text(move.date, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
            Spacer()
            Text(move.delta)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(move.isPositive ? OuraTheme.Colors.greenAccent : OuraTheme.Colors.dangerText)
            if move.productSku != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)

        return Group {
            if let sku = move.productSku,
               let product = allProducts.first(where: { $0.sku == sku }) {
                Button { navigatingProduct = product } label: { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    // MARK: - Helpers

    private var categoryColor: Color {
        switch material.category {
        case .fabric:    return OuraTheme.Colors.blueAccent
        case .thread:    return OuraTheme.Colors.greenAccent
        case .hardware:  return OuraTheme.Colors.warningText
        case .packaging: return OuraTheme.Colors.purple
        }
    }

    private var categoryBg: Color {
        switch material.category {
        case .fabric:    return OuraTheme.Colors.blueBg
        case .thread:    return OuraTheme.Colors.greenBg
        case .hardware:  return OuraTheme.Colors.warningBg
        case .packaging: return OuraTheme.Colors.purpleBg
        }
    }

    private func loadPurchases() async {
        isLoading = true
        async let purchasesTask = api.getPurchases(materialId: material.id)
        async let usageTask     = api.getMaterialUsage(materialId: material.id)
        async let productsTask  = api.getProducts()
        purchases    = (try? await purchasesTask) ?? []
        usageEntries = (try? await usageTask) ?? []
        allProducts  = (try? await productsTask) ?? []
        isLoading = false
    }
}

// MARK: - Fabric family picker sheet

private struct FabricFamilyPickerSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let currentFamily: String?
    let onSave: (String?) -> Void

    @State private var families: [String] = []
    @State private var inputText: String

    init(currentFamily: String?, onSave: @escaping (String?) -> Void) {
        self.currentFamily = currentFamily
        self.onSave = onSave
        _inputText = State(initialValue: currentFamily ?? "")
    }

    private var trimmed: String { inputText.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                if !families.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(families, id: \.self) { family in
                                    Button { inputText = family } label: {
                                        Text(family)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(
                                                inputText == family
                                                    ? OuraTheme.Colors.accent
                                                    : OuraTheme.Colors.textSecondary
                                            )
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(
                                                inputText == family
                                                    ? OuraTheme.Colors.accentLight
                                                    : OuraTheme.Colors.surfaceCard
                                            )
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule().stroke(
                                                    inputText == family
                                                        ? OuraTheme.Colors.accent
                                                        : OuraTheme.Colors.border,
                                                    lineWidth: 1
                                                )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                    } header: {
                        OuraSectionHeader(title: "Jenis yang Sudah Ada")
                    }
                    .listSectionSeparator(.hidden)
                }

                Section {
                    TextField("contoh: Satin, Waffle, Nilon", text: $inputText)
                        .autocorrectionDisabled()
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    OuraSectionHeader(title: "Nama Jenis")
                } footer: {
                    Text("Kain sejenis dikelompokkan di form resep — input dimensi cukup sekali per jenis.")
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .listSectionSeparator(.hidden)

                if currentFamily != nil {
                    Section {
                        Button("Hapus Jenis", role: .destructive) {
                            onSave(nil)
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                    .listSectionSeparator(.hidden)
                }
            }
            .scrollContentBackground(.hidden)
            .background(OuraTheme.Colors.background)
            .navigationTitle("Jenis Kain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        onSave(trimmed.isEmpty ? nil : trimmed)
                        dismiss()
                    }
                    .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
        }
        .task { families = (try? await api.getFabricFamilies()) ?? [] }
    }
}

// MARK: - Stock movement model (local, derived from purchases)

private struct StockMovement {
    let date: Date
    let description: String
    let delta: String
    let isPositive: Bool
    let productSku: String?
}

// MARK: - Purchase row

private struct PurchaseRow: View {
    let purchase: MaterialPurchase
    let material: Material

    private var dateLabel: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "id_ID")
        fmt.dateFormat = "d MMM yyyy"
        return fmt.string(from: purchase.purchasedAt)
    }

    private var dimensionLabel: String {
        if let l = purchase.lengthCm, let w = purchase.widthCm {
            return String(format: "%.0f × %.0f cm", w, l)
        }
        if let q = purchase.qty { return String(format: "%g \(material.purchaseUnit)", q) }
        return "-"
    }

    @ViewBuilder
    private var remainingStatusTag: some View {
        if let remaining = purchase.remainingLengthCm, let length = purchase.lengthCm {
            if remaining <= 0 {
                OuraTag(text: "Habis", color: OuraTheme.Colors.dangerText, bg: OuraTheme.Colors.dangerBg)
            } else if remaining < length {
                OuraTag(
                    text: String(format: "Sisa %.0f cm", remaining),
                    color: OuraTheme.Colors.warningText,
                    bg: OuraTheme.Colors.warningBg
                )
            }
            // remaining == length → belum terpakai, tidak perlu tag
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(dateLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                HStack(spacing: 4) {
                    if let sup = purchase.supplierName {
                        Text(sup)
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        Text("·")
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }
                    Text(dimensionLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    if let label = purchase.packageLabel {
                        Text("·")
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                        Text(label)
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(purchase.totalCost.rupiahFormatted)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                remainingStatusTag
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
