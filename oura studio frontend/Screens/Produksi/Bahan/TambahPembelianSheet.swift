import SwiftUI

struct TambahPembelianSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let preselectedMaterial: Material?

    // Material selection
    @State private var materials: [Material] = []
    @State private var selectedMaterialId: UUID?
    @State private var selectedMaterialName: String = ""
    @State private var selectedMaterial: Material?

    // New material inline creation
    @State private var isCreatingNew = false
    @State private var newMaterialName: String = ""
    @State private var newMaterialCategory: MaterialCategory? = nil
    @State private var newFabricWidthCm: Double? = nil
    @State private var newFabricFamily: String = ""

    // Fabric family edit for existing selected material
    @State private var editFabricFamily: String = ""
    @State private var originalFabricFamily: String = ""

    // Purchase fields
    @State private var widthCm: Double? = nil
    @State private var lengthCm: Double? = nil
    @State private var qty: Double? = nil
    @State private var threadPackageSize: String? = nil

    @State private var totalCost: Double? = nil
    @State private var purchasedAt: Date = Date()

    // Supplier
    @State private var suppliers: [Supplier] = []
    @State private var selectedSupplierId: UUID? = nil
    @State private var selectedSupplierName: String = ""

    // UI
    @State private var isSaving = false
    @State private var errorMsg: String?
    @State private var showDiscardAlert = false
    @State private var showNewMaterialAlert = false
    @State private var newMaterialNameInput = ""
    @State private var showNewSupplierAlert = false
    @State private var newSupplierNameInput = ""

    // MARK: - Computed

    private var resolvedMaterial: Material? { preselectedMaterial ?? selectedMaterial }

    private var existingFabricFamilies: [String] {
        let fams = materials
            .filter { $0.category == .fabric }
            .compactMap { $0.fabricFamily }
        var seen = Set<String>()
        return fams.filter { seen.insert($0).inserted }.sorted()
    }

    private var effectiveCategory: MaterialCategory? {
        resolvedMaterial?.category ?? (isCreatingNew ? newMaterialCategory : nil)
    }

    private var isFabric:   Bool { effectiveCategory == .fabric }
    private var isThread:   Bool { effectiveCategory == .thread }

    private var hasEdits: Bool {
        selectedMaterialId != nil || isCreatingNew
            || (widthCm ?? 0) > 0 || (lengthCm ?? 0) > 0
            || (qty ?? 0) > 0 || (totalCost ?? 0) > 0
            || !selectedSupplierName.isEmpty
    }

    private var canSave: Bool {
        let hasMaterial = resolvedMaterial != nil ||
            (isCreatingNew && !newMaterialName.isEmpty && newMaterialCategory != nil)
        let hasDimension: Bool
        if isFabric {
            hasDimension = (widthCm ?? 0) > 0 && (lengthCm ?? 0) > 0
        } else {
            hasDimension = (qty ?? 0) > 0
        }
        return hasMaterial && hasDimension && (totalCost ?? 0) > 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                bahanSection
                if resolvedMaterial != nil || isCreatingNew {
                    detailSection
                    biayaInfoSection
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
            .navigationTitle("Tambah Pembelian")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        if hasEdits { showDiscardAlert = true }
                        else { dismiss() }
                    }
                    .foregroundStyle(OuraTheme.Colors.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(OuraTheme.Colors.accent)
                    } else {
                        Button("Simpan") { Task { await save() } }
                            .foregroundStyle(canSave ? OuraTheme.Colors.accent : OuraTheme.Colors.textDisabled)
                            .disabled(!canSave)
                    }
                }
            }
            .alert("Buang perubahan?", isPresented: $showDiscardAlert) {
                Button("Batal", role: .cancel) {}
                Button("Buang", role: .destructive) { dismiss() }
            } message: {
                Text("Data yang sudah diisi akan hilang.")
            }
            .alert("Tambah Bahan Baru", isPresented: $showNewMaterialAlert) {
                TextField("Nama bahan", text: $newMaterialNameInput)
                Button("Tambah") {
                    let n = newMaterialNameInput.trimmingCharacters(in: .whitespaces)
                    if !n.isEmpty {
                        newMaterialName = n
                        isCreatingNew = true
                        selectedMaterialId = nil
                        selectedMaterialName = ""
                        widthCm = nil
                    }
                    newMaterialNameInput = ""
                }
                Button("Batal", role: .cancel) { newMaterialNameInput = "" }
            } message: {
                Text("Ketik nama bahan yang ingin ditambahkan.")
            }
            .alert("Tambah Supplier Baru", isPresented: $showNewSupplierAlert) {
                TextField("Nama supplier", text: $newSupplierNameInput)
                Button("Tambah") {
                    let n = newSupplierNameInput.trimmingCharacters(in: .whitespaces)
                    if !n.isEmpty {
                        Task {
                            let s = try? await api.createSupplier(name: n)
                            if let s {
                                suppliers.append(s)
                                selectedSupplierId = s.id
                                selectedSupplierName = s.name
                            }
                        }
                    }
                    newSupplierNameInput = ""
                }
                Button("Batal", role: .cancel) { newSupplierNameInput = "" }
            } message: {
                Text("Ketik nama supplier yang ingin ditambahkan.")
            }
        }
        .task { await loadData() }
    }

    // MARK: - Bahan section

    @ViewBuilder
    private var bahanSection: some View {
        if let pre = preselectedMaterial {
            // Pre-selected from Detail — locked
            Section {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pre.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                        Text(pre.category.displayName)
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            } header: {
                OuraSectionHeader(title: "Bahan")
            }
            .listSectionSeparator(.hidden)

        } else if isCreatingNew {
            // New material — locked display + category/width fields
            Section {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(newMaterialName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                            OuraTag(text: "Baru",
                                    color: OuraTheme.Colors.blueAccent,
                                    bg: OuraTheme.Colors.blueBg)
                        }
                        Text("Bahan baru — belum tersimpan")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }
                    Spacer()
                    Button("Ubah") {
                        isCreatingNew = false
                        newMaterialName = ""
                        newMaterialCategory = nil
                        newFabricWidthCm = nil
                        widthCm = nil
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.accent)
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                ChipSingleSelect(
                    label: "Kategori",
                    selected: $newMaterialCategory,
                    options: MaterialCategory.allCases.map { (value: $0, title: $0.displayName) }
                )
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                if newMaterialCategory == .fabric {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Jenis Kain (opsional)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)

                        if !existingFabricFamilies.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(existingFabricFamilies, id: \.self) { family in
                                        Button {
                                            newFabricFamily = newFabricFamily == family ? "" : family
                                        } label: {
                                            Text(family)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(newFabricFamily == family
                                                    ? OuraTheme.Colors.accent
                                                    : OuraTheme.Colors.textSecondary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(newFabricFamily == family
                                                    ? OuraTheme.Colors.accentLight
                                                    : OuraTheme.Colors.background)
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(
                                                    newFabricFamily == family
                                                        ? OuraTheme.Colors.accent
                                                        : OuraTheme.Colors.border,
                                                    lineWidth: 0.75))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        TextField(existingFabricFamilies.isEmpty
                            ? "contoh: Satin, Waffle, Katun"
                            : "atau ketik nama family baru...",
                            text: $newFabricFamily)
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                            .autocorrectionDisabled()

                        Text("Kain sejenis dikelompokkan di form resep.")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }

            } header: {
                OuraSectionHeader(title: "Bahan Baru")
            }
            .listSectionSeparator(.hidden)

        } else {
            // Search / select / create
            Section {
                SearchableDropdownField(
                    label: "Bahan",
                    selectedId: $selectedMaterialId,
                    selectedName: $selectedMaterialName,
                    items: materials.map { (id: $0.id, name: $0.name) },
                    placeholder: "Pilih atau tambah bahan baru..."
                ) { name in
                    if name.isEmpty {
                        showNewMaterialAlert = true
                    } else {
                        newMaterialName = name
                        isCreatingNew = true
                        selectedMaterialId = nil
                        selectedMaterialName = ""
                        widthCm = nil
                    }
                }
                .onChange(of: selectedMaterialId) { id in
                    selectedMaterial = materials.first { $0.id == id }
                    isCreatingNew = false
                    widthCm = selectedMaterial?.fabricWidthCm
                    let family = selectedMaterial?.fabricFamily ?? ""
                    editFabricFamily = family
                    originalFabricFamily = family
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            } header: {
                OuraSectionHeader(title: "Bahan")
            }
            .listSectionSeparator(.hidden)
        }
    }

    // MARK: - Detail section

    @ViewBuilder
    private var detailSection: some View {
        Section {
            if isFabric {
                // Family kain hanya untuk existing selected material (new material punya field sendiri di atas)
                if !isCreatingNew && resolvedMaterial != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Jenis Kain (opsional)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        TextField("contoh: Satin, Waffle, Katun", text: $editFabricFamily)
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                            .autocorrectionDisabled()
                        Text("Kain sejenis dikelompokkan saat pilih bahan di form resep.")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }

                NumericInputField(label: "Lebar (cm)", value: $widthCm, unit: "cm")
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                NumericInputField(label: "Panjang (cm)", value: $lengthCm, unit: "cm")
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            } else if isThread {
                ChipSingleSelect(
                    label: "Ukuran Kemasan (opsional)",
                    selected: $threadPackageSize,
                    options: [
                        (value: "Kecil", title: "Kecil"),
                        (value: "Besar", title: "Besar"),
                    ]
                )
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                NumericInputField(label: "Jumlah (gulung)", value: $qty, unit: "gulung")
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            } else {
                NumericInputField(
                    label: "Jumlah",
                    value: $qty,
                    unit: resolvedMaterial?.purchaseUnit ?? "pcs"
                )
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
        } header: {
            OuraSectionHeader(title: "Detail Pembelian")
        }
        .listSectionSeparator(.hidden)
    }

    // MARK: - Biaya & Info section

    @ViewBuilder
    private var biayaInfoSection: some View {
        Section {
            CurrencyInputField(label: "Total Biaya", value: $totalCost)
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

            SearchableDropdownField(
                label: "Supplier (opsional)",
                selectedId: $selectedSupplierId,
                selectedName: $selectedSupplierName,
                items: suppliers.map { (id: $0.id, name: $0.name) },
                placeholder: "Pilih atau tambah supplier baru..."
            ) { name in
                if name.isEmpty {
                    showNewSupplierAlert = true
                } else {
                    Task {
                        let s = try? await api.createSupplier(name: name)
                        if let s {
                            suppliers.append(s)
                            selectedSupplierId = s.id
                            selectedSupplierName = s.name
                        }
                    }
                }
            }
            .listRowBackground(OuraTheme.Colors.surfaceCard)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

            OuraDatePickerField(label: "Tanggal Beli", date: $purchasedAt)
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        } header: {
            OuraSectionHeader(title: "Biaya & Info")
        }
        .listSectionSeparator(.hidden)
    }

    // MARK: - Load

    private func loadData() async {
        async let mats = api.getMaterials()
        async let sups = api.getSuppliers()
        materials = (try? await mats) ?? []
        suppliers = (try? await sups) ?? []
        // Pre-fill width from preselected material
        if let pre = preselectedMaterial {
            widthCm = pre.fabricWidthCm
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMsg = nil
        defer { isSaving = false }

        do {
            var materialId: UUID

            if let existing = resolvedMaterial {
                materialId = existing.id
                // Patch fabric family jika berubah
                if existing.category == .fabric {
                    let trimmed = editFabricFamily.trimmingCharacters(in: .whitespaces)
                    if trimmed != originalFabricFamily {
                        _ = try? await api.patchMaterial(
                            id: existing.id,
                            PatchMaterialRequest(fabricFamily: trimmed.isEmpty ? nil : trimmed)
                        )
                    }
                }
            } else if isCreatingNew, let cat = newMaterialCategory {
                let familyVal = newFabricFamily.trimmingCharacters(in: .whitespaces)
                let mat = try await api.createMaterial(CreateMaterialRequest(
                    name: newMaterialName,
                    category: cat.rawValue,
                    costClass: cat.defaultCostClass,
                    purchaseUnit: cat.defaultPurchaseUnit,
                    usageUnit: cat.defaultUsageUnit,
                    fabricWidthCm: cat == .fabric ? newFabricWidthCm : nil,
                    fabricFamily: cat == .fabric && !familyVal.isEmpty ? familyVal : nil
                ))
                materialId = mat.id
            } else {
                errorMsg = "Pilih atau buat bahan terlebih dahulu"
                return
            }

            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withFullDate]

            let req = CreatePurchaseRequest(
                widthCm: isFabric ? widthCm : nil,
                lengthCm: isFabric ? lengthCm : nil,
                qty: isFabric ? nil : qty,
                packageLabel: isThread ? threadPackageSize : nil,
                totalCost: totalCost ?? 0,
                supplierId: selectedSupplierId,
                supplierName: selectedSupplierId == nil && !selectedSupplierName.isEmpty
                    ? selectedSupplierName : nil,
                purchasedAt: fmt.string(from: purchasedAt)
            )
            _ = try await api.createPurchase(materialId: materialId, req)
            dismiss()
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
