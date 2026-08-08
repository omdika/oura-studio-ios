import SwiftUI

struct OptimasiView: View {
    @EnvironmentObject private var api: APIService

    var onLayoutSaved: (() -> Void)? = nil

    enum Step { case selectPurchase, selectCandidates, showResults }

    @State private var step: Step = .selectPurchase
    @State private var fabricPurchases: [(material: Material, purchase: MaterialPurchase)] = []
    @State private var selectedPurchase: MaterialPurchase?
    @State private var selectedMaterial: Material?
    @State private var patternSpecs: [PatternSpec] = []
    @State private var candidates: [UUID: Int] = [:]  // patternSpecId → minQty (0 = no minimum)
    @State private var layouts: [OptimizerLayout] = []
    @State private var isLoading = false
    @State private var isCalculating = false
    @State private var errorMsg: String?
    @State private var isSaving = false
    @State private var savedBatch: ProductionBatch?

    private var filteredSpecs: [PatternSpec] {
        guard let materialId = selectedPurchase?.materialId else { return [] }
        return patternSpecs.filter { spec in
            spec.isActive && spec.fabrics.contains { $0.materialId == materialId }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Optimasi Pola")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, OuraTheme.Spacing.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: OuraTheme.Spacing.sectionGap) {
                    stepHeader

                    switch step {
                    case .selectPurchase:  selectPurchaseStep
                    case .selectCandidates: selectCandidatesStep
                    case .showResults:     resultsStep
                    }

                    if let err = errorMsg {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.dangerText)
                            .padding()
                            .background(OuraTheme.Colors.dangerBg)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                    }
                }
                .padding(.horizontal, OuraTheme.Spacing.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
        .background(OuraTheme.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadData() }
    }

    // MARK: - Step header

