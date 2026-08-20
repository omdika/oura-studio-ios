import SwiftUI

private struct FabricGroup: Identifiable {
    let family: String?
    let fabIds: [UUID]
    var id: String { family ?? fabIds.map { $0.uuidString }.joined(separator: "-") }
    var isGrouped: Bool { family != nil && fabIds.count > 1 }
}

struct TambahResepSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    // Section 1: Product + sizes (all tabs selectable)
    @State private var products: [Product] = []
    @State private var allSizes: [ProductSizeDetail] = []
    @State private var selectedProductId: UUID?
    @State private var selectedProductName: String = ""
    @State private var activeSizeLabel: String = ""

    // Section 2: Fabrics (shared picker, dimensions vary per size tab)
    @State private var fabrics: [Material] = []
    @State private var selectedFabricIds: [UUID] = []
    @State private var fabricLengths: [String: [UUID: Double]] = [:]
    @State private var fabricWidths: [String: [UUID: Double]] = [:]
    @State private var fabricRotations: [String: [UUID: Bool]] = [:]

    // Section 3: Components (shared)
    @State private var allMaterials: [Material] = []
    @State private var selectedComponentIds: [UUID] = []
    @State private var componentQtys: [UUID: Double] = [:]

    // Section 4: Labor (shared)
    @State private var laborMinutes: Double?

    // Recipe type
    @State private var isFabricVariant = true

    // New product quick-create
    @State private var showNewProductSheet = false
    @State private var pendingNewProductName: String = ""

    // New size inline-create
    @State private var showAddSizeAlert = false
    @State private var newSizeLabelInput = ""
    @State private var isCreatingSize = false

    // State
    @State private var isSaving = false
    @State private var errorMsg: String?
    @State private var showDiscardAlert = false

    private var hasChanges: Bool {
        selectedProductId != nil ||
        !selectedFabricIds.isEmpty || !selectedComponentIds.isEmpty ||
        (laborMinutes ?? 0) > 0
    }

    private var selectedProduct: Product? { products.first { $0.id == selectedProductId } }
    private var sizesForProduct: [ProductSizeDetail] {
        guard let p = selectedProduct else { return [] }
        return allSizes.filter { $0.productId == p.id }
    }

    // Unique size labels for tabs (avoids duplicates when multiple fabric variants share a label)
    private var uniqueSizeLabels: [String] {
        var seen = Set<String>()
        return sizesForProduct.compactMap { size in
            seen.insert(size.sizeLabel).inserted ? size.sizeLabel : nil
        }.sorted()
    }

    private func sizeIsComplete(_ label: String) -> Bool {
        guard !selectedFabricIds.isEmpty else { return false }
        return selectedFabricIds.allSatisfy { id in
            (fabricLengths[label]?[id] ?? 0) > 0 && (fabricWidths[label]?[id] ?? 0) > 0
        }
    }

    private var canSave: Bool {
        guard !selectedFabricIds.isEmpty else { return false }
        guard (laborMinutes ?? 0) > 0 else { return false }
        guard selectedComponentIds.allSatisfy({ id in (componentQtys[id] ?? 0) > 0 }) else { return false }
        return uniqueSizeLabels.contains { sizeIsComplete($0) }
    }

    // Returns names of fabrics that are missing dimensions for the active size tab.
    // Used to surface exactly which fabric rows still need input.
    private var missingDimFabricNames: [String] {
        guard !selectedFabricIds.isEmpty, !activeSizeLabel.isEmpty else { return [] }
        return selectedFabricIds.compactMap { id -> String? in
            let hasLen = (fabricLengths[activeSizeLabel]?[id] ?? 0) > 0
            let hasWid = (fabricWidths[activeSizeLabel]?[id] ?? 0) > 0
            guard !hasLen || !hasWid else { return nil }
            return fabrics.first { $0.id == id }?.name
        }
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
        NavigationStack {
            Form {
                // Produk & Ukuran
                Section {
                    InlineSearchDropdownField(
                        label: "Produk",
                        selectedId: $selectedProductId,
                        selectedName: $selectedProductName,
                        items: products.filter { !$0.isArchived }.map { (id: $0.id, name: $0.name) },
                        onCreateNew: { name in
                            pendingNewProductName = name
                            showNewProductSheet = true
                        }
                    )
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .onChange(of: selectedProductId) { _, _ in
                        activeSizeLabel = uniqueSizeLabels.first ?? ""
                        fabricLengths = [:]
                        fabricWidths = [:]
                        fabricRotations = [:]
                    }

                    if selectedProductId != nil {
                        tipeResepSelector
                            .listRowBackground(OuraTheme.Colors.surfaceCard)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        sizePickerRow
                            .listRowBackground(OuraTheme.Colors.surfaceCard)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                } header: {
                    OuraSectionHeader(title: "Produk & Ukuran")
                }
                .listSectionSeparator(.hidden)

                // Kain (shared picker, dimensions keyed by active size tab)
                if !activeSizeLabel.isEmpty {
                    Section {
                        TokenizedMultiSelectField(
                            label: "Kain yang Digunakan",
                            selectedIds: $selectedFabricIds,
                            items: fabrics.map { (id: $0.id, name: $0.name) },
                            placeholder: "Pilih kain (opsional)"
                        )
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .onChange(of: selectedFabricIds) { _, _ in
                            propagateGroupDimensions()
                        }

                        ForEach(fabricGroups) { group in
                            let repId = group.fabIds[0]
                            let displayName = group.isGrouped
                                ? "\(group.family!) (\(group.fabIds.count) warna)"
                                : (fabrics.first { $0.id == repId }?.name ?? "")
                            let rowHasLen = (fabricLengths[activeSizeLabel]?[repId] ?? 0) > 0
                            let rowHasWid = (fabricWidths[activeSizeLabel]?[repId] ?? 0) > 0
                            let rowIncomplete = !rowHasLen || !rowHasWid
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Text(displayName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(rowIncomplete ? OuraTheme.Colors.warningText : OuraTheme.Colors.textSecondary)
                                    if rowIncomplete {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(OuraTheme.Colors.warningText)
                                    }
                                }
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

                        if !missingDimFabricNames.isEmpty && missingDimFabricNames.count < selectedFabricIds.count {
                            Text("Isi dimensi untuk: \(missingDimFabricNames.joined(separator: ", "))")
                                .font(.system(size: 12))
                                .foregroundStyle(OuraTheme.Colors.warningText)
                                .listRowBackground(OuraTheme.Colors.warningBg)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
                            items: allMaterials
                                .filter { $0.category == .hardware || $0.category == .packaging }
                                .map { (id: $0.id, name: $0.name) },
                            placeholder: "Pilih bahan tambahan (opsional)"
                        )
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                        ForEach(selectedComponentIds, id: \.self) { matId in
                            let mat = allMaterials.first { $0.id == matId }
                            let name = mat?.name ?? ""
                            let unit = mat?.usageUnit ?? "pcs"
                            NumericInputField(
                                label: "\(name) per unit (\(unit))",
                                value: Binding(
                                    get: { componentQtys[matId] },
                                    set: { componentQtys[matId] = $0 }
                                ),
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

                if let err = errorMsg {
                    Section {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.dangerText)
                            .listRowBackground(OuraTheme.Colors.dangerBg)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OuraTheme.Colors.background)
            .navigationTitle("Tambah Resep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        if hasChanges { showDiscardAlert = true } else { dismiss() }
                    }
                    .foregroundStyle(OuraTheme.Colors.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Simpan") { Task { await save() } }
                            .foregroundStyle(canSave ? OuraTheme.Colors.accent : OuraTheme.Colors.textDisabled)
                            .disabled(!canSave || isSaving)
                    }
                }
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .task { await loadData() }
        .alert("Buang perubahan?", isPresented: $showDiscardAlert) {
            Button("Batal", role: .cancel) {}
            Button("Buang", role: .destructive) { dismiss() }
        } message: {
            Text("Data yang sudah diisi akan hilang.")
        }
        .alert("Tambah Ukuran Baru", isPresented: $showAddSizeAlert) {
            TextField("contoh: S, M, L, Free Size", text: $newSizeLabelInput)
                .autocorrectionDisabled()
            Button("Tambah") {
                let label = newSizeLabelInput.trimmingCharacters(in: .whitespaces)
                newSizeLabelInput = ""
                guard !label.isEmpty else { return }
                Task { await addNewSize(label: label) }
            }
            Button("Batal", role: .cancel) { newSizeLabelInput = "" }
        } message: {
            Text("Untuk produk \(selectedProductName)")
        }
        .sheet(isPresented: $showNewProductSheet) {
            TambahProdukCepatSheet(initialName: pendingNewProductName) { product, sizes in
                products.append(product)
                allSizes.append(contentsOf: sizes)
                selectedProductId = product.id
                selectedProductName = product.name
                activeSizeLabel = sizes.first?.sizeLabel ?? ""
            }
        }
    }

    // MARK: - Tipe Resep selector

    private var tipeResepSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tipe Resep")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
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

    // MARK: - Size tab picker row

    private var sizePickerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ukuran")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(uniqueSizeLabels, id: \.self) { label in
                        let isActive = activeSizeLabel == label
                        let isDone = sizeIsComplete(label)
                        Button {
                            activeSizeLabel = label
                        } label: {
                            HStack(spacing: 4) {
                                if isDone {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                Text(label)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(
                                isActive ? .white :
                                isDone   ? OuraTheme.Colors.accent :
                                           OuraTheme.Colors.textSecondary
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                isActive ? OuraTheme.Colors.accent :
                                isDone   ? OuraTheme.Colors.accentLight :
                                           OuraTheme.Colors.surfaceSheet
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    isActive ? Color.clear :
                                    isDone   ? OuraTheme.Colors.accent.opacity(0.35) :
                                               OuraTheme.Colors.border,
                                    lineWidth: 1
                                )
                            )
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: activeSizeLabel)
                        .animation(.easeInOut(duration: 0.15), value: isDone)
                    }

                    Button {
                        showAddSizeAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            if isCreatingSize {
                                ProgressView().scaleEffect(0.65).tint(OuraTheme.Colors.accent)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text("Ukuran Baru")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(OuraTheme.Colors.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(OuraTheme.Colors.accentLight)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(OuraTheme.Colors.accent.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(isCreatingSize)
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func addNewSize(label: String) async {
        guard let product = selectedProduct else { return }
        isCreatingSize = true
        defer { isCreatingSize = false }
        do {
            let newSize = try await api.createProductSize(sku: product.sku, sizeLabel: label)
            allSizes.append(newSize)
            activeSizeLabel = newSize.sizeLabel
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func propagateGroupDimensions() {
        for group in fabricGroups {
            guard let repId = group.fabIds.first else { continue }
            for sizeLabel in uniqueSizeLabels {
                guard let repLen = fabricLengths[sizeLabel]?[repId], repLen > 0 else { continue }
                let repWid = fabricWidths[sizeLabel]?[repId] ?? 0
                let repRot = fabricRotations[sizeLabel]?[repId] ?? true
                var lenDict = fabricLengths[sizeLabel] ?? [:]
                var widDict = fabricWidths[sizeLabel] ?? [:]
                var rotDict = fabricRotations[sizeLabel] ?? [:]
                for id in group.fabIds {
                    if (lenDict[id] ?? 0) == 0 { lenDict[id] = repLen }
                    if (widDict[id] ?? 0) == 0 { widDict[id] = repWid }
                    if rotDict[id] == nil { rotDict[id] = repRot }
                }
                fabricLengths[sizeLabel] = lenDict
                fabricWidths[sizeLabel] = widDict
                fabricRotations[sizeLabel] = rotDict
            }
        }
    }

    private func loadData() async {
        async let prods = api.getProducts()
        async let sizes = api.getAllProductSizes()
        async let mats  = api.getMaterials()

        products    = (try? await prods) ?? []
        allSizes    = (try? await sizes) ?? []
        allMaterials = ((try? await mats) ?? []).filter { !$0.isArchived }
        fabrics     = allMaterials.filter { $0.category == .fabric }
    }

    private func save() async {
        let completedLabels = uniqueSizeLabels.filter { sizeIsComplete($0) }
        guard !completedLabels.isEmpty else {
            errorMsg = "Isi dimensi kain untuk setidaknya satu ukuran."; return
        }

        let incomplComps = selectedComponentIds.filter { id in (componentQtys[id] ?? 0) <= 0 }
        if !incomplComps.isEmpty {
            let names = incomplComps.compactMap { id in allMaterials.first { $0.id == id }?.name }.joined(separator: ", ")
            errorMsg = "Isi jumlah untuk bahan tambahan: \(names)"
            return
        }

        guard (laborMinutes ?? 0) > 0 else {
            errorMsg = "Isi estimasi waktu kerja (menit)."; return
        }

        isSaving = true
        errorMsg = nil
        defer { isSaving = false }

        let components = selectedComponentIds.map { matId in
            CreatePatternSpecRequest.ComponentInput(materialId: matId, qtyPerUnit: componentQtys[matId] ?? 0)
        }

        do {
            if isFabricVariant {
                // Varian Kain: one spec per (size × fabric), each in its own ProductSize
                for sizeLabel in completedLabels {
                    for fabId in selectedFabricIds {
                        guard let fabric = fabrics.first(where: { $0.id == fabId }) else { continue }
                        let existingVariant = allSizes.first {
                            $0.productId == selectedProduct!.id &&
                            $0.sizeLabel == sizeLabel && $0.fabricVariantName == fabric.name
                        }
                        let targetSizeId: UUID
                        if let existing = existingVariant {
                            targetSizeId = existing.id
                        } else {
                            let newSize = try await api.createProductSize(
                                sku: selectedProduct!.sku,
                                sizeLabel: sizeLabel,
                                fabricVariantName: fabric.name
                            )
                            allSizes.append(newSize)
                            targetSizeId = newSize.id
                        }
                        let fabricInput = CreatePatternSpecRequest.FabricInput(
                            materialId: fabId,
                            cutLengthCm: fabricLengths[sizeLabel]?[fabId] ?? 0,
                            cutWidthCm: fabricWidths[sizeLabel]?[fabId] ?? 0,
                            rotationAllowed: fabricRotations[sizeLabel]?[fabId] ?? true
                        )
                        _ = try await api.createOrUpdatePatternSpec(CreatePatternSpecRequest(
                            productSizeId: targetSizeId,
                            fabrics: [fabricInput],
                            estLaborMinutes: laborMinutes ?? 0,
                            components: components
                        ))
                    }
                }
            } else {
                // Kombo Kain: all fabrics in one spec per base size
                for sizeLabel in completedLabels {
                    guard let size = sizesForProduct.first(where: { $0.sizeLabel == sizeLabel }) else { continue }
                    let fabricInputs = selectedFabricIds.map { fabId in
                        CreatePatternSpecRequest.FabricInput(
                            materialId: fabId,
                            cutLengthCm: fabricLengths[sizeLabel]?[fabId] ?? 0,
                            cutWidthCm: fabricWidths[sizeLabel]?[fabId] ?? 0,
                            rotationAllowed: fabricRotations[sizeLabel]?[fabId] ?? true
                        )
                    }
                    _ = try await api.createOrUpdatePatternSpec(CreatePatternSpecRequest(
                        productSizeId: size.id,
                        fabrics: fabricInputs,
                        estLaborMinutes: laborMinutes ?? 0,
                        components: components
                    ))
                }
            }
            dismiss()
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

// MARK: - Quick product + size creation sheet

private struct TambahProdukCepatSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let initialName: String
    let onCreated: (Product, [ProductSizeDetail]) -> Void

    @State private var productName: String = ""
    @State private var skuCode: String = ""
    @State private var selectedSizes: [String] = ["Free Size"]
    @State private var isSaving = false
    @State private var errorMsg: String?
    @State private var showCustomSizeAlert = false
    @State private var customSizeInput = ""

    private let presets: [(label: String, sizes: [String])] = [
        ("Free Size", ["Free Size"]),
        ("XS – XXL", ["XS", "S", "M", "L", "XL", "XXL"]),
        ("S – XXL",  ["S", "M", "L", "XL", "XXL"]),
    ]

    private var canCreate: Bool {
        !productName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !skuCode.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedSizes.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Produk Baru")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(OuraTheme.Colors.surfaceSheet)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(OuraTheme.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().overlay(OuraTheme.Colors.separator)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    fieldGroup(label: "Nama Produk") {
                        TextField("contoh: Scrunchie Mini", text: $productName)
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                            .autocorrectionDisabled()
                            .onChange(of: productName) { _, val in
                                skuCode = Self.autoSKU(from: val)
                            }
                            .inputFieldStyle()
                    }

                    fieldGroup(label: "Kode SKU") {
                        TextField("contoh: SCRMINI", text: $skuCode)
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .inputFieldStyle()
                        Text("Kode unik singkat untuk produk ini. Tidak bisa diubah setelah dibuat.")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }

                    fieldGroup(label: "Ukuran") {
                        // Preset group chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presets, id: \.label) { preset in
                                    let isActive = preset.sizes == selectedSizes
                                    Button {
                                        selectedSizes = preset.sizes
                                    } label: {
                                        Text(preset.label)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(isActive ? OuraTheme.Colors.accent : OuraTheme.Colors.textSecondary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(isActive ? OuraTheme.Colors.accentLight : OuraTheme.Colors.surfaceSheet)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(
                                                isActive ? OuraTheme.Colors.accent.opacity(0.4) : OuraTheme.Colors.border,
                                                lineWidth: 1
                                            ))
                                    }
                                    .buttonStyle(.plain)
                                    .animation(.easeInOut(duration: 0.15), value: selectedSizes)
                                }
                            }
                        }

                        // Active size tokens
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
                                        .padding(.leading, 10)
                                        .padding(.trailing, 8)
                                        .padding(.vertical, 6)
                                        .background(OuraTheme.Colors.surfaceCard)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(OuraTheme.Colors.border, lineWidth: 1))
                                    }
                                }
                            }
                        }

                        // Custom size add button
                        Button {
                            showCustomSizeAlert = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Ukuran Kustom")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(OuraTheme.Colors.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(OuraTheme.Colors.accentLight)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(OuraTheme.Colors.accent.opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Text("Bisa tambah ukuran lain nanti di Tab Produk.")
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
                Button {
                    Task { await createProduct() }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Buat Produk")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canCreate ? OuraTheme.Colors.accentGradient : LinearGradient(colors: [OuraTheme.Colors.border], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                }
                .buttonStyle(.plain)
                .disabled(!canCreate || isSaving)
                .padding(16)
            }
            .background(OuraTheme.Colors.background)
        }
        .background(OuraTheme.Colors.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            productName = initialName
            skuCode = Self.autoSKU(from: initialName)
        }
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

    private func createProduct() async {
        isSaving = true
        errorMsg = nil
        defer { isSaving = false }

        let name = productName.trimmingCharacters(in: .whitespaces)
        let sku  = skuCode.trimmingCharacters(in: .whitespaces).uppercased()

        do {
            let product = try await api.createProduct(name: name, sku: sku)
            var sizeDetails: [ProductSizeDetail] = []
            for label in selectedSizes {
                let detail = try await api.createProductSize(sku: product.sku, sizeLabel: label)
                sizeDetails.append(detail)
            }
            onCreated(product, sizeDetails)
            dismiss()
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    static func autoSKU(from name: String) -> String {
        // Take up to 3 alphanumeric chars from each word, then cap at 8.
        // "Scrunchie Waffle Merah" → "SCR"+"WAF"+"MER" = "SCRWAFME"
        // "Scrunchie Satin" → "SCR"+"SAT" = "SCRSAT"
        // Much less collision-prone than taking first 8 chars of the full name.
        let words = name.uppercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        let parts = words.map { word in
            String(word.filter { $0.isLetter || $0.isNumber }.prefix(3))
        }
        return String(parts.joined().prefix(8))
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
