import SwiftUI

struct OptimasiView: View {
    @EnvironmentObject private var api: APIService

    var onLayoutSaved: (() -> Void)? = nil

    enum Step { case selectSpec, selectRolls, showResults }

    private struct FabricLayoutResult {
        let materialId: UUID
        let materialName: String
        let purchaseId: UUID
        let layouts: [OptimizerLayout]
    }

    private struct CombinedLayoutResult: Identifiable {
        let strategyIndex: Int
        let fabricLayouts: [(materialId: UUID, materialName: String, layout: OptimizerLayout)]
        var bottleneckQty: Int { fabricLayouts.map { $0.layout.totalQty }.min() ?? 0 }
        var bottleneckFabricName: String? {
            guard fabricLayouts.count > 1 else { return nil }
            return fabricLayouts.min(by: { $0.layout.totalQty < $1.layout.totalQty })?.materialName
        }
        var strategy: OptimizerStrategy { fabricLayouts.first?.layout.strategy ?? .minWaste }
        var id: Int { strategyIndex }

        var displayItems: [(productName: String, sizeLabel: String, qty: Int)] {
            let perFabric: [[UUID: (String, String, Int)]] = fabricLayouts.map { fl in
                var bySize: [UUID: (String, String, Int)] = [:]
                for item in fl.layout.items {
                    let prev = bySize[item.productSizeId]
                    bySize[item.productSizeId] = (item.productName, item.sizeLabel, (prev?.2 ?? 0) + item.qtySuggested)
                }
                return bySize
            }
            let allIds = Set(perFabric.flatMap { $0.keys })
            return allIds.compactMap { sizeId -> (String, String, Int)? in
                let entries = perFabric.compactMap { $0[sizeId] }
                guard let first = entries.first else { return nil }
                return (first.0, first.1, entries.map { $0.2 }.min() ?? 0)
            }.sorted { $0.1 < $1.1 }
        }
    }

    @State private var step: Step = .selectSpec
    @State private var fabricPurchases: [(material: Material, purchase: MaterialPurchase)] = []
    @State private var patternSpecs: [PatternSpec] = []
    @State private var selectedSpec: PatternSpec?
    @State private var rollSelections: [UUID: MaterialPurchase] = [:]   // materialId → chosen roll
    @State private var targetQty: Int = 1
    @State private var fabricLayoutResults: [FabricLayoutResult] = []
    @State private var isLoading = false
    @State private var isCalculating = false
    @State private var errorMsg: String?
    @State private var isSaving = false
    @State private var savedBatch: ProductionBatch?

    private var canCalculate: Bool {
        guard let spec = selectedSpec else { return false }
        return spec.fabrics.allSatisfy { rollSelections[$0.materialId] != nil }
    }

    private var combinedResults: [CombinedLayoutResult] {
        guard let primary = fabricLayoutResults.first else { return [] }
        return primary.layouts.enumerated().compactMap { i, _ in
            let entries = fabricLayoutResults.compactMap { fr -> (UUID, String, OptimizerLayout)? in
                guard i < fr.layouts.count else { return nil }
                return (fr.materialId, fr.materialName, fr.layouts[i])
            }
            guard !entries.isEmpty else { return nil }
            return CombinedLayoutResult(
                strategyIndex: i,
                fabricLayouts: entries.map { (materialId: $0.0, materialName: $0.1, layout: $0.2) }
            )
        }
    }

    private var groupedSpecs: [(productName: String, specs: [PatternSpec])] {
        var dict: [String: [PatternSpec]] = [:]
        for spec in patternSpecs.filter(\.isActive) {
            dict[spec.productName, default: []].append(spec)
        }
        return dict
            .map { (productName: $0.key, specs: $0.value.sorted { $0.sizeLabel < $1.sizeLabel }) }
            .sorted { $0.productName < $1.productName }
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
                    case .selectSpec:   selectSpecStep
                    case .selectRolls:  selectRollsStep
                    case .showResults:  resultsStep
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
        .onAppear { if !isLoading { Task { await loadData() } } }
    }

    // MARK: - Step header