    private var stepHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array([("1", "Pilih Kain"), ("2", "Pola"), ("3", "Hasil")].enumerated()), id: \.offset) { idx, item in
                let isActive = (step == .selectPurchase && idx == 0) ||
                               (step == .selectCandidates && idx == 1) ||
                               (step == .showResults && idx == 2)
                let isDone = (step == .selectCandidates && idx == 0) ||
                             (step == .showResults && idx <= 1)

                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(isDone ? OuraTheme.Colors.accent : (isActive ? OuraTheme.Colors.accentLight : OuraTheme.Colors.border))
                            .frame(width: 24, height: 24)
                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text(item.0)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(isActive ? OuraTheme.Colors.accent : OuraTheme.Colors.textTertiary)
                        }
                    }
                    Text(item.1)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? OuraTheme.Colors.textPrimary : OuraTheme.Colors.textTertiary)
                }

                if idx < 2 {
                    Rectangle()
                        .fill(isDone ? OuraTheme.Colors.accent : OuraTheme.Colors.border)
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 6)
                }
            }
        }
        .padding(OuraTheme.Spacing.cardPad)
        .ouraCard()
    }

    // MARK: - Step 1: Select purchase

    private var selectPurchaseStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            OuraSectionHeader(title: "Pilih Gulungan Kain")

            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if fabricPurchases.isEmpty {
                Text("Tidak ada pembelian kain tersedia")
                    .font(.system(size: 14))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                    .padding()
                    .ouraCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(fabricPurchases.enumerated()), id: \.element.purchase.id) { idx, item in
                        purchaseRow(material: item.material, purchase: item.purchase)
                        if idx < fabricPurchases.count - 1 {
                            Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                        }
                    }
                }
                .ouraCard()
            }
        }
    }

    private func purchaseRow(material: Material, purchase: MaterialPurchase) -> some View {
        let isSelected = selectedPurchase?.id == purchase.id
        return Button {
            selectedPurchase = purchase
            selectedMaterial = material
            withAnimation { step = .selectCandidates }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(material.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    HStack(spacing: 6) {
                        if let l = purchase.lengthCm, let w = purchase.widthCm {
                            Text("\(w, specifier: "%.0f") × \(l, specifier: "%.0f") cm")
                                .font(.system(size: 12))
                                .foregroundStyle(OuraTheme.Colors.textSecondary)
                        }
                        if let rem = purchase.remainingLengthCm, let l = purchase.lengthCm {
                            OuraTag(
                                text: String(format: "%.0f cm sisa", rem),
                                color: rem < l * 0.2 ? OuraTheme.Colors.warningText : OuraTheme.Colors.blueAccent,
                                bg: rem < l * 0.2 ? OuraTheme.Colors.warningBg : OuraTheme.Colors.blueBg
                            )
                        }
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(isSelected ? OuraTheme.Colors.accentLight : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Select candidates

    private var selectCandidatesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let p = selectedPurchase {
                HStack {
                    OuraSectionHeader(title: "Kain Dipilih")
                    Spacer()
                    Button("Ganti") { withAnimation { step = .selectPurchase } }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if let mat = selectedMaterial {
                        Text(mat.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                    }
                    Text("\(p.lengthCm.map { "\($0, specifier: "%.0f") cm" } ?? "") · \(p.totalCost.rupiahFormatted)")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                }
            }

            OuraSectionHeader(title: "Pilih Pola Kandidat")
                .padding(.top, 8)

            if filteredSpecs.isEmpty {
                Text("Tidak ada resep pola aktif untuk kain ini")
                    .font(.system(size: 14))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                    .padding()
                    .ouraCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredSpecs.enumerated()), id: \.element.id) { idx, spec in
                        candidateRow(spec: spec)
                        if idx < filteredSpecs.count - 1 {
                            Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                        }
                    }
                }
                .ouraCard()
            }

            if !candidates.isEmpty {
                OuraPrimaryButton(title: isCalculating ? "Menghitung..." : "Hitung Optimasi", isLoading: isCalculating) {
                    Task { await calculateLayouts() }
                }
            }
        }
    }

    private func candidateRow(spec: PatternSpec) -> some View {
        let isSelected = candidates[spec.id] != nil
        let matchedFabric = spec.fabrics.first(where: { $0.materialId == selectedPurchase?.materialId })
            ?? spec.fabrics.first
        return HStack(spacing: 12) {
            Button {
                if isSelected { candidates.removeValue(forKey: spec.id) }
                else { candidates[spec.id] = 0 }
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? OuraTheme.Colors.accent : OuraTheme.Colors.border)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(spec.productName) · \(spec.sizeLabel)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                if let fabric = matchedFabric {
                    Text("\(fabric.materialName) · \(fabric.cutLengthCm, specifier: "%.0f")×\(fabric.cutWidthCm, specifier: "%.0f") cm")
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                }
            }

            Spacer()

            if isSelected {
                HStack(spacing: 6) {
                    Text("Min:")
                        .font(.system(size: 11))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                    HStack(spacing: 0) {
                        Button {
                            let cur = candidates[spec.id] ?? 0
                            if cur > 0 { candidates[spec.id] = cur - 1 }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(OuraTheme.Colors.accent)
                                .frame(width: 26, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Text("\(candidates[spec.id] ?? 0)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                            .frame(width: 28)
                            .multilineTextAlignment(.center)

                        Button {
                            candidates[spec.id] = (candidates[spec.id] ?? 0) + 1
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(OuraTheme.Colors.accent)
                                .frame(width: 26, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .background(OuraTheme.Colors.border.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Step 3: Results

    private var resultsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let batch = savedBatch {
                savedSuccessView(batch: batch)
            } else {
                HStack {
                    OuraSectionHeader(title: "Hasil Optimasi")
                    Spacer()
                    Button("Ubah") { withAnimation { step = .selectCandidates } }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.accent)
                }

                if layouts.isEmpty {
                    Text("Tidak ada layout yang dapat dihitung")
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .padding()
                        .ouraCard()
                } else {
                    ForEach(layouts) { layout in
                        layoutCard(layout)
                    }
                }
            }
        }
    }

    private func savedSuccessView(batch: ProductionBatch) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(OuraTheme.Colors.greenAccent)
                Text("Batch Produksi Dibuat!")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Text(batch.batchLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                Text(batch.batchSizeDetail)
                    .font(.system(size: 13))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                Text("Siap dikonfirmasi di tab Produksi")
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .ouraCard()

            OuraPrimaryButton(title: "Lanjut ke Produksi") {
                onLayoutSaved?()
                resetState()
            }

            Button("Mulai Optimasi Baru") {
                resetState()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(OuraTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
        }
    }

    private func layoutCard(_ layout: OptimizerLayout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(layout.strategy.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                Text("\(layout.wastePct * 100, specifier: "%.1f")% waste")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        layout.wastePct > 0.2
                            ? OuraTheme.Colors.dangerText
                            : OuraTheme.Colors.greenAccent
                    )
            }

            Divider().overlay(OuraTheme.Colors.separator)

            HStack {
                statCell(label: "Total Qty", value: "\(layout.totalQty) pcs")
                Spacer()
                if let profit = layout.estimatedProfit {
                    statCell(label: "Est. Profit", value: profit.rupiahFormatted)
                }
            }

            ForEach(layout.items) { item in
                HStack {
                    Text("\(item.productName) · \(item.sizeLabel)")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    Spacer()
                    Text("\(item.qtySuggested) pcs")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                }
            }

            Button {
                Task { await saveLayout(layout) }
            } label: {
                HStack {
                    Spacer()
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Gunakan Layout Ini")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Spacer()
                }
                .frame(height: 40)
                .foregroundStyle(OuraTheme.Colors.accent)
                .background(OuraTheme.Colors.accentLight)
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
        }
        .padding(OuraTheme.Spacing.cardPad)
        .ouraCard()
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
        }
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        let mats = (try? await api.getMaterials()) ?? []
        let fabricMats = mats.filter { $0.category == .fabric }
        var pairs: [(material: Material, purchase: MaterialPurchase)] = []
        for mat in fabricMats {
            let purchases = (try? await api.getPurchases(materialId: mat.id)) ?? []
            let available = purchases.filter { p in
                if let rem = p.remainingLengthCm { return rem > 0 }
                return p.lengthCm != nil
            }
            pairs.append(contentsOf: available.map { (material: mat, purchase: $0) })
        }
        fabricPurchases = pairs
        patternSpecs = (try? await api.getPatternSpecs()) ?? []
        isLoading = false
    }

    private func calculateLayouts() async {
        guard let purchase = selectedPurchase, !candidates.isEmpty else { return }
        isCalculating = true
        errorMsg = nil
        defer { isCalculating = false }

        let candidateList = candidates.compactMap { (specId, minQty) -> OptimizerCandidate? in
            guard let spec = patternSpecs.first(where: { $0.id == specId }) else { return nil }
            return OptimizerCandidate(
                productSizeId: spec.productSizeId,
                patternSpecId: specId,
                minQty: minQty == 0 ? nil : minQty
            )
        }

        let req = SuggestOptimizerRequest(
            materialPurchaseId: purchase.id,
            candidates: candidateList
        )

        do {
            layouts = try await api.suggestLayouts(req)
            withAnimation { step = .showResults }
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func saveLayout(_ layout: OptimizerLayout) async {
        guard let purchase = selectedPurchase else { return }
        isSaving = true
        errorMsg = nil
        defer { isSaving = false }

        let items = layout.items.map {
            CreateLayoutRequest.CreateLayoutItemInput(
                productSizeId: $0.productSizeId,
                patternSpecId: $0.patternSpecId,
                orientation: $0.orientation,
                qtySuggested: $0.qtySuggested,
                fabricLengthUsedCm: $0.fabricLengthUsedCm,
                costPerPiece: $0.costPerPiece
            )
        }

        do {
            let cutting = try await api.createLayout(CreateLayoutRequest(
                materialPurchaseId: purchase.id,
                strategy: layout.strategy.rawValue,
                items: items
            ))
            let batch = try await api.createProductionBatch(cuttingLayoutId: cutting.id)
            withAnimation { savedBatch = batch }
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func resetState() {
        step = .selectPurchase
        candidates = [:]
        selectedPurchase = nil
        selectedMaterial = nil
        savedBatch = nil
        layouts = []
    }
}
