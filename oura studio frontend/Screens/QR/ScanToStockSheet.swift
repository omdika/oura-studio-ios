import SwiftUI

struct ScanToStockSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let size: ProductSizeDetail
    let dismissParent: () -> Void

    @State private var qty: Int = 1
    @State private var reason: StockReason = .production
    @State private var note: String = ""
    @State private var isSaving = false
    @State private var errorMsg: String?
    @State private var didSucceed = false

    // HPP section
    @State private var showHppSection: Bool = false
    @State private var editHppFabric: Double? = nil
    @State private var editHppPooled: Double? = nil
    @State private var editHppHardware: Double? = nil
    @State private var editHppLabor: Double? = nil
    @State private var editHppOverhead: Double? = nil
    @State private var editSellingPrice: Double? = nil

    // Material deduction
    @State private var deductBahan: Bool = true
    @State private var relatedSpec: PatternSpec? = nil
    @State private var isLoadingSpec: Bool = false

    enum StockReason: String, CaseIterable {
        case production = "production"
        case adjustment = "adjustment"
        var displayName: String { self == .production ? "Dari Produksi" : "Koreksi Stok" }
    }

    private var editHppTotal: Double {
        (editHppFabric ?? 0) + (editHppPooled ?? 0) + (editHppHardware ?? 0)
        + (editHppLabor ?? 0) + (editHppOverhead ?? 0)
    }
    private var hasManualHpp: Bool { editHppTotal > 0 }
    private var hasFabricVariant: Bool { size.fabricVariantName != nil }
    private var canSave: Bool { qty >= 1 && !isSaving }

    var body: some View {
        NavigationStack {
            if didSucceed {
                successView
            } else {
                formView
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await loadSpec() }
    }

    // MARK: - Form

    private var formView: some View {
        Form {
            // Product info
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(size.productName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Text(size.displayLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    Text("Stok saat ini: \(size.currentStockQty) pcs")
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }
            .listSectionSeparator(.hidden)

            // Stock input
            Section {
                HStack {
                    Text("Jumlah Masuk")
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Spacer()
                    HStack(spacing: 16) {
                        Button { if qty > 1 { qty -= 1 } } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(qty > 1 ? OuraTheme.Colors.accent : OuraTheme.Colors.border)
                        }
                        .buttonStyle(.plain)
                        .disabled(qty <= 1)

                        Text("\(qty)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                            .frame(minWidth: 28, alignment: .center)

                        Button { qty += 1 } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(OuraTheme.Colors.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Alasan")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    HStack(spacing: 8) {
                        ForEach(StockReason.allCases, id: \.self) { r in
                            let selected = reason == r
                            Button { reason = r } label: {
                                Text(r.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(selected ? .white : OuraTheme.Colors.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(selected ? OuraTheme.Colors.accent : OuraTheme.Colors.surfaceSheet)
                                    .clipShape(Capsule())
                                    .overlay(Capsule()
                                        .stroke(selected ? Color.clear : OuraTheme.Colors.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: reason)
                        }
                    }
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                TextField("Catatan (opsional)", text: $note)
                    .font(.system(size: 14))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            } header: {
                OuraSectionHeader(title: "Stok Masuk")
            }
            .listSectionSeparator(.hidden)

            // HPP section — only for "Dari Produksi"
            if reason == .production {
                if let existingHpp = size.effectiveHppBreakdown {
                    hppExistingSection(existingHpp)
                } else {
                    hppNudgeSection
                    if showHppSection {
                        hppInputSection
                        if editHppTotal > 0 {
                            hppPriceAdvisorSection
                        }
                    }
                }

                // Material deduction toggle
                if hasFabricVariant {
                    bahanDeductionSection
                }
            }

            // Error
            if let err = errorMsg {
                Section {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.dangerText)
                        .listRowBackground(OuraTheme.Colors.dangerBg)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OuraTheme.Colors.background)
        .navigationTitle("Stok Masuk")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Batal") { dismiss() }
                    .foregroundStyle(OuraTheme.Colors.accent)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Simpan") { Task { await save() } }
                        .foregroundStyle(canSave ? OuraTheme.Colors.accent : OuraTheme.Colors.textDisabled)
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - HPP: existing (read-only)

    private func hppExistingSection(_ hpp: HPPBreakdown) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                let isManual = size.latestHppBreakdown == nil
                HStack(spacing: 6) {
                    Text(isManual ? "HPP · MANUAL" : "HPP Breakdown")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                    if isManual {
                        Text("manual")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.warningText)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(OuraTheme.Colors.warningBg)
                            .clipShape(Capsule())
                    }
                }
                hppReadRow("Kain", value: hpp.fabric)
                hppReadRow("Bahan Pooled", value: hpp.pooledMaterial)
                hppReadRow("Hardware", value: hpp.hardware)
                hppReadRow("Tenaga Kerja", value: hpp.labor)
                hppReadRow("Overhead", value: hpp.overhead)
                Divider().overlay(OuraTheme.Colors.separator)
                HStack {
                    Text("HPP Total")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Spacer()
                    Text(hpp.total.rupiahFormatted)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
            .listRowBackground(OuraTheme.Colors.surfaceCard)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            VStack(spacing: 0) {
                Divider().overlay(OuraTheme.Colors.separator)
                PriceAdvisorSection(hpp: hpp, itemLabel: size.displayLabel) { price in
                    editSellingPrice = price
                }
            }
            .listRowBackground(OuraTheme.Colors.surfaceCard)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        } header: { OuraSectionHeader(title: "Rincian HPP") }
        .listSectionSeparator(.hidden)
    }

    private func hppReadRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Spacer()
            Text(value.rupiahFormatted)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(value > 0 ? OuraTheme.Colors.textPrimary : OuraTheme.Colors.textTertiary)
        }
    }

    // MARK: - HPP: nudge (no HPP yet)

    private var hppNudgeSection: some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showHppSection.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.warningText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HPP belum ada")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                        Text("Price Advisor tidak aktif. Atur sekarang?")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: showHppSection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(OuraTheme.Colors.warningBg)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }
        .listSectionSeparator(.hidden)
    }

    // MARK: - HPP: input fields

    private var hppInputSection: some View {
        Section {
            CurrencyInputField(label: "Kain (fabric)", value: $editHppFabric)
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            CurrencyInputField(label: "Bahan Pooled", value: $editHppPooled)
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            CurrencyInputField(label: "Hardware", value: $editHppHardware)
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            CurrencyInputField(label: "Tenaga Kerja", value: $editHppLabor)
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            CurrencyInputField(label: "Overhead", value: $editHppOverhead)
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

            if editHppTotal > 0 {
                HStack {
                    Text("HPP Total")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Spacer()
                    Text(editHppTotal.rupiahFormatted)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
        } header: { OuraSectionHeader(title: "Rincian HPP Manual") }
        .listSectionSeparator(.hidden)
    }

    // MARK: - HPP: Price Advisor (after manual input)

    private var hppPriceAdvisorSection: some View {
        Section {
            let hpp = HPPBreakdown(fabric: editHppFabric ?? 0,
                                   pooledMaterial: editHppPooled ?? 0,
                                   hardware: editHppHardware ?? 0,
                                   labor: editHppLabor ?? 0,
                                   overhead: editHppOverhead ?? 0,
                                   total: editHppTotal)
            VStack(spacing: 0) {
                Divider().overlay(OuraTheme.Colors.separator)
                PriceAdvisorSection(hpp: hpp, itemLabel: size.displayLabel) { price in
                    editSellingPrice = price
                }
            }
            .listRowBackground(OuraTheme.Colors.surfaceCard)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .listSectionSeparator(.hidden)
    }

    // MARK: - Material deduction toggle

    private var bahanDeductionSection: some View {
        Section {
            if isLoadingSpec {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Cek pola produksi…")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            } else if let spec = relatedSpec {
                Toggle(isOn: $deductBahan) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Kurangi bahan otomatis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                        Text("Pola: \(spec.sizeLabel) · \(spec.fabricMaterialName)")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }
                }
                .tint(OuraTheme.Colors.accent)
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }
        } header: { OuraSectionHeader(title: "Bahan") }
        .listSectionSeparator(.hidden)
    }

    // MARK: - Success view

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(OuraTheme.Colors.greenAccent)
            Text("Stok masuk \(qty) pcs")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
            Text(size.displayLabel)
                .font(.system(size: 15))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Text("Stok baru: ~\(size.currentStockQty + qty) pcs")
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
            if let price = editSellingPrice {
                Text("Harga jual: \(price.rupiahFormatted)")
                    .font(.system(size: 13))
                    .foregroundStyle(OuraTheme.Colors.accent)
            }
            Spacer()
            VStack(spacing: 12) {
                Button {
                    dismiss()
                    dismissParent()
                } label: {
                    Text("Selesai")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(OuraTheme.Colors.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                }
                .buttonStyle(.plain)

                Button { dismiss() } label: {
                    Text("Scan Lagi")
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationTitle("Berhasil")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Load PatternSpec

    private func loadSpec() async {
        guard hasFabricVariant, reason == .production else {
            deductBahan = false
            return
        }
        isLoadingSpec = true
        defer { isLoadingSpec = false }
        let specs = (try? await api.getPatternSpecsForSize(productSku: size.productSku, sizeLabel: size.sizeLabel)) ?? []
        relatedSpec = specs.first(where: { $0.productSizeId == size.id && $0.isActive })
        if relatedSpec == nil { deductBahan = false }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMsg = nil
        defer { isSaving = false }
        do {
            // 1. Add stock — use addStockFromBahan if spec exists and toggle is ON
            if reason == .production, deductBahan, let spec = relatedSpec {
                _ = try await api.addStockFromBahan(
                    sku: size.productSku, sizeId: size.id, qty: qty, specId: spec.id)
            } else {
                _ = try await api.adjustStock(
                    sku: size.productSku, sizeId: size.id, qty: qty,
                    reason: reason.rawValue,
                    note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note)
            }

            // 2. Patch HPP and/or selling price if provided (best-effort — stock already saved)
            if hasManualHpp || editSellingPrice != nil {
                let patch = PatchProductSizeRequest(
                    sellingPrice: editSellingPrice,
                    manualHppFabric:   hasManualHpp ? (editHppFabric   ?? 0) : nil,
                    manualHppPooled:   hasManualHpp ? (editHppPooled   ?? 0) : nil,
                    manualHppHardware: hasManualHpp ? (editHppHardware ?? 0) : nil,
                    manualHppLabor:    hasManualHpp ? (editHppLabor    ?? 0) : nil,
                    manualHppOverhead: hasManualHpp ? (editHppOverhead ?? 0) : nil)
                _ = try? await api.patchProductSize(sku: size.productSku, sizeId: size.id, patch)
            }

            didSucceed = true
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