    private var stepHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array([("1", "Pilih Produk"), ("2", "Pilih Kain"), ("3", "Hasil")].enumerated()), id: \.offset) { idx, item in
                let isActive = (step == .selectSpec && idx == 0) ||
                               (step == .selectRolls && idx == 1) ||
                               (step == .showResults && idx == 2)
                let isDone   = (step == .selectRolls && idx == 0) ||
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

    // MARK: - Step 1: Pilih Produk

    private var selectSpecStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            OuraSectionHeader(title: "Pilih Produk")

            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if groupedSpecs.isEmpty {
                Text("Tidak ada resep pola aktif. Buat resep di tab Resep terlebih dahulu.")
                    .font(.system(size: 14))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                    .padding()
                    .ouraCard()
            } else {
                VStack(spacing: 10) {
                    ForEach(groupedSpecs, id: \.productName) { group in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(group.productName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(OuraTheme.Colors.textTertiary)
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                                .padding(.bottom, 2)

                            ForEach(Array(group.specs.enumerated()), id: \.element.id) { idx, spec in
                                specRow(spec)
                                if idx < group.specs.count - 1 {
                                    Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                                }
                            }
                        }
                        .ouraCard()
                    }
                }
            }
        }
    }

    private func specRow(_ spec: PatternSpec) -> some View {
        Button {
            selectedSpec = spec
            rollSelections = [:]
            withAnimation { step = .selectRolls }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(spec.sizeLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Text(spec.fabrics.map(\.materialName).joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if spec.fabrics.count > 1 {
                    OuraTag(
                        text: "\(spec.fabrics.count) kain",
                        color: OuraTheme.Colors.blueAccent,
                        bg: OuraTheme.Colors.blueBg
                    )
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Pilih Gulungan Kain

    private var selectRollsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let spec = selectedSpec {
                HStack {
                    OuraSectionHeader(title: "Produk Dipilih")
                    Spacer()
                    Button("Ganti") { withAnimation { step = .selectSpec } }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(spec.productName) · \(spec.sizeLabel)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Text(spec.fabrics.map(\.materialName).joined(separator: ", "))
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                }
                .padding(OuraTheme.Spacing.cardPad)
                .ouraCard()

                OuraSectionHeader(title: "Pilih Gulungan Kain")
                    .padding(.top, 4)

                ForEach(spec.fabrics) { fabric in
                    rollPickerSection(fabric: fabric)
                }

                if !canCalculate {
                    Text("Pilih satu gulungan untuk setiap kain yang dibutuhkan")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }

                // Target produksi
                VStack(alignment: .leading, spacing: 6) {
                    OuraSectionHeader(title: "Target Produksi")
                    HStack {
                        Text("Minimal pcs yang ingin diproduksi")
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        Spacer()
                        HStack(spacing: 0) {
                            Button {
                                if targetQty > 1 { targetQty -= 1 }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.accent)
                                    .frame(width: 34, height: 34)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Text("\(targetQty)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                                .frame(width: 36)
                                .multilineTextAlignment(.center)
                            Button {
                                targetQty += 1
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.accent)
                                    .frame(width: 34, height: 34)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .background(OuraTheme.Colors.border.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(OuraTheme.Spacing.cardPad)
                    .ouraCard()
                }
                .padding(.top, 4)

                OuraPrimaryButton(title: isCalculating ? "Menghitung..." : "Hitung Optimasi", isLoading: isCalculating) {
                    Task { await calculateLayouts() }
                }
                .disabled(!canCalculate)
                .opacity(canCalculate ? 1 : 0.5)
            }
        }
    }

    private func rollPickerSection(fabric: PatternFabric) -> some View {
        let rolls = fabricPurchases.filter { $0.material.id == fabric.materialId }
        return VStack(alignment: .leading, spacing: 6) {
            // Section label outside card — nama kain + dimensi potong + status pilihan
            HStack(spacing: 6) {
                Text(fabric.materialName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Text("· potong \(fabric.cutLengthCm, specifier: "%.0f")×\(fabric.cutWidthCm, specifier: "%.0f") cm")
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }

            // Card: hanya baris roll, tanpa nama kain lagi
            VStack(alignment: .leading, spacing: 0) {
                if rolls.isEmpty {
                    Text("Tidak ada stok gulungan tersedia")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                        .padding(16)
                } else {
                    ForEach(Array(rolls.enumerated()), id: \.element.purchase.id) { idx, item in
                        rollRow(fabricId: fabric.materialId, purchase: item.purchase)
                        if idx < rolls.count - 1 {
                            Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                        }
                    }
                }
            }
            .ouraCard()
        }
    }

    private func rollRow(fabricId: UUID, purchase: MaterialPurchase) -> some View {
        let isSelected = rollSelections[fabricId]?.id == purchase.id
        return Button {
            rollSelections[fabricId] = purchase
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    if let l = purchase.lengthCm, let w = purchase.widthCm {
                        Text("\(w, specifier: "%.0f") × \(l, specifier: "%.0f") cm")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                    }
                    if let rem = purchase.remainingLengthCm, let l = purchase.lengthCm {
                        OuraTag(
                            text: String(format: "%.0f cm sisa", rem),
                            color: rem < l * 0.2 ? OuraTheme.Colors.warningText : OuraTheme.Colors.blueAccent,
                            bg:    rem < l * 0.2 ? OuraTheme.Colors.warningBg  : OuraTheme.Colors.blueBg
                        )
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

    // MARK: - Step 3: Hasil

    private var resultsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let batch = savedBatch {
                savedSuccessView(batch: batch)
            } else {
                HStack {
                    OuraSectionHeader(title: "Hasil Optimasi")
                    Spacer()
                    Button("Ubah") { withAnimation { step = .selectRolls } }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.accent)
                }

                if combinedResults.isEmpty {
                    Text("Tidak ada layout yang dapat dihitung")
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .padding()
                        .ouraCard()
                } else {
                    ForEach(combinedResults) { result in
                        combinedLayoutCard(result)
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

            Button("Mulai Optimasi Baru") { resetState() }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }

    private func combinedLayoutCard(_ result: CombinedLayoutResult) -> some View {
        let primaryLayout = result.fabricLayouts.first?.layout
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.strategy.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    if let spec = selectedSpec {
                        Text("\(spec.productName) · \(spec.sizeLabel)")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }
                }
                Spacer()
                if let wPct = primaryLayout?.wastePct {
                    Text("\(wPct * 100, specifier: "%.1f")% waste")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(wPct > 0.2 ? OuraTheme.Colors.dangerText : OuraTheme.Colors.greenAccent)
                }
            }

            Divider().overlay(OuraTheme.Colors.separator)

            if result.fabricLayouts.count > 1 {
                ForEach(result.fabricLayouts, id: \.materialId) { fl in
                    HStack {
                        Text(fl.materialName)
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        Spacer()
                        Text("\(fl.layout.totalQty) pcs")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(
                                fl.layout.totalQty == result.bottleneckQty
                                    ? OuraTheme.Colors.warningText
                                    : OuraTheme.Colors.textPrimary
                            )
                    }
                }
                Divider().overlay(OuraTheme.Colors.separator)
                HStack {
                    statCell(label: "Batas Produksi", value: "\(result.bottleneckQty) pcs")
                    Spacer()
                    if let name = result.bottleneckFabricName {
                        Text("Terbatas oleh \(name)")
                            .font(.system(size: 11))
                            .foregroundStyle(OuraTheme.Colors.warningText)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } else {
                HStack(alignment: .bottom) {
                    statCell(label: "Total Qty", value: "\(result.bottleneckQty) pcs")
                    Spacer()
                    if let fabricName = result.fabricLayouts.first?.materialName {
                        Text(fabricName)
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                            .padding(.bottom, 2)
                    }
                }
            }

            ForEach(Array(result.displayItems.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text("\(item.productName) · \(item.sizeLabel)")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    Spacer()
                    Text("\(item.qty) pcs")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                }
            }

            Button {
                Task { await saveLayout(result) }
            } label: {
                HStack {
                    Spacer()
                    if isSaving { ProgressView() }
                    else { Text("Gunakan Layout Ini").font(.system(size: 14, weight: .semibold)) }
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
        guard let spec = selectedSpec, canCalculate else { return }
        isCalculating = true
        errorMsg = nil
        defer { isCalculating = false }

        let candidate = OptimizerCandidate(
            productSizeId: spec.productSizeId,
            patternSpecId: spec.id,
            minQty: targetQty
        )

        do {
            var results: [FabricLayoutResult] = []
            for fabric in spec.fabrics {
                guard let purchase = rollSelections[fabric.materialId] else { continue }
                let layouts = try await api.suggestLayouts(
                    SuggestOptimizerRequest(materialPurchaseId: purchase.id, candidates: [candidate])
                )
                results.append(FabricLayoutResult(
                    materialId: fabric.materialId,
                    materialName: fabric.materialName,
                    purchaseId: purchase.id,
                    layouts: layouts
                ))
            }
            fabricLayoutResults = results
            withAnimation { step = .showResults }
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func saveLayout(_ result: CombinedLayoutResult) async {
        isSaving = true
        errorMsg = nil
        defer { isSaving = false }

        do {
            var cuttingLayoutIds: [UUID] = []
            for fl in result.fabricLayouts {
                guard let purchaseId = rollSelections[fl.materialId]?.id else { continue }
                let items = fl.layout.items.map {
                    CreateLayoutRequest.CreateLayoutItemInput(
                        productSizeId: $0.productSizeId,
                        patternSpecId: $0.patternSpecId,
                        orientation: $0.orientation,
                        qtySuggested: $0.qtySuggested,
                        fabricLengthUsedCm: $0.fabricLengthUsedCm,
                        costPerPiece: $0.costPerPiece
                    )
                }
                let cutting = try await api.createLayout(CreateLayoutRequest(
                    materialPurchaseId: purchaseId,
                    strategy: fl.layout.strategy.rawValue,
                    items: items
                ))
                cuttingLayoutIds.append(cutting.id)
            }
            let batch = try await api.createProductionBatch(cuttingLayoutIds: cuttingLayoutIds)
            withAnimation { savedBatch = batch }
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func resetState() {
        step = .selectSpec
        selectedSpec = nil
        rollSelections = [:]
        targetQty = 1
        savedBatch = nil
        fabricLayoutResults = []
    }
}
