import SwiftUI

struct TambahPenjualanSheet: View {
    @EnvironmentObject private var api: APIService
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var onSave: (() -> Void)? = nil

    @State private var availableSizes: [ProductSizeDetail] = []
    @State private var customerName: String = ""
    @State private var selectedMethod: PaymentMethod = .cash
    @State private var marketplaceFeePct: Double? = nil
    @State private var items: [SaleItem] = []
    @State private var isOrderPaid: Bool = true
    @State private var showProductPicker = false
    @State private var isSaving = false
    @State private var errorMsg: String?

    private struct SaleItem: Identifiable {
        let id = UUID()
        var sizeId: UUID
        var displayName: String     // e.g. "Scrunchie · M · Satin Pelangi"
        var maxQty: Int             // currentStockQty — hard cap
        var qty: Double? = 1
        var unitPrice: Double? = nil
        var discount: Double? = nil
    }

    private var selectedSizeIds: Set<UUID> { Set(items.map { $0.sizeId }) }

    private var totalRevenue: Double {
        items.reduce(0.0) { sum, item in
            let price = (item.unitPrice ?? 0) - (item.discount ?? 0)
            return sum + price * (item.qty ?? 1)
        }
    }

    private var canSave: Bool {
        !items.isEmpty &&
        items.allSatisfy { (Int($0.qty ?? 0)) > 0 && ($0.unitPrice ?? 0) > 0 }
    }

    var body: some View {
        let content = Form {
            // Info penjualan
            Section {
                TextField("Nama pelanggan (opsional)", text: $customerName)
                    .listRowBackground(OuraTheme.Colors.surfaceCard)

                Picker("Pembayaran", selection: $selectedMethod) {
                    ForEach(PaymentMethod.allCases, id: \.rawValue) {
                        Text($0.displayName).tag($0)
                    }
                }
                .tint(OuraTheme.Colors.accent)
                .listRowBackground(OuraTheme.Colors.surfaceCard)

                if selectedMethod == .marketplace {
                    NumericInputField(label: "Fee Marketplace (%)", value: $marketplaceFeePct, unit: "%")
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }

                Toggle(isOn: $isOrderPaid) {
                    HStack(spacing: 6) {
                        Image(systemName: isOrderPaid ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isOrderPaid ? OuraTheme.Colors.greenAccent : OuraTheme.Colors.textTertiary)
                            .font(.system(size: 15))
                        Text("Sudah Lunas")
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                    }
                }
                .tint(OuraTheme.Colors.greenAccent)
                .listRowBackground(OuraTheme.Colors.surfaceCard)
            } header: { OuraSectionHeader(title: "Info Penjualan") }
            .listSectionSeparator(.hidden)

            // Produk dijual
            Section {
                if items.isEmpty {
                    Text("Belum ada produk ditambahkan.")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .listRowBackground(OuraTheme.Colors.background)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                ForEach($items) { $item in
                    itemCard(item: $item)
                }

                Button { showProductPicker = true } label: {
                    Label("Tambah Produk", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
            } header: { OuraSectionHeader(title: "Produk Dijual") }
            .listSectionSeparator(.hidden)

            // Total
            if totalRevenue > 0 {
                Section {
                    HStack {
                        Text("Total Pendapatan")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                        Spacer()
                        Text(totalRevenue.rupiahFormatted)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(OuraTheme.Colors.accent)
                    }
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                } header: { OuraSectionHeader(title: "Ringkasan") }
                .listSectionSeparator(.hidden)
            }

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
        .task { await loadSizes() }
        .sheet(isPresented: $showProductPicker) {
            ProductPickerSheet(
                sizes: availableSizes,
                alreadySelected: selectedSizeIds
            ) { size in
                items.append(SaleItem(
                    sizeId: size.id,
                    displayName: "\(size.productName) · \(size.displayLabel)",
                    maxQty: size.currentStockQty,
                    qty: 1,
                    unitPrice: size.sellingPrice,
                    discount: nil
                ))
            }
        }

        NavigationStack {
            content
                .navigationTitle("Catat Penjualan")
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
        }
    }

    @ViewBuilder
    private func itemCard(item: Binding<SaleItem>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: name + remove button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.wrappedValue.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    HStack(spacing: 4) {
                        Image(systemName: "cube.box")
                            .font(.system(size: 10))
                        Text("Tersedia: \(item.wrappedValue.maxQty) pcs")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                Spacer()
                Button {
                    items.removeAll { $0.id == item.wrappedValue.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Qty + Harga Satuan + Diskon — one aligned row, same label+box structure throughout
            HStack(alignment: .top, spacing: 10) {
                // Qty column — matches CurrencyInputField visual exactly
                VStack(alignment: .leading, spacing: 6) {
                    Text("Qty")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    HStack(spacing: 0) {
                        Button {
                            let cur = Int(item.wrappedValue.qty ?? 1)
                            if cur > 1 { item.wrappedValue.qty = Double(cur - 1) }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(OuraTheme.Colors.accent)
                                .frame(width: 26, height: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        TextField("", text: Binding(
                            get: { item.wrappedValue.qty.map { "\(Int($0))" } ?? "" },
                            set: { str in
                                if let v = Int(str), v > 0 {
                                    item.wrappedValue.qty = Double(min(v, item.wrappedValue.maxQty))
                                } else if str.isEmpty {
                                    item.wrappedValue.qty = nil
                                }
                            }
                        ))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 15))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                        .frame(width: 32)

                        Button {
                            let cur = Int(item.wrappedValue.qty ?? 0)
                            if cur < item.wrappedValue.maxQty { item.wrappedValue.qty = Double(cur + 1) }
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(OuraTheme.Colors.accent)
                                .frame(width: 26, height: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .background(OuraTheme.Colors.surfaceSheet)
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                            .stroke(OuraTheme.Colors.border, lineWidth: 1)
                    )
                }
                .frame(maxWidth: 90)

                CurrencyInputField(label: "Harga Satuan", value: item.unitPrice)
                CurrencyInputField(label: "Diskon", value: item.discount)
                    .frame(maxWidth: 100)
            }
        }
        .listRowBackground(OuraTheme.Colors.surfaceCard)
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    }

    private func loadSizes() async {
        let all = (try? await api.getAllProductSizes()) ?? []
        availableSizes = all.filter { !$0.isArchived && $0.currentStockQty > 0 }
    }

    private func save() async {
        isSaving = true; errorMsg = nil; defer { isSaving = false }
        let reqItems = items.compactMap { item -> CreateSalesOrderRequest.ItemInput? in
            guard let qty = item.qty, qty > 0, Int(qty) <= item.maxQty,
                  let price = item.unitPrice, price > 0
            else { return nil }
            return CreateSalesOrderRequest.ItemInput(
                productSizeId: item.sizeId,
                qty: Int(qty),
                unitPrice: price,
                discount: item.discount
            )
        }
        let req = CreateSalesOrderRequest(
            customerName: customerName.isEmpty ? nil : customerName,
            paymentMethod: selectedMethod.rawValue,
            marketplaceFeePct: selectedMethod == .marketplace ? marketplaceFeePct.map { $0 / 100 } : nil,
            items: reqItems
        )
        do {
            let order = try await api.createSalesOrder(req)
            if isOrderPaid { _ = try? await api.markSalesOrderPaid(id: order.id) }
            onSave?()
            appState.dashboardNeedsRefresh = true
            dismiss()
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }
}

// MARK: - Product picker bottom sheet

private struct ProductPickerSheet: View {
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
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
