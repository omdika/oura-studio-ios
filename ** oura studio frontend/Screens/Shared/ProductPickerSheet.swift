import SwiftUI

// ProductPickerSheet dipindahkan ke file terpisah dan dijadikan public
public struct ProductPickerSheet: View {
    let sizes: [ProductSizeDetail]
    let alreadySelected: Set<UUID>
    let onSelect: (ProductSizeDetail) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var pickable: [ProductSizeDetail] {
        sizes.filter { !alreadySelected.contains($0.id) }
    }

    private var filtered: [ProductSizeDetail] {
        if searchText.isEmpty { return pickable }
        let q = searchText.lowercased()
        return pickable.filter {
            $0.productName.lowercased().contains(q) ||
            $0.sizeLabel.lowercased().contains(q) ||
            ($0.fabricVariantName?.lowercased().contains(q) ?? false)
        }
    }

    private var groups: [(productName: String, sizes: [ProductSizeDetail])] {
        var dict: [String: [ProductSizeDetail]] = [:]
        for s in filtered { dict[s.productName, default: []].append(s) }
        return dict.map { (productName: $0.key, sizes: $0.value) }
            .sorted { $0.productName < $1.productName }
    }

    public var body: some View { // body juga public
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                    TextField("Cari produk...", text: $searchText)
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

                if groups.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "cube.box")
                            .font(.system(size: 36))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                        Text(sizes.isEmpty ? "Belum ada stok produk." : "Tidak ada hasil pencarian.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        if sizes.isEmpty {
                            Text("Konfirmasi batch produksi terlebih dahulu\ndi Tab Produksi → Produksi.")
                                .font(.system(size: 12))
                                .foregroundStyle(OuraTheme.Colors.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(groups, id: \.productName) { group in
                            Section {
                                ForEach(group.sizes, id: \.id) { size in
                                    Button {
                                        onSelect(size)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(size.displayLabel)
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                                                if let price = size.sellingPrice {
                                                    Text(price.rupiahFormatted)
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                                                }
                                            }
                                            Spacer()
                                            Text("\(size.currentStockQty) pcs")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(size.isLowStock ? OuraTheme.Colors.warningText : OuraTheme.Colors.greenAccent)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(size.isLowStock ? OuraTheme.Colors.warningBg : OuraTheme.Colors.greenBg)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                                }
                            } header: {
                                Text(group.productName.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                                    .kerning(0.8)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(OuraTheme.Colors.background)
                }
            }
            .background(OuraTheme.Colors.background)
            .navigationTitle("Pilih Produk")
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
