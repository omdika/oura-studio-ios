import SwiftUI

private struct FabricGroup: Identifiable {
    let family: String?
    let fabIds: [UUID]
    var id: String { family ?? fabIds.map { $0.uuidString }.joined(separator: "-") }
    var isGrouped: Bool { family != nil && fabIds.count > 1 }
}

struct EditResepSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let specGroups: [SpecGroup]
    let onUpdate: () -> Void

    private var productName: String { specGroups.first?.productName ?? "" }
    private var productSku: String { specGroups.first?.productSku ?? "" }

    @State private var allSizes: [ProductSizeDetail] = []
    @State private var fabrics: [Material] = []
    @State private var allMaterials: [Material] = []
    @State private var isLoading = true

    @State private var selectedFabricIds: [UUID] = []
    @State private var fabricLengths: [String: [UUID: Double]] = [:]
    @State private var fabricWidths: [String: [UUID: Double]] = [:]
    @State private var fabricRotations: [String: [UUID: Bool]] = [:]

    @State private var selectedComponentIds: [UUID] = []
    @State private var componentQtys: [UUID: Double] = [:]

    @State private var laborMinutes: Double?
    @State private var isFabricVariant = true
    @State private var activeSizeLabel: String = ""

    // fabricMaterialId → [specId] — used to deactivate removed fabrics on save
    @State private var existingSpecsByFabric: [UUID: [UUID]] = [:]

    @State private var isSaving = false
    @State private var errorMsg: String?
    @State private var showDiscardAlert = false

    @State private var showAddSizeAlert = false
    @State private var newSizeLabelInput = ""
    @State private var isCreatingSize = false

    private var sizesForProduct: [ProductSizeDetail] {
        allSizes.filter { $0.productSku == productSku }
    }

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
            ZStack {
                OuraTheme.Colors.background.ignoresSafeArea()
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Form {
                        productSection
                        if !activeSizeLabel.isEmpty {
                            kainSection
                            komponenSection
                            laborSection
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
                }
            }
            .navigationTitle("Edit Resep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { showDiscardAlert = true }
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
        .interactiveDismissDisabled(true)
        .task { await loadData() }
        .alert("Buang perubahan?", isPresented: $showDiscardAlert) {
            Button("Batal", role: .cancel) {}
            Button("Buang", role: .destructive) { dismiss() }
        } message: {
            Text("Perubahan yang belum disimpan akan hilang.")
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
            Text("Untuk produk \(productName)")
        }
    }

    // MARK: - Sections

    private var productSection: some View {
        Section {
            HStack {
                Text("Produk")
                    .font(.system(size: 15))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                Spacer()
                Text(productName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
            }
            .listRowBackground(OuraTheme.Colors.surfaceCard)
            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))

            tipeResepDisplay
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

            sizePickerRow
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        } header: {
            OuraSectionHeader(title: "Produk & Ukuran")
        }
        .listSectionSeparator(.hidden)
    }

    private var kainSection: some View {
        Section {
            TokenizedMultiSelectField(
                label: "Kain yang Digunakan",
                selectedIds: $selectedFabricIds,
                items: fabrics.map { (id: $0.id, name: $0.name) },
                placeholder: "Pilih kain (opsional)"
            )
            .listRowBackground(OuraTheme.Colors.surfaceCard)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .onChange(of: selectedFabricIds) { _ in
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
    }

    private var komponenSection: some View {
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
    }

    private var laborSection: some View {
        Section {
            NumericInputField(label: "Est. Waktu Kerja", value: $laborMinutes, unit: "menit")
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        } header: {
            OuraSectionHeader(title: "Tenaga Kerja")
        }
        .listSectionSeparator(.hidden)
    }

    // MARK: - Tipe Resep (read-only)

    private var tipeResepDisplay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tipe Resep")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            HStack(spacing: 6) {
                Text(isFabricVariant ? "Varian Kain" : "Kombo Kain")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.accent)
                Text("· tidak dapat diubah")
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Size tab picker

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
                        Button { activeSizeLabel = label } label: {
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

                    Button { showAddSizeAlert = true } label: {
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

    // MARK: - Data loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        async let sizesTask = api.getAllProductSizes()
        async let matsTask = api.getMaterials()

        allSizes = (try? await sizesTask) ?? []
        allMaterials = ((try? await matsTask) ?? []).filter { !$0.isArchived }
        fabrics = allMaterials.filter { $0.category == .fabric }

        populateFromSpecs()
    }

    private func populateFromSpecs() {
        let allSpecs = specGroups.flatMap { $0.specs }
        guard !allSpecs.isEmpty else { return }

        isFabricVariant = allSpecs.allSatisfy { $0.fabrics.count == 1 }

        let firstSpec = allSpecs[0]
        laborMinutes = firstSpec.estLaborMinutes
        selectedComponentIds = firstSpec.components.map { $0.materialId }
        for comp in firstSpec.components {
            componentQtys[comp.materialId] = comp.qtyPerUnit
        }

        var fabricIdOrder = [UUID]()
        var seen = Set<UUID>()

        for specGroup in specGroups {
            for spec in specGroup.specs {
                let sizeLabel = spec.sizeLabel
                let fabricsInSpec = isFabricVariant
                    ? (spec.fabrics.first.map { [$0] } ?? [])
                    : spec.fabrics

                for fabric in fabricsInSpec {
                    let mid = fabric.materialId
                    if seen.insert(mid).inserted { fabricIdOrder.append(mid) }

                    var lenDict = fabricLengths[sizeLabel] ?? [:]
                    var widDict = fabricWidths[sizeLabel] ?? [:]
                    var rotDict = fabricRotations[sizeLabel] ?? [:]
                    lenDict[mid] = fabric.cutLengthCm
                    widDict[mid] = fabric.cutWidthCm
                    rotDict[mid] = fabric.rotationAllowed
                    fabricLengths[sizeLabel] = lenDict
                    fabricWidths[sizeLabel] = widDict
                    fabricRotations[sizeLabel] = rotDict

                    if isFabricVariant {
                        existingSpecsByFabric[mid, default: []].append(spec.id)
                    }
                }
            }
        }

        selectedFabricIds = fabricIdOrder
        activeSizeLabel = uniqueSizeLabels.first ?? ""
    }

    private func addNewSize(label: String) async {
        isCreatingSize = true
        defer { isCreatingSize = false }
        do {
            let newSize = try await api.createProductSize(sku: productSku, sizeLabel: label)
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

    // MARK: - Save

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
                for sizeLabel in completedLabels {
                    for fabId in selectedFabricIds {
                        guard let fabric = fabrics.first(where: { $0.id == fabId }) else { continue }
                        let existingVariant = allSizes.first {
                            $0.productSku == productSku &&
                            $0.sizeLabel == sizeLabel && $0.fabricVariantName == fabric.name
                        }
                        let targetSizeId: UUID
                        if let existing = existingVariant {
                            targetSizeId = existing.id
                        } else {
                            let newSize = try await api.createProductSize(
                                sku: productSku,
                                sizeLabel: sizeLabel,
                                fabricVariantName: fabric.name
                            )
                            allSizes.append(newSize)
                            targetSizeId = newSize.id
                        }
                        _ = try await api.createOrUpdatePatternSpec(CreatePatternSpecRequest(
                            productSizeId: targetSizeId,
                            fabrics: [CreatePatternSpecRequest.FabricInput(
                                materialId: fabId,
                                cutLengthCm: fabricLengths[sizeLabel]?[fabId] ?? 0,
                                cutWidthCm: fabricWidths[sizeLabel]?[fabId] ?? 0,
                                rotationAllowed: fabricRotations[sizeLabel]?[fabId] ?? true
                            )],
                            estLaborMinutes: laborMinutes ?? 0,
                            components: components
                        ))
                    }
                }

                // Deactivate specs for fabrics removed from selection
                let removedFabricIds = Set(existingSpecsByFabric.keys).subtracting(Set(selectedFabricIds))
                for fabId in removedFabricIds {
                    for specId in (existingSpecsByFabric[fabId] ?? []) {
                        try await api.deactivatePatternSpec(id: specId)
                    }
                }
            } else {
                // Kombo Kain: one spec per base size with all fabrics
                for sizeLabel in completedLabels {
                    guard let size = sizesForProduct.first(where: {
                        $0.sizeLabel == sizeLabel && $0.fabricVariantName == nil
                    }) else { continue }
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

            onUpdate()
            dismiss()
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
