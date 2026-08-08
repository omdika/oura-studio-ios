import SwiftUI

struct ProduksiBatchView: View {
    @EnvironmentObject private var api: APIService

    @State private var batches: [ProductionBatch] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var expandedBatchId: UUID? = nil

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
                                onUpdateItem: { item, qty in Task { await updateItem(batch: batch, item: item, qty: qty) } }
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
                                confirmedBatchRow(batch)
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

    private func confirmedBatchRow(_ batch: ProductionBatch) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
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
                        HStack {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(OuraTheme.Colors.border)
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
                            Text("· HPP \(item.hppTotal.rupiahFormatted)")
                                .font(.system(size: 11))
                                .foregroundStyle(OuraTheme.Colors.textTertiary)
                        }
                        .padding(.horizontal, OuraTheme.Spacing.cardPad)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .ouraCard()
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
        batches = (try? await api.getProductionBatches()) ?? []
        isLoading = false
    }

    private func confirm(_ batch: ProductionBatch) async {
        do {
            _ = try await api.confirmBatch(id: batch.id)
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
            let updated = try await api.updateBatchItem(batchId: batch.id, itemId: item.id, qtyActual: qty)
            if let bIdx = batches.firstIndex(where: { $0.id == batch.id }),
               let iIdx = batches[bIdx].items.firstIndex(where: { $0.id == item.id }) {
                batches[bIdx].items[iIdx] = updated
            }
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func createManualBatch() async {
        do {
            let batch = try await api.createProductionBatch(cuttingLayoutId: nil)
            batches.insert(batch, at: 0)
            expandedBatchId = batch.id
        } catch {
            errorMsg = error.localizedDescription
        }
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
                    BatchItemRow(item: item, onUpdate: { qty in onUpdateItem(item, qty) })
                    if item.id != batch.items.last?.id {
                        Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                    }
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
                        Text("Konfirmasi Produksi")
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
    }
}

private struct BatchItemRow: View {
    let item: ProductionBatchItem
    let onUpdate: (Int) -> Void

    @State private var qtyText: String = ""

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.sizeLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
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
                    .onChange(of: qtyText) { _, new in
                        if let q = Int(new) { onUpdate(q) }
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
        .onAppear { qtyText = "\(item.qtyActual)" }
    }
}
