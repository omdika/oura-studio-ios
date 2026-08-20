import SwiftUI

// MARK: - Shared group model

struct ProdukSizeGroup: Identifiable {
    let sizeLabel: String
    let variants: [ProductSizeDetail]
    public var id: String { sizeLabel }
    var totalStock: Int { variants.reduce(0) { $0 + $1.currentStockQty } }
    // Variants shown in UI. Falls back to null-fabric records when no explicit variants exist
    // (e.g. multi-fabric products whose ProductSize has fabricVariantName = null).
    var displayVariants: [ProductSizeDetail] {
        let withFabric = variants.filter { $0.fabricVariantName != nil }
        return withFabric.isEmpty ? variants : withFabric
    }
    var isAnyHabis: Bool { displayVariants.contains { $0.currentStockQty == 0 } }
    var isAnyMenipis: Bool { displayVariants.contains { $0.isLowStock && $0.currentStockQty > 0 } }
}

func makeSizeGroups(from sizes: [ProductSizeDetail]) -> [ProdukSizeGroup] {
    Dictionary(grouping: sizes.filter { !$0.isArchived }, by: \.sizeLabel)
        .map { label, variants in
            ProdukSizeGroup(sizeLabel: label, variants: variants.sorted { $0.displayLabel < $1.displayLabel })
        }
        .sorted { $0.sizeLabel < $1.sizeLabel }
}

// MARK: - ProdukDetailView

struct ProdukDetailView: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let product: Product
    var onProductChanged: (() -> Void)? = nil

    @State private var sizes: [ProductSizeDetail] = []
    @State private var isLoading = true
    @State private var isEditingName = false
    @State private var editName: String = ""
    @State private var showAddSize = false
    @State private var showArchiveAlert = false
    @State private var errorMsg: String?

    private var sizeGroups: [ProdukSizeGroup] { makeSizeGroups(from: sizes) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuraTheme.Spacing.sectionGap) {
                headerCard
                sizesSection
                if let err = errorMsg {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.dangerText)
                        .padding(10)
                        .background(OuraTheme.Colors.dangerBg)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                        .padding(.horizontal, OuraTheme.Spacing.horizontal)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(OuraTheme.Colors.background)
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        editName = product.name
                        isEditingName = true
                    } label: {
                        Label("Ubah Nama", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showArchiveAlert = true
                    } label: {
                        Label("Arsipkan Produk", systemImage: "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
        }
        .task { await loadSizes() }
        .sheet(isPresented: $showAddSize, onDismiss: { Task { await loadSizes() } }) {
            AddSizeSheet(productSku: product.sku, existingSizes: sizes)
        }
        .alert("Ubah Nama Produk", isPresented: $isEditingName) {
            TextField("Nama produk", text: $editName)
            Button("Simpan") { Task { await renameProduct() } }
            Button("Batal", role: .cancel) {}
        }
        .alert("Arsipkan \(product.name)?", isPresented: $showArchiveAlert) {
            Button("Arsipkan", role: .destructive) { Task { await archiveProduct() } }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Produk tidak akan muncul di daftar dan tidak bisa digunakan untuk transaksi baru.")
        }
    }

    // MARK: - Header card

    private var headerCard: some View {
        let materialNames = Array(Set(sizes.compactMap { $0.fabricVariantName })).sorted()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    if !materialNames.isEmpty {
                        Text(materialNames.joined(separator: ", "))
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                    }
                    Text(product.sku)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(OuraTheme.Colors.border)
                        .clipShape(Capsule())
                }
                Spacer()
            }
            Divider().overlay(OuraTheme.Colors.separator)
            HStack {
                infoCell("Jumlah Ukuran", value: "\(sizeGroups.count)")
                Spacer()
                let totalStock = sizes.reduce(0) { $0 + $1.currentStockQty }
                infoCell("Total Stok", value: "\(totalStock) pcs")
            }
        }
        .padding(OuraTheme.Spacing.cardPad)
        .ouraCard()
        .padding(.horizontal, OuraTheme.Spacing.horizontal)
    }

    private func infoCell(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
        }
    }

    // MARK: - Sizes section (grouped by size label)

    private var sizesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                OuraSectionHeader(title: "Ukuran")
                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                Spacer()
                Button {
                    showAddSize = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Tambah Ukuran")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(OuraTheme.Colors.accent)
                }
                .buttonStyle(.plain)
                .padding(.trailing, OuraTheme.Spacing.horizontal)
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if sizeGroups.isEmpty {
                Text("Belum ada ukuran")
                    .font(.system(size: 14))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .ouraCard()
                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sizeGroups.enumerated()), id: \.element.id) { idx, group in
                        NavigationLink(destination: ProdukSizeGroupView(product: product, sizeLabel: group.sizeLabel)) {
                            SizeGroupRow(group: group)
                        }
                        .buttonStyle(.plain)
                        if idx < sizeGroups.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                                .overlay(OuraTheme.Colors.separator)
                        }
                    }
                }
                .ouraCard()
                .padding(.horizontal, OuraTheme.Spacing.horizontal)
            }
        }
    }

    // MARK: - Actions

    private func loadSizes() async {
        isLoading = true
        sizes = (try? await api.getProductSizes(sku: product.sku)) ?? []
        isLoading = false
    }

    private func renameProduct() async {
        guard !editName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            _ = try await api.patchProduct(sku: product.sku, name: editName.trimmingCharacters(in: .whitespaces))
            onProductChanged?()
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }

    private func archiveProduct() async {
        do {
            try await api.archiveProduct(sku: product.sku, currentName: product.name)
            onProductChanged?()
            dismiss()
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }
}

