import SwiftUI

struct TambahResepSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    // Section 1: Product + size
    @State private var products: [Product] = []
    @State private var allSizes: [ProductSizeDetail] = []
    @State private var selectedProductId: UUID?
    @State private var selectedProductName: String = ""
    @State private var selectedSizeName: String = ""

    // Section 2: Fabrics (multi, all optional)
    @State private var fabrics: [Material] = []
    @State private var selectedFabricIds: [UUID] = []
    @State private var fabricLengths: [UUID: Double] = [:]
    @State private var fabricWidths: [UUID: Double] = [:]
    @State private var fabricRotations: [UUID: Bool] = [:]

    // Section 3: Components
    @State private var allMaterials: [Material] = []
    @State private var selectedComponentIds: [UUID] = []
    @State private var componentQtys: [UUID: Double] = [:]

    // Section 4: Labor
    @State private var laborMinutes: Double?

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
        selectedProductId != nil || !selectedSizeName.isEmpty ||
        !selectedFabricIds.isEmpty || !selectedComponentIds.isEmpty ||
        (laborMinutes ?? 0) > 0
    }

    private var selectedProduct: Product? { products.first { $0.id == selectedProductId } }
    private var sizesForProduct: [ProductSizeDetail] {
        guard let p = selectedProduct else { return [] }
        return allSizes.filter { $0.productId == p.id }
    }
    // Any size with matching sizeLabel works — we only use it for productSku / productId
    private var selectedSize: ProductSizeDetail? {
        sizesForProduct.first { $0.sizeLabel == selectedSizeName }
    }

    // Unique size labels for the picker (avoids duplicate chips when multiple fabric variants share a label)
    private var uniqueSizeLabels: [String] {
        var seen = Set<String>()
        return sizesForProduct.compactMap { size in
            seen.insert(size.sizeLabel).inserted ? size.sizeLabel : nil
        }.sorted()
    }

    private var canSave: Bool {
        guard selectedSize != nil else { return false }
        guard (laborMinutes ?? 0) > 0 else { return false }
        let fabricsValid = selectedFabricIds.allSatisfy { id in
            (fabricLengths[id] ?? 0) > 0 && (fabricWidths[id] ?? 0) > 0
        }
        let compsValid = selectedComponentIds.allSatisfy { id in (componentQtys[id] ?? 0) > 0 }
        return fabricsValid && compsValid
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
                    .onChange(of: selectedProductId) { _, _ in selectedSizeName = "" }

                    if selectedProductId != nil {
                        sizePickerRow
                            .listRowBackground(OuraTheme.Colors.surfaceCard)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                } header: {
                    OuraSectionHeader(title: "Produk & Ukuran")
                }
                .listSectionSeparator(.hidden)

                // Kain (opsional, multi)
                if selectedSize != nil {
                    Section {
                        TokenizedMultiSelectField(
                            label: "Kain yang Digunakan",
                            selectedIds: $selectedFabricIds,
                            items: fabrics.map { (id: $0.id, name: $0.name) },
                            placeholder: "Pilih kain (opsional)"
                        )
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .onChange(of: selectedFabricIds) { _, newIds in
                            for id in newIds where fabricRotations[id] == nil {
                                fabricRotations[id] = true
                            }
                        }

                        ForEach(selectedFabricIds, id: \.self) { fabId in
                            let name = fabrics.first { $0.id == fabId }?.name ?? ""
                            VStack(alignment: .leading, spacing: 10) {
                                Text(name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                                HStack(spacing: 12) {
                                    NumericInputField(
                                        label: "Panjang (cm)",
                                        value: Binding(
                                            get: { fabricLengths[fabId] },
                                            set: { fabricLengths[fabId] = $0 }
                                        ),
                                        unit: "cm"
                                    )
                                    NumericInputField(
                                        label: "Lebar (cm)",
                                        value: Binding(
                                            get: { fabricWidths[fabId] },
                                            set: { fabricWidths[fabId] = $0 }
                                        ),
                                        unit: "cm"
                                    )
                                }
                                Toggle("Rotasi Diizinkan", isOn: Binding(
                                    get: { fabricRotations[fabId] ?? true },
                                    set: { fabricRotations[fabId] = $0 }
                                ))
                                .tint(OuraTheme.Colors.accent)
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(OuraTheme.Colors.surfaceCard)
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
                                .filter { $0.category == .hardware }
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
                selectedSizeName = sizes.count == 1 ? sizes[0].sizeLabel : ""
            }
        }
    }

    // MARK: - Size picker row with inline "+ Ukuran Baru" chip

    private var sizePickerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ukuran")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(uniqueSizeLabels, id: \.self) { label in
                        let isSelected = selectedSizeName == label
                        Button {
                            selectedSizeName = isSelected ? "" : label
                        } label: {
                            Text(label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : OuraTheme.Colors.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(isSelected ? OuraTheme.Colors.accent : OuraTheme.Colors.surfaceSheet)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(isSelected ? Color.clear : OuraTheme.Colors.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: selectedSizeName)
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
            selectedSizeName = newSize.sizeLabel
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
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
        guard let size = selectedSize else {
            errorMsg = "Pilih produk dan ukuran terlebih dahulu."; return
        }

        let incomplFabrics = selectedFabricIds.filter { id in
            (fabricLengths[id] ?? 0) <= 0 || (fabricWidths[id] ?? 0) <= 0
        }
        if !incomplFabrics.isEmpty {
            let names = incomplFabrics.compactMap { id in fabrics.first { $0.id == id }?.name }.joined(separator: ", ")
            errorMsg = "Isi dimensi panjang dan lebar untuk kain: \(names)"
            return
        }

        let incomplComps = selectedComponentIds.filter { id in (componentQtys[id] ?? 0) <= 0 }
        if !incomplComps.isEmpty {
            let names = incomplComps.compactMap { id in allMaterials.first { $0.id == id }?.name }.joined(separator: ", ")
            errorMsg = "Isi jumlah untuk bahan tambahan: \(names)"
            return
        }

        guard (laborMinutes ?? 0) > 0 else {
            errorMsg = "Isi estimasi waktu kerja (menit)."
            return
        }

        isSaving = true
        errorMsg = nil
        defer { isSaving = false }

        let components = selectedComponentIds.map { matId in
            CreatePatternSpecRequest.ComponentInput(materialId: matId, qtyPerUnit: componentQtys[matId] ?? 0)
        }

        do {
            guard !selectedFabricIds.isEmpty else {
                throw APIError.serverError(400, "Pilih setidaknya satu kain untuk resep ini.")
            }
            let fabricInputs = selectedFabricIds.map { fabId in
                CreatePatternSpecRequest.FabricInput(
                    materialId: fabId,
                    cutLengthCm: fabricLengths[fabId] ?? 0,
                    cutWidthCm: fabricWidths[fabId] ?? 0,
                    rotationAllowed: fabricRotations[fabId] ?? true
                )
            }
            let req = CreatePatternSpecRequest(
                productSizeId: size.id,
                fabrics: fabricInputs,
                estLaborMinutes: laborMinutes ?? 0,
                components: components
            )
            _ = try await api.createOrUpdatePatternSpec(req)
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
        ("XS – XL",  ["XS", "S", "M", "L", "XL"]),
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
