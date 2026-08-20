import SwiftUI

struct ProduksiBatchView: View {
    @EnvironmentObject private var api: APIService

    @State private var batches: [ProductionBatch] = []
    @State private var allMaterials: [Material] = []
    @State private var settings: [SettingItem] = []
    @State private var patternSpecs: [PatternSpec] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var expandedBatchId: UUID? = nil

    private var skuMap: [UUID: String] {
        Dictionary(patternSpecs.map { ($0.productSizeId, $0.productSku) },
                   uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Batch Produksi")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                Button {
                    Task { await createManualBatch() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.accent)
                        .frame(width: 32, height: 32)
                        .background(OuraTheme.Colors.accentLight)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, OuraTheme.Spacing.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if batches.isEmpty {
                    emptyView
                } else {
                    batchList
                }
            }
        }
        .background(OuraTheme.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
        .alert("Terjadi Kesalahan", isPresented: Binding(
            get: { errorMsg != nil },
            set: { if !$0 { errorMsg = nil } }
        )) {
            Button("OK") { errorMsg = nil }
        } message: {
            Text(errorMsg ?? "")
        }
    }

    // MARK: - List

    private var batchList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuraTheme.Spacing.sectionGap) {
                let drafts     = batches.filter { $0.isDraft }
                let confirmed  = batches.filter { $0.isConfirmed }

                if !drafts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        OuraSectionHeader(title: "Draft")
                        ForEach(drafts) { batch in
                            BatchCard(
                                batch: batch,
                                isExpanded: expandedBatchId == batch.id,
                                onToggle: { withAnimation { expandedBatchId = expandedBatchId == batch.id ? nil : batch.id } },
                                onConfirm: { Task { await confirm(batch) } },
                                onDelete:  { Task { await deleteBatch(batch) } },
                                onUpdateItem: { item, qty in Task { await updateItem(batch: batch, item: item, qty: qty) } },
                                onApplyPrice: { item, price in Task { await applyPrice(item: item, price: price) } }
                            )
                        }
                    }
                }

                if !confirmed.isEmpty {
                    let grouped = Dictionary(grouping: confirmed.prefix(20), by: { $0.materialName ?? "Manual" })
                    let sortedKeys = grouped.keys.sorted()
                    ForEach(sortedKeys, id: \.self) { matName in
                        VStack(alignment: .leading, spacing: 12) {
                            OuraSectionHeader(title: matName.uppercased())
                            ForEach(grouped[matName] ?? []) { batch in
                                ConfirmedBatchCard(batch: batch,
                                    onApplyPrice: { item, price in Task { await applyPrice(item: item, price: price) } })
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, OuraTheme.Spacing.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer")
                .font(.system(size: 40))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
            Text("Belum ada produksi")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Text("Gunakan Optimasi atau buat batch manual")
                .font(.system(size: 13))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        async let batchesTask  = api.getProductionBatches()
        async let matsTask     = api.getMaterials()
        async let specsTask    = api.getPatternSpecs()
        async let settingsTask = api.getSettings()
        var loaded  = (try? await batchesTask)  ?? []
        allMaterials = (try? await matsTask)    ?? []
        patternSpecs = (try? await specsTask)   ?? []
        settings     = (try? await settingsTask) ?? []
        enrichDraftHpp(&loaded)
        batches = loaded
        isLoading = false
    }

    private func enrichDraftHpp(_ batches: inout [ProductionBatch]) {
        let settingsMap = Dictionary(uniqueKeysWithValues: settings.map { ($0.key, $0.value) })
        let matCostMap  = Dictionary(uniqueKeysWithValues: allMaterials.map { ($0.id, $0.currentAvgCost) })
        let specMap     = Dictionary(uniqueKeysWithValues: patternSpecs.map { ($0.id, $0) })
        let laborRate   = settingsMap["labor_rate_per_minute"]          ?? 0
        let overhead    = settingsMap["default_overhead_per_unit"]      ?? 0
        let threadPool  = settingsMap["pooled_material_rate:thread"]    ?? 0
        let packPool    = settingsMap["pooled_material_rate:packaging"] ?? 0
        let pooled      = threadPool + packPool
        for bIdx in batches.indices where batches[bIdx].isDraft {
            for iIdx in batches[bIdx].items.indices {
                var item = batches[bIdx].items[iIdx]
                guard item.latestHppBreakdown == nil, item.hppFabric > 0 else { continue }
                let spec  = item.patternSpecId.flatMap { specMap[$0] }
                let labor = (spec?.estLaborMinutes ?? 0) * laborRate
                let hardware: Double = spec?.components.reduce(0.0) { partial, comp in
                    partial + comp.qtyPerUnit * (matCostMap[comp.materialId] ?? 0)
                } ?? 0
                let total    = item.hppFabric + pooled + hardware + labor + overhead
                item.latestHppBreakdown = HPPBreakdown(
                    fabric: item.hppFabric, pooledMaterial: pooled,
                    hardware: hardware, labor: labor, overhead: overhead, total: total
                )
                batches[bIdx].items[iIdx] = item
            }
        }
    }

    private func confirm(_ batch: ProductionBatch) async {
        do {
            try await api.confirmBatch(id: batch.id)
            // Auto-apply suggested price (40% margin) for every item that has HPP
            await withTaskGroup(of: Void.self) { group in
                for item in batch.items {
                    let hpp = item.latestHppBreakdown?.total
                        ?? (item.hppTotal > 0 ? item.hppTotal : nil)
                    guard let hpp, hpp > 0, item.productSizeId != nil else { continue }
                    let price = ceil(hpp / 0.6) // 40% margin = hpp / (1 - 0.40)
                    group.addTask { await self.applyPrice(item: item, price: price) }
                }
            }
            await load()
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func deleteBatch(_ batch: ProductionBatch) async {
        do {
            try await api.deleteProductionBatch(id: batch.id)
            batches.removeAll { $0.id == batch.id }
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func updateItem(batch: ProductionBatch, item: ProductionBatchItem, qty: Int) async {
        do {
            var updated = try await api.updateBatchItem(batchId: batch.id, itemId: item.id, qtyActual: qty)
            if let bIdx = batches.firstIndex(where: { $0.id == batch.id }),
               let iIdx = batches[bIdx].items.firstIndex(where: { $0.id == item.id }) {
                // Preserve client-side enrichment — API response doesn't include latestHppBreakdown
                updated.latestHppBreakdown = updated.latestHppBreakdown ?? batches[bIdx].items[iIdx].latestHppBreakdown
                batches[bIdx].items[iIdx] = updated
            }
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func createManualBatch() async {
        do {
            let batch = try await api.createProductionBatch(cuttingLayoutIds: [])
            batches.insert(batch, at: 0)
            expandedBatchId = batch.id
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func applyPrice(item: ProductionBatchItem, price: Double) async {
        guard let sizeId = item.productSizeId,
              let sku = skuMap[sizeId] else { return }
        _ = try? await api.patchProductSize(sku: sku, sizeId: sizeId, PatchProductSizeRequest(sellingPrice: price))
    }
}

// MARK: - Batch card

private struct BatchCard: View {
    let batch: ProductionBatch
    let isExpanded: Bool
    let onToggle: () -> Void
    let onConfirm: () -> Void
    let onDelete: () -> Void
    let onUpdateItem: (ProductionBatchItem, Int) -> Void
    let onApplyPrice: (ProductionBatchItem, Double) -> Void

    @State private var hppItemId: UUID? = nil

    private func effectiveHpp(for item: ProductionBatchItem) -> HPPBreakdown? {
        if let breakdown = item.latestHppBreakdown { return breakdown }
        // Real backend draft: only hppFabric is populated; full HPP computed at confirmation
        guard item.hppFabric > 0 else { return nil }
        let total = item.hppTotal > 0
            ? item.hppTotal
            : item.hppFabric + item.hppPooledMaterial + item.hppHardware + item.hppLabor + item.hppOverhead
        return HPPBreakdown(fabric: item.hppFabric, pooledMaterial: item.hppPooledMaterial,
                            hardware: item.hppHardware, labor: item.hppLabor,
                            overhead: item.hppOverhead, total: total)
    }

    private var hppFocusItem: ProductionBatchItem? {
        let withHpp = batch.items.filter { effectiveHpp(for: $0) != nil }
        guard !withHpp.isEmpty else { return nil }
        if let focused = hppItemId, let item = withHpp.first(where: { $0.id == focused }) {
            return item
        }
        return withHpp.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(batch.draftLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                        Text("\(batch.items.count) pola · \(batch.producedAt, style: .date)")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .padding(OuraTheme.Spacing.cardPad)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().overlay(OuraTheme.Colors.separator)

                ForEach(batch.items) { item in
                    BatchItemRow(
                        item: item,
                        isHppSelected: hppFocusItem?.id == item.id && effectiveHpp(for: item) != nil,
                        onUpdate: { qty in onUpdateItem(item, qty) },
                        onSelectHpp: effectiveHpp(for: item) != nil ? { hppItemId = item.id } : nil
                    )
                    if item.id != batch.items.last?.id {
                        Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                    }
                }

                if let focus = hppFocusItem, let hpp = effectiveHpp(for: focus) {
                    Divider().overlay(OuraTheme.Colors.separator)
                    hppRincian(sizeLabel: focus.sizeLabel, hpp: hpp)
                    Divider().overlay(OuraTheme.Colors.separator)
                    PriceAdvisorSection(hpp: hpp, itemLabel: focus.sizeLabel) { price in
                        onApplyPrice(focus, price)
                    }
                    .id(focus.id)
                }

                Divider().overlay(OuraTheme.Colors.separator)

                HStack(spacing: 12) {
                    Button(action: onDelete) {
                        Text("Hapus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(OuraTheme.Colors.dangerText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(OuraTheme.Colors.dangerBg)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                    }
                    .buttonStyle(.plain)

                    Button(action: onConfirm) {
                        Text("Konfirmasi & Tambah ke Stok")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(OuraTheme.Colors.accentGradient)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, OuraTheme.Spacing.cardPad)
                .padding(.bottom, OuraTheme.Spacing.cardPad)
                .padding(.top, 10)
            }
        }
        .ouraCard(OuraTheme.Radius.card)
        .onChange(of: isExpanded) { expanded in
            if expanded { hppItemId = nil }
        }
    }

    // MARK: - HPP Rincian

    private func hppRincian(sizeLabel: String, hpp: HPPBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text("RINCIAN HPP")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                Text(sizeLabel.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.accent)
            }
            .padding(.horizontal, OuraTheme.Spacing.cardPad)
            .padding(.top, 12)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                hppRow("Kain (fabric)", value: hpp.fabric, dot: Color(red: 0.24, green: 0.52, blue: 0.95))
                if hpp.fabricItems.count > 1 {
                    ForEach(hpp.fabricItems, id: \.name) { hppSubRow($0.name, cost: $0.cost) }
                }
                if hpp.pooledMaterial > 0 {
                    hppRow("Bahan Pooled", value: hpp.pooledMaterial, dot: Color(red: 0.58, green: 0.35, blue: 0.85))
                }
                if hpp.hardware > 0 {
                    hppRow("Hardware", value: hpp.hardware, dot: Color(red: 0.95, green: 0.75, blue: 0.20))
                    if hpp.hardwareItems.count > 1 {
                        ForEach(hpp.hardwareItems, id: \.name) { hppSubRow($0.name, cost: $0.cost) }
                    }
                }
                if hpp.labor > 0 {
                    hppRow("Tenaga Kerja", value: hpp.labor, dot: Color(red: 0.95, green: 0.48, blue: 0.22))
                }
                if hpp.overhead > 0 {
                    hppRow("Overhead", value: hpp.overhead, dot: OuraTheme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, OuraTheme.Spacing.cardPad)

            Divider()
                .overlay(OuraTheme.Colors.separator)
                .padding(.horizontal, OuraTheme.Spacing.cardPad)
                .padding(.top, 8)

            HStack {
                Text("HPP Total")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                Text(hpp.total.rupiahFormatted)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.accent)
            }
            .padding(.horizontal, OuraTheme.Spacing.cardPad)
            .padding(.vertical, 10)
        }
    }

    private func hppRow(_ label: String, value: Double, dot: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(dot).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Spacer()
            Text(value.rupiahFormatted)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
        }
        .padding(.vertical, 5)
    }

    private func hppSubRow(_ label: String, cost: Double) -> some View {
        HStack {
            Text("· \(label)")
                .font(.system(size: 12))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .padding(.leading, 15)
            Spacer()
            Text(cost.rupiahFormatted)
                .font(.system(size: 12))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Confirmed batch card

private struct ConfirmedBatchCard: View {
    let batch: ProductionBatch
    let onApplyPrice: (ProductionBatchItem, Double) -> Void

    @State private var hppItemId: UUID? = nil

    private func effectiveHpp(for item: ProductionBatchItem) -> HPPBreakdown? {
        if let breakdown = item.latestHppBreakdown { return breakdown }
        guard item.hppFabric > 0 else { return nil }
        let total = item.hppTotal > 0
            ? item.hppTotal
            : item.hppFabric + item.hppPooledMaterial + item.hppHardware + item.hppLabor + item.hppOverhead
        return HPPBreakdown(fabric: item.hppFabric, pooledMaterial: item.hppPooledMaterial,
                            hardware: item.hppHardware, labor: item.hppLabor,
                            overhead: item.hppOverhead, total: total)
    }

    private var hppFocusItem: ProductionBatchItem? {
        guard let id = hppItemId else { return nil }
        return batch.items.first { $0.id == id && effectiveHpp(for: $0) != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(batch.batchLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    OuraTag(text: "Selesai", color: OuraTheme.Colors.greenAccent, bg: OuraTheme.Colors.greenBg)
                    Text(batch.producedAt, style: .date)
                        .font(.system(size: 11))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
            }
            .padding(OuraTheme.Spacing.cardPad)

            if !batch.items.isEmpty {
                Divider().overlay(OuraTheme.Colors.separator).padding(.horizontal, OuraTheme.Spacing.cardPad)

                VStack(spacing: 0) {
                    ForEach(batch.items.sorted { $0.sizeLabel < $1.sizeLabel }) { item in
                        let hasHpp = effectiveHpp(for: item) != nil
                        let isSelected = hppItemId == item.id && hasHpp
                        Button {
                            guard hasHpp else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hppItemId = hppItemId == item.id ? nil : item.id
                            }
                        } label: {
                            HStack {
                                HStack(spacing: 6) {
                                    Rectangle()
                                        .fill(isSelected ? OuraTheme.Colors.accent : OuraTheme.Colors.border)
                                        .frame(width: 2, height: 14)
                                        .clipShape(Capsule())
                                    Text(item.sizeLabel)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                                }
                                Spacer()
                                Text("\(item.qtyActual) pcs")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                                if item.hppTotal > 0 {
                                    Text("· HPP \(item.hppTotal.rupiahFormatted)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(isSelected ? OuraTheme.Colors.accent : OuraTheme.Colors.textTertiary)
                                }
                                if hasHpp {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                                        .rotationEffect(.degrees(isSelected ? 90 : 0))
                                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                                }
                            }
                            .padding(.horizontal, OuraTheme.Spacing.cardPad)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let focus = hppFocusItem, let hpp = effectiveHpp(for: focus) {
                    Divider().overlay(OuraTheme.Colors.separator)
                    hppRincian(sizeLabel: focus.sizeLabel, hpp: hpp)
                    Divider().overlay(OuraTheme.Colors.separator)
                    PriceAdvisorSection(hpp: hpp, itemLabel: focus.sizeLabel) { price in
                        onApplyPrice(focus, price)
                    }
                    .id(focus.id)
                }
            }
        }
        .ouraCard()
    }

    private func hppRincian(sizeLabel: String, hpp: HPPBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text("RINCIAN HPP")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                Text(sizeLabel.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.accent)
            }
            .padding(.horizontal, OuraTheme.Spacing.cardPad)
            .padding(.top, 12)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                hppRow("Kain (fabric)", value: hpp.fabric, dot: Color(red: 0.24, green: 0.52, blue: 0.95))
                if hpp.fabricItems.count > 1 {
                    ForEach(hpp.fabricItems, id: \.name) { hppSubRow($0.name, cost: $0.cost) }
                }
                if hpp.pooledMaterial > 0 {
                    hppRow("Bahan Pooled", value: hpp.pooledMaterial, dot: Color(red: 0.58, green: 0.35, blue: 0.85))
                }
                if hpp.hardware > 0 {
                    hppRow("Hardware", value: hpp.hardware, dot: Color(red: 0.95, green: 0.75, blue: 0.20))
                    if hpp.hardwareItems.count > 1 {
                        ForEach(hpp.hardwareItems, id: \.name) { hppSubRow($0.name, cost: $0.cost) }
                    }
                }
                if hpp.labor > 0 {
                    hppRow("Tenaga Kerja", value: hpp.labor, dot: Color(red: 0.95, green: 0.48, blue: 0.22))
                }
                if hpp.overhead > 0 {
                    hppRow("Overhead", value: hpp.overhead, dot: OuraTheme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, OuraTheme.Spacing.cardPad)

            Divider()
                .overlay(OuraTheme.Colors.separator)
                .padding(.horizontal, OuraTheme.Spacing.cardPad)
                .padding(.top, 8)

            HStack {
                Text("HPP Total")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                Text(hpp.total.rupiahFormatted)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.accent)
            }
            .padding(.horizontal, OuraTheme.Spacing.cardPad)
            .padding(.vertical, 10)
        }
    }

    private func hppRow(_ label: String, value: Double, dot: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(dot).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Spacer()
            Text(value.rupiahFormatted)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
        }
        .padding(.vertical, 5)
    }

    private func hppSubRow(_ label: String, cost: Double) -> some View {
        HStack {
            Text("· \(label)")
                .font(.system(size: 12))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .padding(.leading, 15)
            Spacer()
            Text(cost.rupiahFormatted)
                .font(.system(size: 12))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Draft item row

private struct BatchItemRow: View {
    let item: ProductionBatchItem
    let isHppSelected: Bool
    let onUpdate: (Int) -> Void
    let onSelectHpp: (() -> Void)?

    @State private var qtyText: String = ""

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.sizeLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    if isHppSelected {
                        Circle()
                            .fill(OuraTheme.Colors.accent)
                            .frame(width: 6, height: 6)
                    }
                }
                HStack(spacing: 4) {
                    if item.hppTotal > 0 {
                        Text("HPP \(item.hppTotal.rupiahFormatted)/pcs")
                            .font(.system(size: 11))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                    } else if item.hppFabric > 0 {
                        Text("~kain \(item.hppFabric.rupiahFormatted)/pcs")
                            .font(.system(size: 11))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }
                    if let sug = item.qtySuggested {
                        Text("· Saran: \(sug)")
                            .font(.system(size: 11))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    let cur = Int(qtyText) ?? item.qtyActual
                    if cur > 0 {
                        let new = cur - 1
                        qtyText = "\(new)"
                        onUpdate(new)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(OuraTheme.Colors.border)
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)

                TextField("0", text: $qtyText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 44)
                    .onChange(of: qtyText) { new in
                        guard let q = Int(new), q != item.qtyActual else { return }
                        onUpdate(q)
                    }

                Button {
                    let cur = Int(qtyText) ?? item.qtyActual
                    let new = cur + 1
                    qtyText = "\(new)"
                    onUpdate(new)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(OuraTheme.Colors.accent)
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { onSelectHpp?() }
        .onAppear { qtyText = "\(item.qtyActual)" }
    }
}