// MARK: - Size group row (used in ProdukDetailView sizesSection)

private struct SizeGroupRow: View {
    let group: ProdukSizeGroup

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.sizeLabel)
                        .font(.system(size: 15, weight: .semibold))
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
                }
                Text(group.displayVariants.count == 1
                     ? (group.displayVariants.first?.fabricVariantName ?? "1 varian")
                     : "\(group.displayVariants.count) varian kain")
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(group.totalStock) pcs")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Variant row (used in ProdukSizeGroupView)

struct ProdukVariantRow: View {
    let size: ProductSizeDetail

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text([size.fabricVariantName, size.sizeLabel].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    if size.isLowStock {
                        OuraTag(
                            text: size.currentStockQty == 0 ? "Habis" : "Menipis",
                            color: size.currentStockQty == 0 ? OuraTheme.Colors.dangerText : OuraTheme.Colors.warningText,
                            bg:    size.currentStockQty == 0 ? OuraTheme.Colors.dangerBg   : OuraTheme.Colors.warningBg
                        )
                    }
                }
                HStack(spacing: 6) {
                    if let hpp = size.latestHppBreakdown {
                        Text("HPP \(hpp.total.rupiahFormatted)")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                    }
                    if let margin = size.marginPct {
                        Text("·").foregroundStyle(OuraTheme.Colors.textTertiary)
                        Text(String(format: "%.0f%% margin", margin * 100 as Double))
                            .font(.system(size: 12))
                            .foregroundStyle(margin >= 0.3 ? OuraTheme.Colors.greenAccent : OuraTheme.Colors.warningText)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if let price = size.sellingPrice {
                    Text(price.rupiahFormatted)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                }
                Text("\(size.currentStockQty) pcs")
                    .font(.system(size: 11))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - ProdukSizeGroupView

struct ProdukSizeGroupView: View {
    @EnvironmentObject private var api: APIService

    let product: Product
    let sizeLabel: String

    @State private var variants: [ProductSizeDetail] = []
    @State private var isLoading = true
    @State private var showAddVariant = false
    @State private var errorMsg: String?

    private var totalStock: Int { variants.reduce(0) { $0 + $1.currentStockQty } }
    // Only show variants that have an explicit fabric — null-fabric sizes are placeholder records
    // that look confusing in this view (they render as "L | 0 pcs" inside the "L" group page).
    private var displayedVariants: [ProductSizeDetail] {
        let withFabric = variants.filter { $0.fabricVariantName != nil }
        return withFabric.isEmpty ? variants : withFabric
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuraTheme.Spacing.sectionGap) {
                aggregateCard
                variantsSection
                if let err = errorMsg {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.dangerText)
                        .padding(10)
                        .background(OuraTheme.Colors.dangerBg)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                        .padding(.horizontal, OuraTheme.Spacing.horizontal)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(OuraTheme.Colors.background)
        .navigationTitle("\(product.name) · \(sizeLabel)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showAddVariant, onDismiss: { Task { await load() } }) {
            AddSizeSheet(
                productSku: product.sku,
                existingSizes: variants,
                prefilledSizeLabel: sizeLabel
            )
        }
    }

    private var aggregateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    Text(sizeLabel)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                }
                Spacer()
                Text(product.sku)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(OuraTheme.Colors.border).clipShape(Capsule())
            }
            Divider().overlay(OuraTheme.Colors.separator)
            HStack {
                groupInfoCell("Varian Kain", value: "\(displayedVariants.count)")
                Spacer()
                groupInfoCell("Total Stok", value: "\(totalStock) pcs")
            }
        }
        .padding(OuraTheme.Spacing.cardPad)
        .ouraCard()
        .padding(.horizontal, OuraTheme.Spacing.horizontal)
    }

    private func groupInfoCell(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11)).foregroundStyle(OuraTheme.Colors.textTertiary)
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(OuraTheme.Colors.textPrimary)
        }
    }

    private var variantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                OuraSectionHeader(title: "Varian Kain")
                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                Spacer()
                Button {
                    showAddVariant = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                        Text("Tambah Varian").font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(OuraTheme.Colors.accent)
                }
                .buttonStyle(.plain)
                .padding(.trailing, OuraTheme.Spacing.horizontal)
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if displayedVariants.isEmpty {
                Text("Belum ada varian kain")
                    .font(.system(size: 14))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .ouraCard()
                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(displayedVariants.enumerated()), id: \.element.id) { idx, variant in
                        NavigationLink(destination: ProdukSizeDetailView(productSize: variant)) {
                            ProdukVariantRow(size: variant)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await archiveVariant(variant) }
                            } label: {
                                Label("Arsip", systemImage: "archivebox")
                            }
                        }
                        if idx < displayedVariants.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                                .overlay(OuraTheme.Colors.separator)
                        }
                    }
                }
                .ouraCard()
                .padding(.horizontal, OuraTheme.Spacing.horizontal)
            }
        }
    }

    private func load() async {
        isLoading = true
        let all = (try? await api.getProductSizes(sku: product.sku)) ?? []
        variants = all.filter { !$0.isArchived && $0.sizeLabel == sizeLabel }
        isLoading = false
    }

    private func archiveVariant(_ v: ProductSizeDetail) async {
        do {
            try await api.archiveProductSize(sku: product.sku, sizeId: v.id)
            variants.removeAll { $0.id == v.id }
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }
}

