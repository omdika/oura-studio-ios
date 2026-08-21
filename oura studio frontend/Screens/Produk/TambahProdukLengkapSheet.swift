import SwiftUI

private struct FabricGroup: Identifiable {
    let family: String?
    let fabIds: [UUID]
    var id: String { family ?? fabIds.map { $0.uuidString }.joined(separator: "-") }
    var isGrouped: Bool { family != nil && fabIds.count > 1 }
}

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

struct TambahProdukLengkapSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    // Called after "Simpan Tanpa Resep" creates the product, so the caller can immediately
    // navigate to ProdukDetailView -- lands on the product's size list rather than jumping
    // straight into one specific size, since the user (not this form) should pick which size(s)
    // get an initial harga/stok/HPP.
    var onCreatedWithoutRecipe: ((Product) -> Void)? = nil

    // MARK: — Step 1: product fields
    @State private var productName = ""
    @State private var sku = ""
    @State private var selectedSizes: [String] = ["Free Size"]
    @State private var showCustomSizeAlert = false
    @State private var customSizeInput = ""

    // MARK: — Step 2: recipe fields
    @State private var fabrics: [Material] = []
    @State private var allMaterials: [Material] = []
    @State private var activeSizeLabel: String = ""
    @State private var selectedFabricIds: [UUID] = []
    @State private var fabricLengths: [String: [UUID: Double]] = [:]
    @State private var fabricWidths: [String: [UUID: Double]] = [:]
    @State private var fabricRotations: [String: [UUID: Bool]] = [:]
    @State private var isFabricVariant = true
    @State private var selectedComponentIds: [UUID] = []
    @State private var componentQtys: [UUID: Double] = [:]
    @State private var laborMinutes: Double?

    // MARK: — Navigation & save state
    @State private var isOnRecipeStep = false
    @State private var isSaving = false
    @State private var errorMsg: String?

    // MARK: — Dari Resep discovery
    @State private var resepProducts: [ResepProductInfo] = []
    @State private var isLoadingResep = false
    @State private var selectedResepProduct: ResepProductInfo? = nil
    @State private var resepSearchText = ""

    private var filteredResepProducts: [ResepProductInfo] {
        resepSearchText.isEmpty
            ? resepProducts
            : resepProducts.filter { $0.name.localizedCaseInsensitiveContains(resepSearchText) }
    }

    private let presets: [(label: String, sizes: [String])] = [
        ("Free Size", ["Free Size"]),
        ("XS – XXL", ["XS", "S", "M", "L", "XL", "XXL"]),
        ("S – XXL",  ["S", "M", "L", "XL", "XXL"]),
    ]

    private var step1Valid: Bool {
        !productName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !sku.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedSizes.isEmpty
    }

    private func sizeIsComplete(_ label: String) -> Bool {
        guard !selectedFabricIds.isEmpty else { return false }
        return selectedFabricIds.allSatisfy { id in
            (fabricLengths[label]?[id] ?? 0) > 0 && (fabricWidths[label]?[id] ?? 0) > 0
        }
    }

    private var recipeCanSave: Bool {
        guard !selectedFabricIds.isEmpty else { return false }
        guard (laborMinutes ?? 0) > 0 else { return false }
        guard selectedComponentIds.allSatisfy({ id in (componentQtys[id] ?? 0) > 0 }) else { return false }
        return selectedSizes.contains { sizeIsComplete($0) }
    }

    private var fabricGroups: [FabricGroup] {
        var familyMap: [String: [UUID]] = [:]
        var ungrouped: [UUID] = []
        for fabId in selectedFabricIds {
            if let family = fabrics.first(where: { $0.id == fabId })?.fabricFamily {
                familyMap[family, default: []].append(fabId)
            } else {
                ungrouped.append(fabId)
            }
        }
        var groups: [FabricGroup] = familyMap.keys.sorted().map {
            FabricGroup(family: $0, fabIds: familyMap[$0]!)
        }
        groups += ungrouped.map { FabricGroup(family: nil, fabIds: [$0]) }
        return groups
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(OuraTheme.Colors.separator)
            // Fixed right below the header (not inside the scrollable content below) so a save
            // failure is visible immediately, regardless of scroll position — previously this sat
            // at the bottom of the form/list and could be scrolled out of view.
            if let err = errorMsg {
                errorBanner(err)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }
            if isOnRecipeStep {
                recipeStepContent
            } else {
                productStepContent
            }
        }
        .background(OuraTheme.Colors.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            await loadMaterials()
            await loadResepProducts()
        }
        .sheet(item: $selectedResepProduct) { product in
            TambahStokDariResepSheet(product: product) {
                Task { await loadResepProducts() }
            }
            .environmentObject(api)
        }
        .alert("Ukuran Kustom", isPresented: $showCustomSizeAlert) {
            TextField("contoh: 2XL, 32, One Size", text: $customSizeInput)
                .autocorrectionDisabled()
            Button("Tambah") {
                let label = customSizeInput.trimmingCharacters(in: .whitespaces)
                customSizeInput = ""
                guard !label.isEmpty, !selectedSizes.contains(label) else { return }
                selectedSizes.append(label)
                activeSizeLabel = label
            }
            Button("Batal", role: .cancel) { customSizeInput = "" }
        }
    }

    // MARK: — Header

    private var header: some View {
        HStack {
            if isOnRecipeStep {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isOnRecipeStep = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Produk")
                            .font(.system(size: 15))
                    }
                    .foregroundStyle(OuraTheme.Colors.accent)
                }
                .buttonStyle(.plain)
            } else {
                Button("Batal") { dismiss() }
                    .foregroundStyle(OuraTheme.Colors.accent)
            }

            Spacer()

            Text(isOnRecipeStep ? "Tambah Resep" : "Tambah Produk")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)

            Spacer()

            // Invisible placeholder to balance title
            Text("Batal").foregroundStyle(.clear)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: — Step 1: Product

    private var productStepContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    dariResepSection

                    if !resepProducts.isEmpty {
                        HStack(spacing: 8) {
                            Rectangle().fill(OuraTheme.Colors.separator).frame(height: 0.75)
                            Text("BUAT PRODUK BARU")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(OuraTheme.Colors.textTertiary)
                                .tracking(0.5)
                                .fixedSize()
                            Rectangle().fill(OuraTheme.Colors.separator).frame(height: 0.75)
                        }
                    }

                    sectionLabel("Nama Produk") {
                        TextField("contoh: Scrunchie Mini", text: $productName)
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                            .autocorrectionDisabled()
                            .onChange(of: productName) { val in sku = Self.autoSKU(from: val) }
                            .fieldStyle()
                    }

                    sectionLabel("Kode SKU") {
                        TextField("contoh: SCRMINI", text: $sku)
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .fieldStyle()
                        Text("Kode unik singkat. Tidak bisa diubah setelah dibuat.")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }

                    sectionLabel("Ukuran") {
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
                                            .overlay(Capsule().stroke(isActive ? OuraTheme.Colors.accent.opacity(0.4) : OuraTheme.Colors.border, lineWidth: 1))
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
                                            Button { selectedSizes.removeAll { $0 == size } } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                                            }
                                            .buttonStyle(.borderless)
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

                    sectionLabel("Tipe Produk") {
                        HStack(spacing: 8) {
                            Button { isFabricVariant = true } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Varian Kain")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(isFabricVariant ? OuraTheme.Colors.accent : OuraTheme.Colors.textPrimary)
                                    Text("Tiap kain jadi varian produk tersendiri")
                                        .font(.system(size: 11))
                                        .foregroundStyle(isFabricVariant ? OuraTheme.Colors.accent : OuraTheme.Colors.textTertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(isFabricVariant ? OuraTheme.Colors.accentLight : OuraTheme.Colors.surfaceSheet)
                                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                                .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium).stroke(
                                    isFabricVariant ? OuraTheme.Colors.accent.opacity(0.5) : OuraTheme.Colors.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: isFabricVariant)

                            Button { isFabricVariant = false } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Kombo Kain")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(!isFabricVariant ? OuraTheme.Colors.accent : OuraTheme.Colors.textPrimary)
                                    Text("Semua kain masuk dalam satu resep")
                                        .font(.system(size: 11))
                                        .foregroundStyle(!isFabricVariant ? OuraTheme.Colors.accent : OuraTheme.Colors.textTertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(!isFabricVariant ? OuraTheme.Colors.accentLight : OuraTheme.Colors.surfaceSheet)
                                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                                .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium).stroke(
                                    !isFabricVariant ? OuraTheme.Colors.accent.opacity(0.5) : OuraTheme.Colors.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: isFabricVariant)
                        }
                    }
                }
                .padding(16)
            }

            VStack(spacing: 0) {
                Divider().overlay(OuraTheme.Colors.separator)
                VStack(spacing: 10) {
                    // Primary: go to recipe step
                    Button {
                        activeSizeLabel = selectedSizes.first ?? ""
                        withAnimation(.easeInOut(duration: 0.2)) { isOnRecipeStep = true }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Lanjutkan ke Resep")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(step1Valid ? OuraTheme.Colors.accentGradient : LinearGradient(colors: [OuraTheme.Colors.border], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                    }
                    .buttonStyle(.plain)
                    .disabled(!step1Valid || isSaving)

                    // Secondary: save product only
                    Button {
                        Task { await saveProductOnly() }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView().tint(OuraTheme.Colors.accent)
                            } else {
                                Text("Simpan Tanpa Resep")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(step1Valid ? OuraTheme.Colors.accent : OuraTheme.Colors.textDisabled)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(OuraTheme.Colors.surfaceSheet)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                        .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.large).stroke(OuraTheme.Colors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!step1Valid || isSaving)
                }
                .padding(16)
            }
            .background(OuraTheme.Colors.background)
        }
    }

    // MARK: — Step 2: Recipe

    private var recipeStepContent: some View {
        VStack(spacing: 0) {
            Form {
                // Size tabs — tap a tab to fill its dimensions; checkmark when complete
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ukuran")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedSizes, id: \.self) { size in
                                    let isActive = activeSizeLabel == size
                                    let isDone = sizeIsComplete(size)
                                    Button { activeSizeLabel = size } label: {
                                        HStack(spacing: 4) {
                                            if isDone {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            Text(size)
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundStyle(
                                            isActive ? .white :
                                            isDone   ? OuraTheme.Colors.accent :
                                                       OuraTheme.Colors.textSecondary
                                        )
                                        .padding(.horizontal, 14).padding(.vertical, 7)
                                        .background(
                                            isActive ? OuraTheme.Colors.accent :
                                            isDone   ? OuraTheme.Colors.accentLight :
                                                       OuraTheme.Colors.surfaceSheet
                                        )
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(
                                            isActive ? Color.clear :
                                            isDone   ? OuraTheme.Colors.accent.opacity(0.35) :
                                                       OuraTheme.Colors.border,
                                            lineWidth: 1
                                        ))
                                    }
                                    .buttonStyle(.borderless)
                                    .animation(.easeInOut(duration: 0.15), value: activeSizeLabel)
                                    .animation(.easeInOut(duration: 0.15), value: isDone)
                                }

                                Button { showCustomSizeAlert = true } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("Ukuran")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(OuraTheme.Colors.accent)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(OuraTheme.Colors.accentLight)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(OuraTheme.Colors.accent.opacity(0.35), lineWidth: 1))
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                } header: {
                    OuraSectionHeader(title: "Resep untuk Ukuran")
                }
                .listSectionSeparator(.hidden)

                // Kain
                Section {
                    TokenizedMultiSelectField(
                        label: "Kain yang Digunakan",
                        selectedIds: $selectedFabricIds,
                        items: fabrics.map { (id: $0.id, name: $0.name) },
                        placeholder: "Pilih kain (opsional)"
                    )
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                    ForEach(fabricGroups) { group in
                        let repId = group.fabIds[0]
                        let displayName = group.isGrouped
                            ? "\(group.family!) (\(group.fabIds.count) warna)"
                            : (fabrics.first { $0.id == repId }?.name ?? "")
                        VStack(alignment: .leading, spacing: 10) {
                            Text(displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(OuraTheme.Colors.textSecondary)
                            HStack(spacing: 12) {
                                NumericInputField(
                                    label: "Panjang (cm)",
                                    value: Binding(
                                        get: { fabricLengths[activeSizeLabel]?[repId] },
                                        set: { val in
                                            var dict = fabricLengths[activeSizeLabel] ?? [:]
                                            for id in group.fabIds { dict[id] = val }
                                            fabricLengths[activeSizeLabel] = dict
                                        }
                                    ),
                                    unit: "cm"
                                )
                                NumericInputField(
                                    label: "Lebar (cm)",
                                    value: Binding(
                                        get: { fabricWidths[activeSizeLabel]?[repId] },
                                        set: { val in
                                            var dict = fabricWidths[activeSizeLabel] ?? [:]
                                            for id in group.fabIds { dict[id] = val }
                                            fabricWidths[activeSizeLabel] = dict
                                        }
                                    ),
                                    unit: "cm"
                                )
                            }
                            Toggle("Rotasi Diizinkan", isOn: Binding(
                                get: { fabricRotations[activeSizeLabel]?[repId] ?? true },
                                set: { val in
                                    var dict = fabricRotations[activeSizeLabel] ?? [:]
                                    for id in group.fabIds { dict[id] = val }
                                    fabricRotations[activeSizeLabel] = dict
                                }
                            ))
                            .tint(OuraTheme.Colors.accent)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .id(activeSizeLabel + group.id)
                    }
                } header: {
                    OuraSectionHeader(title: "Kain (Opsional)")
                }
                .listSectionSeparator(.hidden)

                // Komponen tambahan
                Section {
                    TokenizedMultiSelectField(
                        label: "Bahan Tambahan",
                        selectedIds: $selectedComponentIds,
                        items: allMaterials.filter { $0.category != .fabric }.map { (id: $0.id, name: $0.name) },
                        placeholder: "Pilih bahan tambahan (opsional)"
                    )
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                    ForEach(selectedComponentIds, id: \.self) { matId in
                        let mat = allMaterials.first { $0.id == matId }
                        let unit = mat?.usageUnit ?? "pcs"
                        NumericInputField(
                            label: "\(mat?.name ?? "") per unit (\(unit))",
                            value: Binding(get: { componentQtys[matId] }, set: { componentQtys[matId] = $0 }),
                            unit: unit
                        )
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                } header: {
                    OuraSectionHeader(title: "Komponen Tambahan")
                }
                .listSectionSeparator(.hidden)

                // Labor
                Section {
                    NumericInputField(label: "Est. Waktu Kerja", value: $laborMinutes, unit: "menit")
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                } header: {
                    OuraSectionHeader(title: "Tenaga Kerja")
                }
                .listSectionSeparator(.hidden)
            }
            .scrollContentBackground(.hidden)
            .background(OuraTheme.Colors.background)

            // Bottom
            VStack(spacing: 0) {
                Divider().overlay(OuraTheme.Colors.separator)
                VStack(spacing: 10) {
                    Button { Task { await saveProductAndRecipe() } } label: {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            else {
                                Text("Simpan Produk & Resep")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(recipeCanSave ? OuraTheme.Colors.accentGradient : LinearGradient(colors: [OuraTheme.Colors.border], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                    }
                    .buttonStyle(.plain)
                    .disabled(!recipeCanSave || isSaving)

                    Button { Task { await saveProductOnly() } } label: {
                        Text("Simpan Tanpa Resep")
                            .font(.system(size: 14))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
                .padding(16)
            }
            .background(OuraTheme.Colors.background)
        }
    }

    // MARK: — Dari Resep Section

    @ViewBuilder
    private var dariResepSection: some View {
        if isLoadingResep || !resepProducts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("DARI RESEP")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                    .tracking(0.5)

                if isLoadingResep {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                            .font(.system(size: 14))
                        TextField("Cari produk dari resep...", text: $resepSearchText)
                            .font(.system(size: 14))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if !resepSearchText.isEmpty {
                            Button { resepSearchText = "" } label: {
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

                    if filteredResepProducts.isEmpty {
                        Text("Tidak ada produk cocok")
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredResepProducts.enumerated()), id: \.element.id) { idx, product in
                                if idx > 0 {
                                    Divider()
                                        .overlay(OuraTheme.Colors.separator)
                                        .padding(.leading, 12)
                                }
                                Button { selectedResepProduct = product } label: {
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
                        }
                        .background(OuraTheme.Colors.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                                .stroke(OuraTheme.Colors.border, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: — Helpers

    @ViewBuilder
    private func sectionLabel<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        Text(msg)
            .font(.system(size: 13))
            .foregroundStyle(OuraTheme.Colors.dangerText)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OuraTheme.Colors.dangerBg)
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
    }

    private static func autoSKU(from name: String) -> String {
        let words = name.uppercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return String(words.map { String($0.filter { $0.isLetter || $0.isNumber }.prefix(3)) }.joined().prefix(8))
    }

    // MARK: — Load

    private func loadMaterials() async {
        let mats = (try? await api.getMaterials()) ?? []
        allMaterials = mats.filter { !$0.isArchived }
        fabrics = allMaterials.filter { $0.category == .fabric }
    }

    private func loadResepProducts() async {
        isLoadingResep = true
        defer { isLoadingResep = false }

        guard let specs = try? await api.getPatternSpecs() else { return }
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

        resepProducts = result.sorted {
            if ($0.totalStock == 0) != ($1.totalStock == 0) { return $0.totalStock == 0 }
            return $0.name < $1.name
        }
    }

    // MARK: — Save: product only

    private func saveProductOnly() async {
        isSaving = true
        defer { isSaving = false }
        errorMsg = nil
        do {
            let product = try await api.createProduct(
                name: productName.trimmingCharacters(in: .whitespaces),
                sku: sku.trimmingCharacters(in: .whitespaces).isEmpty ? nil : sku.trimmingCharacters(in: .whitespaces)
            )
            for size in selectedSizes {
                _ = try await api.createProductSize(sku: product.sku, sizeLabel: size)
            }
            onCreatedWithoutRecipe?(product)
            dismiss()
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }

    // MARK: — Save: product + recipe

    private func saveProductAndRecipe() async {
        let completedSizes = selectedSizes.filter { sizeIsComplete($0) }
        guard !completedSizes.isEmpty else {
            errorMsg = "Isi dimensi kain untuk setidaknya satu ukuran."; return
        }

        let incomplComps = selectedComponentIds.filter { id in (componentQtys[id] ?? 0) <= 0 }
        if !incomplComps.isEmpty {
            let names = incomplComps.compactMap { id in allMaterials.first { $0.id == id }?.name }.joined(separator: ", ")
            errorMsg = "Isi jumlah untuk: \(names)"
            return
        }
        guard (laborMinutes ?? 0) > 0 else { errorMsg = "Isi estimasi waktu kerja (menit)."; return }

        isSaving = true
        defer { isSaving = false }
        errorMsg = nil

        do {
            // 1. Create product
            let product = try await api.createProduct(
                name: productName.trimmingCharacters(in: .whitespaces),
                sku: sku.trimmingCharacters(in: .whitespaces).isEmpty ? nil : sku.trimmingCharacters(in: .whitespaces)
            )

            // 2. Create all base sizes
            var sizeDetails: [ProductSizeDetail] = []
            for label in selectedSizes {
                let detail = try await api.createProductSize(sku: product.sku, sizeLabel: label)
                sizeDetails.append(detail)
            }

            let components = selectedComponentIds.map { matId in
                CreatePatternSpecRequest.ComponentInput(
                    materialId: matId,
                    qtyPerUnit: componentQtys[matId] ?? 0
                )
            }

            // 3. Create specs for each completed size
            for sizeLabel in completedSizes {
                guard let baseSize = sizeDetails.first(where: { $0.sizeLabel == sizeLabel }) else { continue }

                if !isFabricVariant {
                    // All fabrics in one spec linked to base size
                    let fabricInputs = selectedFabricIds.map { fabId in
                        CreatePatternSpecRequest.FabricInput(
                            materialId: fabId,
                            cutLengthCm: fabricLengths[sizeLabel]?[fabId] ?? 0,
                            cutWidthCm: fabricWidths[sizeLabel]?[fabId] ?? 0,
                            rotationAllowed: fabricRotations[sizeLabel]?[fabId] ?? true
                        )
                    }
                    let req = CreatePatternSpecRequest(
                        productSizeId: baseSize.id,
                        fabrics: fabricInputs,
                        estLaborMinutes: laborMinutes ?? 0,
                        components: components
                    )
                    _ = try await api.createOrUpdatePatternSpec(req)
                } else {
                    // One fabric variant size + spec per fabric
                    for fabId in selectedFabricIds {
                        guard let fabric = fabrics.first(where: { $0.id == fabId }) else { continue }
                        let variantSize = try await api.createProductSize(
                            sku: product.sku,
                            sizeLabel: sizeLabel,
                            fabricVariantName: fabric.name
                        )
                        let fabricInput = CreatePatternSpecRequest.FabricInput(
                            materialId: fabId,
                            cutLengthCm: fabricLengths[sizeLabel]?[fabId] ?? 0,
                            cutWidthCm: fabricWidths[sizeLabel]?[fabId] ?? 0,
                            rotationAllowed: fabricRotations[sizeLabel]?[fabId] ?? true
                        )
                        let req = CreatePatternSpecRequest(
                            productSizeId: variantSize.id,
                            fabrics: [fabricInput],
                            estLaborMinutes: laborMinutes ?? 0,
                            components: components
                        )
                        _ = try await api.createOrUpdatePatternSpec(req)
                    }
                }
            }
            dismiss()
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
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

// MARK: — TextField style

private extension View {
    func fieldStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(OuraTheme.Colors.surfaceSheet)
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
            .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium).stroke(OuraTheme.Colors.border, lineWidth: 1))
    }
}

