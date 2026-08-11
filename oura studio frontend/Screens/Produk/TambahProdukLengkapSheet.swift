import SwiftUI

struct TambahProdukLengkapSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    // MARK: — Step 1: product fields
    @State private var productName = ""
    @State private var sku = ""
    @State private var selectedSizes: [String] = ["Free Size"]
    @State private var showCustomSizeAlert = false
    @State private var customSizeInput = ""

    // MARK: — Step 2: recipe fields
    @State private var fabrics: [Material] = []
    @State private var allMaterials: [Material] = []
    @State private var recipeSize: String = ""
    @State private var selectedFabricIds: [UUID] = []
    @State private var fabricLengths: [UUID: Double] = [:]
    @State private var fabricWidths: [UUID: Double] = [:]
    @State private var fabricRotations: [UUID: Bool] = [:]
    @State private var gabungkanResep = false
    @State private var selectedComponentIds: [UUID] = []
    @State private var componentQtys: [UUID: Double] = [:]
    @State private var laborMinutes: Double?

    // MARK: — Navigation & save state
    @State private var isOnRecipeStep = false
    @State private var isSaving = false
    @State private var errorMsg: String?

    private let presets: [(label: String, sizes: [String])] = [
        ("Free Size", ["Free Size"]),
        ("XS – XL",  ["XS", "S", "M", "L", "XL"]),
        ("S – XXL",  ["S", "M", "L", "XL", "XXL"]),
    ]

    private var step1Valid: Bool {
        !productName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !sku.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedSizes.isEmpty
    }

    private var recipeCanSave: Bool {
        guard (laborMinutes ?? 0) > 0 else { return false }
        let fabricsValid = selectedFabricIds.allSatisfy { id in
            (fabricLengths[id] ?? 0) > 0 && (fabricWidths[id] ?? 0) > 0
        }
        let compsValid = selectedComponentIds.allSatisfy { id in (componentQtys[id] ?? 0) > 0 }
        return fabricsValid && compsValid
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(OuraTheme.Colors.separator)
            if isOnRecipeStep {
                recipeStepContent
            } else {
                productStepContent
            }
        }
        .background(OuraTheme.Colors.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await loadMaterials() }
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
                    sectionLabel("Nama Produk") {
                        TextField("contoh: Scrunchie Mini", text: $productName)
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                            .autocorrectionDisabled()
                            .onChange(of: productName) { _, val in sku = Self.autoSKU(from: val) }
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

                    if let err = errorMsg {
                        errorBanner(err)
                    }
                }
                .padding(16)
            }

            VStack(spacing: 0) {
                Divider().overlay(OuraTheme.Colors.separator)
                VStack(spacing: 10) {
                    // Primary: go to recipe step
                    Button {
                        recipeSize = selectedSizes.first ?? ""
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
                // Size picker — only if multiple sizes
                if selectedSizes.count > 1 {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Ukuran lain dapat diresep nanti dari tab Resep.")
                                .font(.system(size: 12))
                                .foregroundStyle(OuraTheme.Colors.textTertiary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(selectedSizes, id: \.self) { size in
                                        let isSelected = recipeSize == size
                                        Button { recipeSize = size } label: {
                                            Text(size)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(isSelected ? .white : OuraTheme.Colors.textSecondary)
                                                .padding(.horizontal, 14).padding(.vertical, 7)
                                                .background(isSelected ? OuraTheme.Colors.accent : OuraTheme.Colors.surfaceSheet)
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(isSelected ? Color.clear : OuraTheme.Colors.border, lineWidth: 1))
                                        }
                                        .buttonStyle(.borderless)
                                        .animation(.easeInOut(duration: 0.15), value: recipeSize)
                                    }
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
                }

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
                    .onChange(of: selectedFabricIds) { _, newIds in
                        for id in newIds where fabricRotations[id] == nil {
                            fabricRotations[id] = true
                        }
                        if newIds.count < 2 { gabungkanResep = false }
                    }

                    if selectedFabricIds.count >= 2 {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Gabungkan dalam satu resep", isOn: $gabungkanResep)
                                .tint(OuraTheme.Colors.accent)
                                .font(.system(size: 14))
                            Text(gabungkanResep
                                ? "Semua kain masuk ke satu resep. Tidak membuat varian produk terpisah."
                                : "Setiap kain jadi resep sendiri-sendiri dengan varian produk tersendiri.")
                                .font(.system(size: 12))
                                .foregroundStyle(OuraTheme.Colors.textTertiary)
                        }
                        .listRowBackground(gabungkanResep ? OuraTheme.Colors.accentLight : OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
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
                                    value: Binding(get: { fabricLengths[fabId] }, set: { fabricLengths[fabId] = $0 }),
                                    unit: "cm"
                                )
                                NumericInputField(
                                    label: "Lebar (cm)",
                                    value: Binding(get: { fabricWidths[fabId] }, set: { fabricWidths[fabId] = $0 }),
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
            dismiss()
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }

    // MARK: — Save: product + recipe

    private func saveProductAndRecipe() async {
        guard !recipeSize.isEmpty else { errorMsg = "Pilih ukuran untuk diresep."; return }

        let incomplFabrics = selectedFabricIds.filter { id in
            (fabricLengths[id] ?? 0) <= 0 || (fabricWidths[id] ?? 0) <= 0
        }
        if !incomplFabrics.isEmpty {
            let names = incomplFabrics.compactMap { id in fabrics.first { $0.id == id }?.name }.joined(separator: ", ")
            errorMsg = "Isi dimensi panjang dan lebar untuk: \(names)"
            return
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

            // 2. Create all sizes (base, no fabricVariantName)
            var sizeDetails: [ProductSizeDetail] = []
            for label in selectedSizes {
                let detail = try await api.createProductSize(sku: product.sku, sizeLabel: label)
                sizeDetails.append(detail)
            }

            // 3. Find the base size for the recipe
            guard let baseSize = sizeDetails.first(where: { $0.sizeLabel == recipeSize }) else {
                dismiss(); return
            }

            let components = selectedComponentIds.map { matId in
                CreatePatternSpecRequest.ComponentInput(
                    materialId: matId,
                    qtyPerUnit: componentQtys[matId] ?? 0
                )
            }

            if selectedFabricIds.isEmpty || gabungkanResep {
                // Gabungkan: one PatternSpec per fabric, all linked to base size (no fabricVariantName)
                guard !selectedFabricIds.isEmpty else {
                    throw APIError.serverError(400, "Pilih setidaknya satu kain untuk resep ini.")
                }
                for fabId in selectedFabricIds {
                    let fabricInput = CreatePatternSpecRequest.FabricInput(
                        materialId: fabId,
                        cutLengthCm: fabricLengths[fabId] ?? 0,
                        cutWidthCm: fabricWidths[fabId] ?? 0,
                        rotationAllowed: fabricRotations[fabId] ?? true
                    )
                    let req = CreatePatternSpecRequest(
                        productSizeId: baseSize.id,
                        fabrics: [fabricInput],
                        estLaborMinutes: laborMinutes ?? 0,
                        components: components
                    )
                    _ = try await api.createOrUpdatePatternSpec(req)
                }
            } else {
                // Pisah: one PatternSpec per fabric, each with its own ProductSize + fabricVariantName
                for fabId in selectedFabricIds {
                    guard let fabric = fabrics.first(where: { $0.id == fabId }) else { continue }
                    let variantSize = try await api.createProductSize(
                        sku: product.sku,
                        sizeLabel: recipeSize,
                        fabricVariantName: fabric.name
                    )
                    let fabricInput = CreatePatternSpecRequest.FabricInput(
                        materialId: fabId,
                        cutLengthCm: fabricLengths[fabId] ?? 0,
                        cutWidthCm: fabricWidths[fabId] ?? 0,
                        rotationAllowed: fabricRotations[fabId] ?? true
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