// MARK: - Add size / add variant sheet

struct AddSizeSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let productSku: String
    let existingSizes: [ProductSizeDetail]
    var prefilledSizeLabel: String? = nil

    @State private var sizeLabel: String = ""
    @State private var fabricVariantName: String = ""       // non-variant mode (free text)
    @State private var selectedFabricName: String? = nil    // variant mode: name of chosen fabric
    @State private var selectedSpecId: UUID? = nil          // variant mode: spec for stock deduction (nil = no deduction)
    @State private var availableSpecs: [PatternSpec] = []   // variant mode: specs for this product+size
    @State private var allFabrics: [Material] = []          // variant mode: all fabric materials in inventory
    @State private var initialStockQty: Double? = nil       // variant mode: optional initial stock
    @State private var manualCutWidthCm: Double? = nil      // variant mode, no recipe: cutting width per piece
    @State private var manualCutLengthCm: Double? = nil     // variant mode, no recipe: cutting length per piece
    @State private var showFabricPicker = false
    @State private var isLoadingData = false
    @State private var isSaving = false
    @State private var errorMsg: String?

    private var isVariantMode: Bool { prefilledSizeLabel != nil }

    private var canSave: Bool {
        let s = sizeLabel.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return false }
        if isVariantMode {
            guard let name = selectedFabricName, !name.isEmpty else { return false }
            let alreadyExists = existingSizes.contains { $0.sizeLabel == s && $0.fabricVariantName == name }
            if alreadyExists {
                // Size pre-created (e.g., via TambahResepSheet); allow only when adding stock
                return (initialStockQty ?? 0) > 0
            }
            return true
        } else {
            let f = fabricVariantName.trimmingCharacters(in: .whitespaces)
            let fOpt: String? = f.isEmpty ? nil : f
            return !existingSizes.contains { $0.sizeLabel == s && $0.fabricVariantName == fOpt }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Ukuran
                if isVariantMode {
                    Section {
                        HStack {
                            Text("Ukuran").foregroundStyle(OuraTheme.Colors.textSecondary)
                            Spacer()
                            Text(prefilledSizeLabel ?? "")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                        }
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                    } header: { OuraSectionHeader(title: "Ukuran") }
                } else {
                    Section {
                        TextField("Ukuran (mis: S, M, L, XL)", text: $sizeLabel)
                            .autocorrectionDisabled()
                            .listRowBackground(OuraTheme.Colors.surfaceCard)
                    } header: { OuraSectionHeader(title: "Label Ukuran") }
                }

                // Jenis Kain
                if isVariantMode {
                    Section {
                        if isLoadingData {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Memuat...").font(.system(size: 13)).foregroundStyle(OuraTheme.Colors.textSecondary)
                            }
                            .listRowBackground(OuraTheme.Colors.surfaceCard)
                        } else {
                            Button { showFabricPicker = true } label: {
                                HStack {
                                    if let name = selectedFabricName {
                                        Text(name)
                                            .font(.system(size: 15))
                                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                                        Spacer()
                                        if selectedSpecId != nil {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 13))
                                                .foregroundStyle(OuraTheme.Colors.greenAccent)
                                        }
                                    } else {
                                        Text("Pilih kain...")
                                            .font(.system(size: 15))
                                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                                        Spacer()
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(OuraTheme.Colors.surfaceCard)
                        }
                    } header: { OuraSectionHeader(title: "Jenis Kain") }
                      footer: {
                          if let name = selectedFabricName {
                              if selectedSpecId != nil {
                                  Text("\(name) ada di resep — stok bahan akan dikurangi otomatis.")
                              } else {
                                  Text("\(name) tidak ada di resep — isi dimensi potongan di bawah agar stok bahan dikurangi.")
                              }
                          }
                      }
                } else {
                    Section {
                        TextField("Jenis kain (opsional, mis: Satin Putih)", text: $fabricVariantName)
                            .autocorrectionDisabled()
                            .listRowBackground(OuraTheme.Colors.surfaceCard)
                    } header: { OuraSectionHeader(title: "Jenis Kain") }
                      footer: {
                          Text("Isi jika satu ukuran dibuat dengan beberapa jenis kain berbeda. Kombinasi ukuran + jenis kain harus unik.")
                      }
                }

                // Dimensi Potongan — only when no recipe (manual fabric deduction)
                if isVariantMode, selectedFabricName != nil, selectedSpecId == nil {
                    Section {
                        NumericInputField(label: "Lebar potongan (cm)", value: $manualCutWidthCm, unit: "cm")
                            .listRowBackground(OuraTheme.Colors.surfaceCard)
                        NumericInputField(label: "Panjang potongan (cm)", value: $manualCutLengthCm, unit: "cm")
                            .listRowBackground(OuraTheme.Colors.surfaceCard)
                    } header: { OuraSectionHeader(title: "Dimensi Potongan per Pcs") }
                      footer: {
                          Text("Opsional. Isi untuk mengurangi stok bahan otomatis. Jika tidak diisi, stok ditambah manual tanpa mengurangi bahan.")
                      }
                }

                // Stok Awal — shown whenever a fabric is selected in variant mode
                if isVariantMode, selectedFabricName != nil {
                    Section {
                        NumericInputField(label: "Jumlah (pcs)", value: $initialStockQty, unit: "pcs")
                            .listRowBackground(OuraTheme.Colors.surfaceCard)
                    } header: { OuraSectionHeader(title: "Stok Awal (opsional)") }
                      footer: {
                          if selectedSpecId != nil {
                              Text("Stok bahan akan dikurangi otomatis sesuai resep.")
                          } else if (manualCutWidthCm ?? 0) > 0 && (manualCutLengthCm ?? 0) > 0 {
                              Text("Stok bahan dikurangi sesuai dimensi di atas.")
                          } else {
                              Text("Stok ditambah manual — bahan tidak akan dikurangi.")
                          }
                      }
                }

                if let err = errorMsg {
                    Section {
                        Text(err).foregroundStyle(OuraTheme.Colors.dangerText)
                            .listRowBackground(OuraTheme.Colors.dangerBg)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OuraTheme.Colors.background)
            .navigationTitle(isVariantMode ? "Tambah Varian Kain" : "Tambah Ukuran")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }.foregroundStyle(OuraTheme.Colors.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { Task { await save() } }
                        .foregroundStyle(canSave ? OuraTheme.Colors.accent : OuraTheme.Colors.textDisabled)
                        .disabled(!canSave || isSaving)
                }
            }
            .onAppear {
                if let prefill = prefilledSizeLabel {
                    sizeLabel = prefill
                    Task { await loadData() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showFabricPicker) {
            FabricPickerSheet(
                fabrics: allFabrics,
                availableSpecs: availableSpecs,
                alreadyUsedFabricNames: usedFabricNames
            ) { fabricName, specId in
                selectedFabricName = fabricName
                selectedSpecId = specId
                if specId != nil { manualCutWidthCm = nil; manualCutLengthCm = nil }
            }
        }
    }

    private var usedFabricNames: Set<String> {
        let label = prefilledSizeLabel ?? sizeLabel
        return Set(existingSizes
            .filter { $0.sizeLabel == label }
            .compactMap { $0.fabricVariantName })
    }

    private var specFabrics: [Material] {
        let specMaterialIds = Set(availableSpecs.flatMap { $0.fabrics.map { $0.materialId } })
        return allFabrics.filter { specMaterialIds.contains($0.id) }
    }

    private func loadData() async {
        isLoadingData = true
        defer { isLoadingData = false }
        async let specsTask = api.getPatternSpecsForSize(productSku: productSku, sizeLabel: prefilledSizeLabel ?? "")
        async let matsTask  = api.getMaterials()
        availableSpecs = ((try? await specsTask) ?? []).filter { $0.productSku == productSku }
        allFabrics     = ((try? await matsTask) ?? []).filter { $0.category == .fabric }
    }

    private func save() async {
        isSaving = true; defer { isSaving = false }
        errorMsg = nil
        let s = sizeLabel.trimmingCharacters(in: .whitespaces)
        let fabricName: String? = isVariantMode
            ? selectedFabricName
            : { let f = fabricVariantName.trimmingCharacters(in: .whitespaces); return f.isEmpty ? nil : f }()
        do {
            // Reuse existing size if it was pre-created (e.g., by TambahResepSheet)
            let targetSize: ProductSizeDetail
            if let existing = existingSizes.first(where: { $0.sizeLabel == s && $0.fabricVariantName == fabricName }) {
                targetSize = existing
            } else {
                targetSize = try await api.createProductSize(sku: productSku, sizeLabel: s, fabricVariantName: fabricName)
            }
            if let qty = initialStockQty, qty > 0 {
                if let specId = selectedSpecId {
                    do {
                        _ = try await api.addStockFromBahan(sku: productSku, sizeId: targetSize.id, qty: Int(qty), specId: specId)
                    } catch APIError.serverError(404, _) {
                        // Spec found in picker but doesn't belong to this product on backend — fall back to plain stock add
                        _ = try await api.adjustStock(sku: productSku, sizeId: targetSize.id, qty: Int(qty), reason: "adjustment")
                    }
                } else if let mat = allFabrics.first(where: { $0.name == fabricName }),
                          let w = manualCutWidthCm, w > 0,
                          let l = manualCutLengthCm, l > 0 {
                    _ = try await api.addStockManual(sku: productSku, sizeId: targetSize.id, qty: Int(qty), materialId: mat.id, cutWidthCm: w, cutLengthCm: l)
                } else {
                    _ = try await api.adjustStock(sku: productSku, sizeId: targetSize.id, qty: Int(qty), reason: "adjustment")
                }
            }
            dismiss()
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }
}

// MARK: - Fabric picker bottom sheet

private struct FabricPickerSheet: View {
    let fabrics: [Material]
    let availableSpecs: [PatternSpec]
    var alreadyUsedFabricNames: Set<String> = []
    var allowAddNew: Bool = true
    let onSelect: (String, UUID?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private var pickableFabrics: [Material] {
        fabrics.filter { !alreadyUsedFabricNames.contains($0.name) }
    }

    private var filteredFabrics: [Material] {
        if searchText.isEmpty { return pickableFabrics }
        return pickableFabrics.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    private func specId(for fabric: Material) -> UUID? {
        availableSpecs.first(where: { $0.fabrics.contains(where: { $0.materialId == fabric.id }) })?.id
    }

    private var showAddNew: Bool {
        guard allowAddNew else { return false }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return false }
        if alreadyUsedFabricNames.contains(where: { $0.lowercased() == q.lowercased() }) { return false }
        return !fabrics.contains(where: { $0.name.lowercased() == q.lowercased() })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                    TextField("Cari kain...", text: $searchText)
                        .font(.system(size: 15))
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(OuraTheme.Colors.surfaceSheet)
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium).stroke(OuraTheme.Colors.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().overlay(OuraTheme.Colors.separator)

                List {
                    if filteredFabrics.isEmpty && !showAddNew {
                        Text(allowAddNew
                            ? "Belum ada kain di inventori. Tambah di Produksi → Bahan."
                            : "Semua kain di resep sudah menjadi varian untuk ukuran ini."
                        )
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .listRowBackground(OuraTheme.Colors.background)
                    }

                    ForEach(filteredFabrics, id: \.id) { fabric in
                        let sid = specId(for: fabric)
                        Button {
                            onSelect(fabric.name, sid)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(fabric.name)
                                        .font(.system(size: 15))
                                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                                    if sid != nil {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(OuraTheme.Colors.greenAccent)
                                            Text("Ada di resep · bisa kurangi stok bahan")
                                                .font(.system(size: 12))
                                                .foregroundStyle(OuraTheme.Colors.greenAccent)
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                    }

                    // Add new fabric option — appears when search doesn't match any existing fabric
                    if showAddNew {
                        let q = searchText.trimmingCharacters(in: .whitespaces)
                        Button {
                            onSelect(q, nil)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(OuraTheme.Colors.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tambah \"\(q)\"")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(OuraTheme.Colors.accent)
                                    Text("Kain baru — belum ada di inventori")
                                        .font(.system(size: 12))
                                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(OuraTheme.Colors.accentLight)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(OuraTheme.Colors.background)
            }
            .background(OuraTheme.Colors.background)
            .navigationTitle("Pilih Kain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }.foregroundStyle(OuraTheme.Colors.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Size detail (HPP + Price Advisor)

struct ProdukSizeDetailView: View {
    @EnvironmentObject private var api: APIService

    let productSize: ProductSizeDetail

    @State private var size: ProductSizeDetail
    @State private var isEditing = false
    @State private var editSellingPrice: Double?
    @State private var editReorderMin: Double?
    @State private var editHppFabric: Double?
    @State private var editHppPooled: Double?
    @State private var editHppHardware: Double?
    @State private var editHppLabor: Double?
    @State private var editHppOverhead: Double?
    @State private var showAdvisor = false
    @State private var isSaving = false
    @State private var showAddStock = false
    @State private var errorMsg: String?

    init(productSize: ProductSizeDetail) {
        self.productSize = productSize
        self._size = State(initialValue: productSize)
    }

    private var editHppTotal: Double {
        (editHppFabric ?? 0) + (editHppPooled ?? 0) + (editHppHardware ?? 0)
        + (editHppLabor ?? 0) + (editHppOverhead ?? 0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuraTheme.Spacing.sectionGap) {
                infoCard
                hppSection
                priceAdvisorSection
                if let err = errorMsg {
                    Text(err).font(.system(size: 13)).foregroundStyle(OuraTheme.Colors.dangerText).padding(.horizontal)
                }
            }
            .padding(.horizontal, OuraTheme.Spacing.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(OuraTheme.Colors.background)
        .navigationTitle(size.displayLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Simpan" : "Edit") {
                    if isEditing { Task { await saveEdits() } }
                    else { startEdit() }
                }
                .foregroundStyle(isSaving ? OuraTheme.Colors.textDisabled : OuraTheme.Colors.accent)
                .disabled(isSaving)
            }
        }
        .task { await refreshSize() }
        .sheet(isPresented: $showAddStock, onDismiss: { Task { await refreshSize() } }) {
            TambahStokSheet(size: size)
        }
    }

    private func refreshSize() async {
        guard let fresh = try? await api.getProductSizes(sku: size.productSku),
              let updated = fresh.first(where: { $0.id == size.id }) else { return }
        size = updated
    }

    // MARK: - Info card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                stockBadge
                Spacer()
                Text(size.productSku)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(OuraTheme.Colors.border).clipShape(Capsule())
            }
            Divider().overlay(OuraTheme.Colors.separator)
            if isEditing {
                CurrencyInputField(label: "Harga Jual", value: $editSellingPrice)
                NumericInputField(label: "Reorder Min (pcs)", value: $editReorderMin, unit: "pcs")
            } else {
                stockRow
                if let fabric = size.fabricVariantName { infoRow("Jenis Kain", value: fabric) }
                if let price = size.sellingPrice { infoRow("Harga Jual", value: price.rupiahFormatted) }
                if let margin = size.marginPct { infoRow("Margin", value: String(format: "%.1f%%", margin * 100)) }
                if let min = size.reorderMinQty { infoRow("Reorder Min", value: String(format: "%.0f pcs", min)) }
            }
        }
        .padding(OuraTheme.Spacing.cardPad)
        .ouraCard()
    }

    private var stockBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(size.currentStockQty == 0 ? OuraTheme.Colors.dangerText
                    : size.isLowStock ? OuraTheme.Colors.warningText
                    : OuraTheme.Colors.greenAccent)
                .frame(width: 8, height: 8)
            Text("\(size.currentStockQty) pcs tersedia")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
        }
    }

    // MARK: - HPP section (batch / manual / edit)

    @ViewBuilder
    private var hppSection: some View {
        if isEditing && size.latestHppBreakdown == nil {
            editHppCard
        } else if let hpp = size.latestHppBreakdown {
            hppCard(hpp, isManual: false)
        } else if let hpp = size.manualHppBreakdown {
            hppCard(hpp, isManual: true)
        }
    }

    private func hppCard(_ hpp: HPPBreakdown, isManual: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                OuraSectionHeader(title: isManual ? "RINCIAN HPP" : "HPP Breakdown")
                if isManual {
                    Text("manual")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.warningText)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(OuraTheme.Colors.warningBg)
                        .clipShape(Capsule())
                }
            }
            hppRow("Kain", value: hpp.fabric, total: hpp.total)
            if !isManual, hpp.fabricItems.count > 1 {
                ForEach(hpp.fabricItems, id: \.name) { hppSubRow($0.name, cost: $0.cost) }
            }
            hppRow("Bahan Pooled", value: hpp.pooledMaterial, total: hpp.total)
            hppRow("Hardware", value: hpp.hardware, total: hpp.total)
            if !isManual, hpp.hardwareItems.count > 1 {
                ForEach(hpp.hardwareItems, id: \.name) { hppSubRow($0.name, cost: $0.cost) }
            }
            hppRow("Tenaga Kerja", value: hpp.labor, total: hpp.total)
            hppRow("Overhead", value: hpp.overhead, total: hpp.total)
            Divider().overlay(OuraTheme.Colors.separator)
            HStack {
                Text("HPP Total").font(.system(size: 14, weight: .bold)).foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                Text(hpp.total.rupiahFormatted).font(.system(size: 16, weight: .bold)).foregroundStyle(OuraTheme.Colors.accent)
            }
        }
        .padding(OuraTheme.Spacing.cardPad)
        .ouraCard()
    }

    private var editHppCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                OuraSectionHeader(title: "RINCIAN HPP")
                Text("manual")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.warningText)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(OuraTheme.Colors.warningBg)
                    .clipShape(Capsule())
            }
            CurrencyInputField(label: "Kain (fabric)", value: $editHppFabric)
            CurrencyInputField(label: "Bahan Pooled", value: $editHppPooled)
            CurrencyInputField(label: "Hardware", value: $editHppHardware)
            CurrencyInputField(label: "Tenaga Kerja", value: $editHppLabor)
            CurrencyInputField(label: "Overhead", value: $editHppOverhead)
            if editHppTotal > 0 {
                Divider().overlay(OuraTheme.Colors.separator)
                HStack {
                    Text("HPP Total").font(.system(size: 14, weight: .bold)).foregroundStyle(OuraTheme.Colors.textPrimary)
                    Spacer()
                    Text(editHppTotal.rupiahFormatted).font(.system(size: 15, weight: .bold)).foregroundStyle(OuraTheme.Colors.accent)
                }
            }
        }
        .padding(OuraTheme.Spacing.cardPad)
        .ouraCard()
    }

    private func hppRow(_ label: String, value: Double, total: Double) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(OuraTheme.Colors.textSecondary)
            Spacer()
            Text(value.rupiahFormatted).font(.system(size: 13, weight: .medium)).foregroundStyle(OuraTheme.Colors.textPrimary)
            Text(String(format: "(%.0f%%)", total > 0 ? value / total * 100 : 0))
                .font(.system(size: 11)).foregroundStyle(OuraTheme.Colors.textTertiary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private func hppSubRow(_ label: String, cost: Double) -> some View {
        HStack {
            Text("· \(label)")
                .font(.system(size: 12))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .padding(.leading, 12)
            Spacer()
            Text(cost.rupiahFormatted)
                .font(.system(size: 12))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
        }
    }

    // MARK: - Price Advisor (always visible, uses shared component)

    private var priceAdvisorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { withAnimation { showAdvisor.toggle() } } label: {
                HStack {
                    Image(systemName: "lightbulb.fill").foregroundStyle(OuraTheme.Colors.warningText)
                    Text("Price Advisor").font(.system(size: 15, weight: .semibold)).foregroundStyle(OuraTheme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: showAdvisor ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12)).foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .padding(OuraTheme.Spacing.cardPad)
                .background(OuraTheme.Colors.warningBg)
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.card))
            }
            .buttonStyle(.plain)

            if showAdvisor {
                if let hpp = effectiveHppForAdvisor {
                    VStack(spacing: 0) {
                        Divider().overlay(OuraTheme.Colors.separator)
                        PriceAdvisorSection(hpp: hpp, itemLabel: size.displayLabel) { price in
                            Task { await applyPrice(price) }
                        }
                    }
                    .ouraCard()
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                        Text("Isi HPP manual di atas untuk mengaktifkan Price Advisor.")
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OuraTheme.Colors.border.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                }
            }
        }
    }

    // In edit mode, use live editHppTotal; in read mode, use stored effectiveHppBreakdown
    private var effectiveHppForAdvisor: HPPBreakdown? {
        if isEditing && size.latestHppBreakdown == nil && editHppTotal > 0 {
            return HPPBreakdown(fabric: editHppFabric ?? 0,
                                pooledMaterial: editHppPooled ?? 0,
                                hardware: editHppHardware ?? 0,
                                labor: editHppLabor ?? 0,
                                overhead: editHppOverhead ?? 0,
                                total: editHppTotal)
        }
        return size.effectiveHppBreakdown
    }

    // MARK: - Supporting rows

    private var stockRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Stok")
                    .font(.system(size: 13))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                Text("\(size.currentStockQty) pcs")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                if size.productionStockQty > 0 || size.manualStockQty > 0 {
                    HStack(spacing: 10) {
                        if size.productionStockQty > 0 {
                            Label("\(size.productionStockQty) produksi", systemImage: "gearshape.fill")
                        }
                        if size.manualStockQty > 0 {
                            Label("\(size.manualStockQty) manual", systemImage: "hand.draw.fill")
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
            }
            Spacer()
            Button { showAddStock = true } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus.circle").font(.system(size: 12))
                    Text("Tambah").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(OuraTheme.Colors.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(OuraTheme.Colors.textSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundStyle(OuraTheme.Colors.textPrimary)
        }
    }

    // MARK: - Edit lifecycle

    private func startEdit() {
        editSellingPrice = size.sellingPrice
        editReorderMin = size.reorderMinQty
        if let manualHpp = size.manualHppBreakdown {
            editHppFabric   = manualHpp.fabric
            editHppPooled   = manualHpp.pooledMaterial
            editHppHardware = manualHpp.hardware
            editHppLabor    = manualHpp.labor
            editHppOverhead = manualHpp.overhead
        }
        withAnimation { isEditing = true }
    }

    private func saveEdits() async {
        isSaving = true; errorMsg = nil; defer { isSaving = false }
        let includeManualHpp = editHppTotal > 0 && size.latestHppBreakdown == nil
        do {
            let updated = try await api.patchProductSize(sku: size.productSku, sizeId: size.id,
                PatchProductSizeRequest(
                    sellingPrice: editSellingPrice,
                    reorderMinQty: editReorderMin,
                    manualHppFabric:   includeManualHpp ? (editHppFabric   ?? 0) : nil,
                    manualHppPooled:   includeManualHpp ? (editHppPooled   ?? 0) : nil,
                    manualHppHardware: includeManualHpp ? (editHppHardware ?? 0) : nil,
                    manualHppLabor:    includeManualHpp ? (editHppLabor    ?? 0) : nil,
                    manualHppOverhead: includeManualHpp ? (editHppOverhead ?? 0) : nil))
            size = updated
            withAnimation { isEditing = false }
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }

    private func applyPrice(_ price: Double) async {
        do {
            _ = try await api.patchProductSize(sku: size.productSku, sizeId: size.id,
                PatchProductSizeRequest(sellingPrice: price))
            await refreshSize()
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }
}

// MARK: - Tambah stok manual sheet

struct TambahStokSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let size: ProductSizeDetail

    @State private var qty: Double? = nil
    @State private var note: String = ""
    @State private var isSaving = false
    @State private var errorMsg: String?

    // Gunakan stok bahan toggle
    @State private var deductBahan: Bool = false
    @State private var relatedSpec: PatternSpec? = nil
    @State private var relatedMaterial: Material? = nil
    @State private var manualCutWidth: Double? = nil
    @State private var manualCutLength: Double? = nil
    @State private var isLoadingSpec: Bool = false

    private var hasFabricVariant: Bool { size.fabricVariantName != nil }

    private var canSave: Bool {
        guard (qty ?? 0) > 0 else { return false }
        if deductBahan && relatedSpec == nil {
            return relatedMaterial != nil && (manualCutWidth ?? 0) > 0 && (manualCutLength ?? 0) > 0
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NumericInputField(label: "Jumlah", value: $qty, unit: "pcs")
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                } header: { OuraSectionHeader(title: "Jumlah") }

                if hasFabricVariant {
                    Section {
                        Toggle("Gunakan stok bahan", isOn: $deductBahan)
                            .listRowBackground(OuraTheme.Colors.surfaceCard)
                    } header: { OuraSectionHeader(title: "Bahan") }
                      footer: {
                          if deductBahan {
                              if isLoadingSpec {
                                  Text("Mengecek resep...")
                              } else if let spec = relatedSpec {
                                  let fabric = spec.fabrics.first
                                  let dims = fabric.map { "\(Int($0.cutLengthCm)) × \(Int($0.cutWidthCm)) cm" } ?? "-"
                                  Text("Resep ditemukan (\(dims)). Stok \(size.fabricVariantName ?? "bahan") akan dikurangi otomatis.")
                              } else {
                                  Text("Resep belum ada untuk varian ini. Masukkan ukuran kain yang dipakai.")
                              }
                          } else {
                              Text("Jika dicentang, stok \(size.fabricVariantName ?? "bahan") akan dikurangi sesuai resep.")
                          }
                      }

                    if deductBahan && !isLoadingSpec && relatedSpec == nil {
                        Section {
                            NumericInputField(label: "Panjang (cm)", value: $manualCutLength, unit: "cm")
                                .listRowBackground(OuraTheme.Colors.surfaceCard)
                            NumericInputField(label: "Lebar (cm)", value: $manualCutWidth, unit: "cm")
                                .listRowBackground(OuraTheme.Colors.surfaceCard)
                        } header: { OuraSectionHeader(title: "Ukuran Kain") }
                    }
                }

                Section {
                    TextField("Catatan (opsional)", text: $note)
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                } header: { OuraSectionHeader(title: "Catatan") }

                if let err = errorMsg {
                    Section {
                        Text(err).foregroundStyle(OuraTheme.Colors.dangerText)
                            .listRowBackground(OuraTheme.Colors.dangerBg)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OuraTheme.Colors.background)
            .navigationTitle("Tambah Stok Manual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }.foregroundStyle(OuraTheme.Colors.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { Task { await save() } }
                        .foregroundStyle(canSave ? OuraTheme.Colors.accent : OuraTheme.Colors.textDisabled)
                        .disabled(!canSave || isSaving)
                }
            }
            .task {
                guard hasFabricVariant else { return }
                isLoadingSpec = true
                defer { isLoadingSpec = false }
                do {
                    let specs = try await api.getPatternSpecsForSize(productSku: size.productSku, sizeLabel: size.sizeLabel)
                    relatedSpec = specs.first(where: { $0.productSizeId == size.id && $0.isActive })
                    let materials = try await api.getMaterials()
                    relatedMaterial = materials.first(where: { $0.name == size.fabricVariantName })
                } catch {}
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() async {
        guard let q = qty, q > 0 else { return }
        isSaving = true; defer { isSaving = false }
        errorMsg = nil
        do {
            if deductBahan {
                if let spec = relatedSpec {
                    _ = try await api.addStockFromBahan(sku: size.productSku, sizeId: size.id,
                                                        qty: Int(q), specId: spec.id)
                } else if let mat = relatedMaterial,
                          let cutW = manualCutWidth, cutW > 0,
                          let cutL = manualCutLength, cutL > 0 {
                    _ = try await api.addStockManual(sku: size.productSku, sizeId: size.id,
                                                     qty: Int(q), materialId: mat.id,
                                                     cutWidthCm: cutW, cutLengthCm: cutL)
                } else {
                    errorMsg = "Data bahan tidak lengkap. Nonaktifkan toggle atau lengkapi ukuran kain."
                    return
                }
            } else {
                _ = try await api.adjustStock(sku: size.productSku, sizeId: size.id,
                                              qty: Int(q), reason: "adjustment",
                                              note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note)
            }
            dismiss()
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }
}
