import SwiftUI

private struct FabricGroup: Identifiable {
    let family: String?
    let fabIds: [UUID]
    var id: String { family ?? fabIds.map { $0.uuidString }.joined(separator: "-") }
    var isGrouped: Bool { family != nil && fabIds.count > 1 }
}

struct ResepEditorView: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let specs: [PatternSpec]
    var onUpdate: (() -> Void)?

    @State private var currentSpecs: [PatternSpec]
    @State private var isEditing = false
    @State private var showVersionHistory = false
    @State private var showDeleteAlert = false
    @State private var isSaving = false
    @State private var errorMsg: String?

    // Fabric edit state
    @State private var allMaterials: [Material] = []
    @State private var editFabricIds: [UUID] = []
    @State private var fabricLengths: [UUID: Double] = [:]
    @State private var fabricWidths: [UUID: Double] = [:]
    @State private var fabricRotations: [UUID: Bool] = [:]
    @State private var editLaborMinutes: Double?

    // Component edit state
    @State private var editComponentIds: [UUID] = []
    @State private var componentQtys: [UUID: Double] = [:]

    init(specs: [PatternSpec], onUpdate: (() -> Void)? = nil) {
        self.specs = specs
        self.onUpdate = onUpdate
        self._currentSpecs = State(initialValue: specs)
    }

    private var representative: PatternSpec { currentSpecs[0] }
    private var groupIsInPlaceEdit: Bool { currentSpecs.allSatisfy { $0.isInPlaceEdit } }
    private var groupCanDelete: Bool { currentSpecs.allSatisfy { $0.canDelete } }
    private var allCurrentFabrics: [PatternFabric] { currentSpecs.flatMap { $0.fabrics } }

    private var canSave: Bool {
        !editFabricIds.isEmpty
            && editFabricIds.allSatisfy { id in (fabricLengths[id] ?? 0) > 0 && (fabricWidths[id] ?? 0) > 0 }
            && editComponentIds.allSatisfy { id in (componentQtys[id] ?? 0) > 0 }
            && (editLaborMinutes ?? 0) > 0
    }

    private var editorFabricGroups: [FabricGroup] {
        var familyMap: [String: [UUID]] = [:]
        var ungrouped: [UUID] = []
        for fabId in editFabricIds {
            if let family = allMaterials.first(where: { $0.id == fabId })?.fabricFamily {
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
            detailTopBar
            Divider().overlay(OuraTheme.Colors.separator)

            ScrollView {
                VStack(alignment: .leading, spacing: OuraTheme.Spacing.sectionGap) {
                    headerCard
                    componentsCard

                    Button { showVersionHistory = true } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(OuraTheme.Colors.blueAccent)
                            Text("Riwayat Versi")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(OuraTheme.Colors.blueAccent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(OuraTheme.Colors.textTertiary)
                        }
                        .padding(16)
                        .ouraCard()
                    }
                    .buttonStyle(.plain)

                    if groupCanDelete {
                        Button { showDeleteAlert = true } label: {
                            Text("Hapus Resep Ini")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(OuraTheme.Colors.dangerText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }

                    if let err = errorMsg {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.dangerText)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, OuraTheme.Spacing.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }

            if isEditing {
                Divider().overlay(OuraTheme.Colors.separator)
                saveBottomBar
            }
        }
        .background(OuraTheme.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showVersionHistory) {
            ResepVersionHistoryView(
                productSizeId: representative.productSizeId,
                productName: representative.productName,
                sizeLabel: representative.sizeLabel
            )
        }
        .alert("Hapus Resep?", isPresented: $showDeleteAlert) {
            Button("Hapus", role: .destructive) { Task { await deleteSpecs() } }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Resep ini belum dipakai di produksi manapun dan akan dihapus permanen.")
        }
        .task { await loadMaterials() }
    }

    private var saveButtonLabel: String {
        groupIsInPlaceEdit ? "Simpan Perubahan" : "Simpan Versi Baru"
    }

    private var saveBottomBar: some View {
        Group {
            if isSaving {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                Button(saveButtonLabel) { Task { await saveEdits() } }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canSave ? .white : OuraTheme.Colors.textDisabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(canSave ? OuraTheme.Colors.accent : OuraTheme.Colors.border)
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                    .disabled(!canSave)
                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(OuraTheme.Colors.background)
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

            Text("\(representative.productName) · \(representative.sizeLabel)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isEditing {
                Button("Batalkan") {
                    errorMsg = nil
                    withAnimation { isEditing = false }
                }
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            } else {
                Button("Edit") { startEdit() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.accent)
            }
        }
        .padding(.horizontal, OuraTheme.Spacing.horizontal)
        .padding(.vertical, 10)
        .background(OuraTheme.Colors.background)
    }

    // MARK: - Header card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Detail Pola")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                if !representative.isActive {
                    OuraTag(text: "Tidak Aktif", color: OuraTheme.Colors.textTertiary, bg: OuraTheme.Colors.border)
                }
            }

            Divider().overlay(OuraTheme.Colors.separator)

            if isEditing {
                if !groupIsInPlaceEdit {
                    versioningNotice
                }

                let availableFabrics = allMaterials.filter { $0.category == .fabric && !$0.isArchived }
                TokenizedMultiSelectField(
                    label: "Kain yang Digunakan",
                    selectedIds: $editFabricIds,
                    items: availableFabrics.map { (id: $0.id, name: $0.name) },
                    placeholder: "Pilih kain (opsional)"
                )
                .onChange(of: editFabricIds) { _, newIds in
                    for id in newIds where fabricRotations[id] == nil {
                        fabricRotations[id] = true
                    }
                }

                ForEach(editorFabricGroups) { group in
                    let repId = group.fabIds[0]
                    let displayName = group.isGrouped
                        ? "\(group.family!) (\(group.fabIds.count) warna)"
                        : (allMaterials.first { $0.id == repId }?.name ?? "")
                    VStack(alignment: .leading, spacing: 8) {
                        Text(displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        HStack(spacing: 12) {
                            NumericInputField(
                                label: "Panjang (cm)",
                                value: Binding(
                                    get: { fabricLengths[repId] },
                                    set: { val in for id in group.fabIds { fabricLengths[id] = val } }
                                ),
                                unit: "cm"
                            )
                            NumericInputField(
                                label: "Lebar (cm)",
                                value: Binding(
                                    get: { fabricWidths[repId] },
                                    set: { val in for id in group.fabIds { fabricWidths[id] = val } }
                                ),
                                unit: "cm"
                            )
                        }
                        Toggle("Rotasi Diizinkan", isOn: Binding(
                            get: { fabricRotations[repId] ?? true },
                            set: { val in for id in group.fabIds { fabricRotations[id] = val } }
                        ))
                        .tint(OuraTheme.Colors.accent)
                        .font(.system(size: 13))
                    }
                    .padding(.vertical, 4)
                    Divider().overlay(OuraTheme.Colors.separator)
                }

                NumericInputField(label: "Estimasi Kerja (menit)", value: $editLaborMinutes, unit: "min")

            } else {
                // Display mode — show fabrics grouped by family
                if allCurrentFabrics.isEmpty {
                    infoRow("Kain", value: "Tanpa Kain")
                } else {
                    let displayItems = fabricDisplayItems(allCurrentFabrics)
                    ForEach(Array(displayItems.enumerated()), id: \.offset) { idx, item in
                        infoRow("Kain", value: item.label)
                        infoRow("Dimensi", value: item.dims)
                        infoRow("Rotasi", value: item.rotation)
                        if idx < displayItems.count - 1 {
                            Divider().overlay(OuraTheme.Colors.separator).padding(.vertical, 2)
                        }
                    }
                }
                infoRow("Est. Kerja", value: String(format: "%.0f menit", representative.estLaborMinutes))
            }

            Divider().overlay(OuraTheme.Colors.separator)
            infoRow("Aktif Sejak", value: representative.effectiveFrom.formatted(.dateTime.day().month().year()))
            if let to = representative.effectiveTo {
                infoRow("Berlaku Hingga", value: to.formatted(.dateTime.day().month().year()))
            }
            let totalUsed = currentSpecs.map { $0.usedInBatchCount }.max() ?? 0
            infoRow("Dipakai di", value: "\(totalUsed) produksi")
        }
        .padding(OuraTheme.Spacing.cardPad)
        .ouraCard()
    }

    private var versioningNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.blueAccent)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("Versi Baru Akan Dibuat")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.blueAccent)
                let maxUsed = currentSpecs.map { $0.usedInBatchCount }.max() ?? 0
                Text("Resep ini aktif sejak \(representative.effectiveFrom.formatted(.dateTime.day().month().year())) dan sudah dipakai di \(maxUsed) produksi. Batch sebelumnya tetap memakai biaya versi lama.")
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(OuraTheme.Colors.blueBg.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundStyle(OuraTheme.Colors.blueAccent.opacity(0.45))
        )
    }

    // MARK: - Components card

    private var componentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            OuraSectionHeader(title: "Komponen Bahan")

            if isEditing {
                let nonFabrics = allMaterials.filter { ($0.category == .hardware || $0.category == .packaging) && !$0.isArchived }
                TokenizedMultiSelectField(
                    label: "Bahan Tambahan",
                    selectedIds: $editComponentIds,
                    items: nonFabrics.map { (id: $0.id, name: $0.name) },
                    placeholder: "Pilih bahan tambahan (opsional)"
                )

                ForEach(editComponentIds, id: \.self) { matId in
                    let mat  = allMaterials.first { $0.id == matId }
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
                }
            } else {
                if representative.components.isEmpty {
                    Text("Tidak ada komponen tambahan")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                } else {
                    ForEach(representative.components) { comp in
                        let unit = allMaterials.first { $0.id == comp.materialId }?.usageUnit ?? "pcs"
                        HStack {
                            Text(comp.materialName)
                                .font(.system(size: 14))
                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                            Spacer()
                            Text("\(comp.qtyPerUnit, specifier: "%.2g") \(unit)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(OuraTheme.Colors.textSecondary)
                        }
                        .padding(.vertical, 2)
                        if comp.id != representative.components.last?.id {
                            Divider().overlay(OuraTheme.Colors.separator)
                        }
                    }
                }
            }
        }
        .padding(OuraTheme.Spacing.cardPad)
        .ouraCard()
    }

    private struct FabricDisplayItem {
        let label: String
        let dims: String
        let rotation: String
    }

    private func fabricDisplayItems(_ fabrics: [PatternFabric]) -> [FabricDisplayItem] {
        var seen = Set<String>()
        var result: [FabricDisplayItem] = []
        for fabric in fabrics {
            if let fam = fabric.fabricFamily {
                guard seen.insert(fam).inserted else { continue }
                let count = fabrics.filter { $0.fabricFamily == fam }.count
                let label = count > 1 ? "\(fam) (\(count) warna)" : fam
                result.append(FabricDisplayItem(
                    label: label,
                    dims: String(format: "%.0f × %.0f cm", fabric.cutLengthCm, fabric.cutWidthCm),
                    rotation: fabric.rotationAllowed ? "Diizinkan" : "Tidak"
                ))
            } else {
                result.append(FabricDisplayItem(
                    label: fabric.materialName,
                    dims: String(format: "%.0f × %.0f cm", fabric.cutLengthCm, fabric.cutWidthCm),
                    rotation: fabric.rotationAllowed ? "Diizinkan" : "Tidak"
                ))
            }
        }
        return result
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
        }
    }

    // MARK: - Actions

    private func startEdit() {
        let fabrics = representative.fabrics
        editFabricIds    = fabrics.map { $0.materialId }
        fabricLengths    = Dictionary(uniqueKeysWithValues: fabrics.map { ($0.materialId, $0.cutLengthCm) })
        fabricWidths     = Dictionary(uniqueKeysWithValues: fabrics.map { ($0.materialId, $0.cutWidthCm) })
        fabricRotations  = Dictionary(uniqueKeysWithValues: fabrics.map { ($0.materialId, $0.rotationAllowed) })
        editLaborMinutes = representative.estLaborMinutes
        editComponentIds = representative.components.map { $0.materialId }
        componentQtys    = Dictionary(uniqueKeysWithValues: representative.components.map { ($0.materialId, $0.qtyPerUnit) })
        withAnimation { isEditing = true }
    }

    private func saveEdits() async {
        let incomplFabrics = editFabricIds.filter { id in
            (fabricLengths[id] ?? 0) <= 0 || (fabricWidths[id] ?? 0) <= 0
        }
        if !incomplFabrics.isEmpty {
            let names = incomplFabrics
                .compactMap { id in allMaterials.first { $0.id == id }?.name }
                .joined(separator: ", ")
            errorMsg = "Isi dimensi panjang dan lebar untuk kain: \(names)"
            return
        }

        let incomplComps = editComponentIds.filter { id in (componentQtys[id] ?? 0) <= 0 }
        if !incomplComps.isEmpty {
            let names = incomplComps
                .compactMap { id in allMaterials.first { $0.id == id }?.name }
                .joined(separator: ", ")
            errorMsg = "Isi jumlah untuk bahan tambahan: \(names)"
            return
        }

        isSaving = true
        errorMsg = nil
        defer { isSaving = false }

        do {
            guard !editFabricIds.isEmpty else {
                throw APIError.serverError(400, "Pilih setidaknya satu kain untuk resep ini.")
            }
            let compInputs = editComponentIds.map { matId in
                CreatePatternSpecRequest.ComponentInput(materialId: matId, qtyPerUnit: componentQtys[matId] ?? 0)
            }
            let fabricInputs = editFabricIds.map { fabId in
                CreatePatternSpecRequest.FabricInput(
                    materialId: fabId,
                    cutLengthCm: fabricLengths[fabId] ?? 0,
                    cutWidthCm: fabricWidths[fabId] ?? 0,
                    rotationAllowed: fabricRotations[fabId] ?? true
                )
            }
            let req = CreatePatternSpecRequest(
                productSizeId: representative.productSizeId,
                fabrics: fabricInputs,
                estLaborMinutes: editLaborMinutes ?? representative.estLaborMinutes,
                components: compInputs
            )
            let updated = try await api.createOrUpdatePatternSpec(req)
            currentSpecs = [updated]
            onUpdate?()
            withAnimation { isEditing = false }
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func deleteSpecs() async {
        do {
            for spec in currentSpecs {
                try await api.deletePatternSpec(id: spec.id)
            }
            onUpdate?()
            dismiss()
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func loadMaterials() async {
        allMaterials = (try? await api.getMaterials()) ?? []
    }
}
