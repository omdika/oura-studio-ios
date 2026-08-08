import SwiftUI

struct BahanListView: View {
    @EnvironmentObject private var api: APIService

    @State private var materials: [Material] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var searchText: String = ""
    @State private var showTambah = false
    @State private var displayCount = 15
    @State private var hasLoadedOnce = false

    private let pageSize = 15

    private var filtered: [Material] {
        let active = materials.filter { !$0.isArchived }
        guard !searchText.isEmpty else { return active }
        return active.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var displayed: [Material] { Array(filtered.prefix(displayCount)) }

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
                } else if filtered.isEmpty {
                    emptyView
                } else {
                    materialList
                }
            }
        }
        .background(OuraTheme.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await load()
            hasLoadedOnce = true
        }
        .onAppear {
            guard hasLoadedOnce else { return }
            Task { await load(silent: true) }
        }
        .sheet(isPresented: $showTambah) {
            TambahPembelianSheet(preselectedMaterial: nil)
        }
        .onChange(of: showTambah) { _, showing in
            if !showing { Task { await load(silent: true) } }
        }
        .onChange(of: searchText) { displayCount = pageSize }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(alignment: .center) {
            Text("Bahan")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
            Spacer()
            Button {
                showTambah = true
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
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .font(.system(size: 14))
            TextField("Cari bahan...", text: $searchText)
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

    // MARK: - List

    private var materialList: some View {
        List {
            ForEach(displayed) { material in
                NavigationLink(destination: BahanDetailView(material: material)) {
                    MaterialRow(material: material)
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))
                .listRowSeparatorTint(OuraTheme.Colors.separator)
            }

            if displayed.count < filtered.count {
                Button {
                    displayCount += pageSize
                } label: {
                    Text("Muat Lebih Banyak ↓")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .listRowBackground(OuraTheme.Colors.background)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(OuraTheme.Colors.background)
        .refreshable { await load() }
    }

    // MARK: - Empty / Error

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
            Text(searchText.isEmpty ? "Belum ada bahan" : "Bahan tidak ditemukan")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            if searchText.isEmpty {
                Text("Tambah pembelian bahan pertama")
                    .font(.system(size: 13))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(OuraTheme.Colors.dangerText)
            Text(msg)
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Coba lagi") { Task { await load() } }
                .foregroundStyle(OuraTheme.Colors.accent)
        }
        .padding(OuraTheme.Spacing.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load(silent: Bool = false) async {
        if !silent { isLoading = true }
        errorMsg = nil
        do { materials = try await api.getMaterials() }
        catch { if !silent { errorMsg = error.localizedDescription } }
        isLoading = false
    }
}

// MARK: - Row

private struct MaterialRow: View {
    let material: Material

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(material.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
            }

            Spacer()

            if let txt = stockQtyText {
                Text(txt)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(stockQtyColor)
            }
        }
    }

    // MARK: Computed helpers

    private var subtitle: String {
        let priceStr: String
        switch material.category {
        case .fabric:
            priceStr = "\((material.currentAvgCost * 100).rupiahFormatted)/m"
        case .thread:
            priceStr = "\(material.currentAvgCost.rupiahFormatted)/gulung"
        case .hardware, .packaging:
            priceStr = "\(material.currentAvgCost.rupiahFormatted)/\(material.purchaseUnit)"
        }
        return "\(material.category.displayName) · \(priceStr)"
    }

    private var dotColor: Color {
        guard let qty = material.currentTotalQty else { return OuraTheme.Colors.greenAccent }
        guard let min = material.reorderMinQty else { return OuraTheme.Colors.greenAccent }
        if qty <= 0 { return OuraTheme.Colors.dangerText }
        if qty < min { return OuraTheme.Colors.warningText }
        return OuraTheme.Colors.greenAccent
    }

    private var stockQtyText: String? {
        guard let qty = material.currentTotalQty else { return nil }
        let unit: String
        switch material.category {
        case .fabric:    unit = "m"
        case .thread:    unit = "gulung"
        default:         unit = material.purchaseUnit
        }
        let num = qty.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(qty))"
            : String(format: "%.1f", qty).replacingOccurrences(of: ".", with: ",")
        return "\(num) \(unit)"
    }

    private var stockQtyColor: Color {
        guard let qty = material.currentTotalQty else { return OuraTheme.Colors.textPrimary }
        guard let min = material.reorderMinQty else { return OuraTheme.Colors.textPrimary }
        if qty <= 0 { return OuraTheme.Colors.dangerText }
        if qty < min { return OuraTheme.Colors.warningText }
        return OuraTheme.Colors.textPrimary
    }
}
