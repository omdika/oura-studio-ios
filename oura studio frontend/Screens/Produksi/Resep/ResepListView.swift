import SwiftUI

// All PatternSpecs sharing the same productSizeId (gabungkan group, or single-fabric pisah spec)
struct SpecGroup: Identifiable {
    let productSizeId: UUID
    let specs: [PatternSpec]

    var id: UUID { productSizeId }
    var sizeLabel: String { specs[0].sizeLabel }
    var productName: String { specs[0].productName }
    var productSku: String { specs[0].productSku }
    var estLaborMinutes: Double { specs[0].estLaborMinutes }
    var maxUsedInBatchCount: Int { specs.map { $0.usedInBatchCount }.max() ?? 0 }

    var isSingleFabric: Bool { specs.count == 1 && specs[0].fabrics.count <= 1 }
    var firstFabric: PatternFabric? { specs.flatMap { $0.fabrics }.first }
    var allFabricNames: String {
        let names = specs.flatMap { $0.fabrics }.map { $0.materialName }
        return names.isEmpty ? "Tanpa Kain" : names.joined(separator: " · ")
    }
}

struct ResepListView: View {
    @EnvironmentObject private var api: APIService

    @State private var specs: [PatternSpec] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var searchText: String = ""
    @State private var showTambah = false

    private var grouped: [(product: String, groups: [SpecGroup])] {
        let filtered = searchText.isEmpty
            ? specs.filter { $0.isActive }
            : specs.filter { $0.isActive && (
                $0.productName.localizedCaseInsensitiveContains(searchText) ||
                $0.sizeLabel.localizedCaseInsensitiveContains(searchText) ||
                $0.fabricMaterialName.localizedCaseInsensitiveContains(searchText)
            )}

        let byProduct = Dictionary(grouping: filtered, by: { $0.productName })
        return byProduct.sorted { $0.key < $1.key }.map { entry in
            let specGroups = Dictionary(grouping: entry.value, by: { $0.productSizeId })
                .map { SpecGroup(productSizeId: $0.key, specs: $0.value) }
                .sorted { $0.sizeLabel < $1.sizeLabel }
            return (product: entry.key, groups: specGroups)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            searchField
                .padding(.horizontal, OuraTheme.Spacing.horizontal)
                .padding(.bottom, 6)

            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMsg {
                    errorView(err)
                } else if grouped.isEmpty {
                    emptyView
                } else {
                    specList
                }
            }
        }
        .background(OuraTheme.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .sheet(isPresented: $showTambah, onDismiss: { Task { await load() } }) {
            TambahResepSheet()
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .center) {
            Text("Resep")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
            Spacer()
            Button { showTambah = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.accent)
                    .frame(width: 32, height: 32)
                    .background(OuraTheme.Colors.accentLight)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tambah Resep")
        }
        .padding(.horizontal, OuraTheme.Spacing.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .font(.system(size: 14))
            TextField("Cari resep pola...", text: $searchText)
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(OuraTheme.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                .stroke(OuraTheme.Colors.border, lineWidth: 0.75)
        )
    }

    private var specList: some View {
        List {
            ForEach(grouped, id: \.product) { group in
                Section {
                    ForEach(group.groups) { specGroup in
                        NavigationLink(destination: ResepEditorView(
                            specs: specGroup.specs,
                            onUpdate: { Task { await load() } }
                        )) {
                            ResepRow(group: specGroup)
                        }
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .listRowSeparatorTint(OuraTheme.Colors.separator)
                    }
                } header: {
                    Text(group.product)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .textCase(.none)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(OuraTheme.Colors.background)
        .refreshable { await load() }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
            Text(searchText.isEmpty ? "Belum ada resep pola" : "Resep tidak ditemukan")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            if searchText.isEmpty {
                Text("Buat resep pola pertama untuk produk Anda")
                    .font(.system(size: 13))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(OuraTheme.Colors.dangerText)
            Text("Gagal memuat resep")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Text(message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Coba Lagi") { Task { await load() } }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        isLoading = true
        errorMsg = nil
        do {
            specs = try await api.getPatternSpecs()
        } catch {
            errorMsg = error.localizedDescription
            specs = []
        }
        isLoading = false
    }
}

// MARK: - Row

private struct ResepRow: View {
    let group: SpecGroup

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(group.sizeLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    // Show dimension tag only for single-fabric rows (pisah)
                    if group.isSingleFabric, let fab = group.firstFabric {
                        OuraTag(text: String(format: "%.0f×%.0f cm", fab.cutLengthCm, fab.cutWidthCm))
                    }
                }
                Text(group.allFabricNames)
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(group.estLaborMinutes, specifier: "%.0f") min")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                if group.maxUsedInBatchCount > 0 {
                    Text("\(group.maxUsedInBatchCount)× dipakai")
                        .font(.system(size: 11))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
            }
        }
    }
}
