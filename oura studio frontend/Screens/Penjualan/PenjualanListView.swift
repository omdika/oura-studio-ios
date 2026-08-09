import SwiftUI

struct PenjualanListView: View {
    @EnvironmentObject private var api: APIService
    @EnvironmentObject private var appState: AppState

    @State private var orders: [SalesOrder] = []
    @State private var isLoading = true
    @State private var showAdd = false
    @State private var editingOrder: SalesOrder? = nil
    @State private var orderToDelete: SalesOrder? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if orders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bag")
                            .font(.system(size: 40))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                        Text("Belum ada penjualan")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        Text("Ketuk + untuk mencatat penjualan baru")
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groupedOrders, id: \.date) { group in
                            Section {
                                ForEach(group.orders) { order in
                                    Button { editingOrder = order } label: {
                                        OrderRow(order: order)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                                    .listRowSeparatorTint(OuraTheme.Colors.separator)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            orderToDelete = order
                                        } label: {
                                            Label("Hapus", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                Text(group.date)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                                    .textCase(.none)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(OuraTheme.Colors.background)
                }
            }

            Button { showAdd = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(OuraTheme.Colors.accent)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .background(OuraTheme.Colors.background)
        .navigationTitle("Penjualan")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showAdd, onDismiss: { Task { await load() } }) {
            TambahPenjualanSheet(onSave: { Task { await load() } })
                .environmentObject(api)
                .environmentObject(appState)
        }
        .sheet(item: $editingOrder, onDismiss: { Task { await load() } }) { order in
            EditPenjualanSheet(order: order)
                .environmentObject(api)
        }
        .confirmationDialog(
            "Hapus \(orderToDelete?.invoiceNo ?? "penjualan ini")?",
            isPresented: Binding(get: { orderToDelete != nil }, set: { if !$0 { orderToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Hapus", role: .destructive) {
                if let order = orderToDelete { Task { await deleteOrder(order) } }
            }
            Button("Batal", role: .cancel) { orderToDelete = nil }
        } message: {
            Text("Stok produk akan dikembalikan. Tindakan ini tidak dapat dibatalkan.")
        }
    }

    // MARK: - Helpers

    private var groupedOrders: [(date: String, orders: [SalesOrder])] {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "id_ID")
        fmt.dateFormat = "EEEE, d MMMM yyyy"
        let sorted = orders.sorted { $0.soldAt > $1.soldAt }
        let grouped = Dictionary(grouping: sorted) { fmt.string(from: $0.soldAt) }
        return grouped.sorted { a, b in
            let dA = sorted.first { fmt.string(from: $0.soldAt) == a.key }?.soldAt ?? .distantPast
            let dB = sorted.first { fmt.string(from: $0.soldAt) == b.key }?.soldAt ?? .distantPast
            return dA > dB
        }.map { (date: $0.key, orders: $0.value) }
    }

    private func load() async {
        isLoading = true
        orders = (try? await api.getSalesOrders()) ?? []
        isLoading = false
    }

    private func deleteOrder(_ order: SalesOrder) async {
        try? await api.deleteSalesOrder(id: order.id)
        orders.removeAll { $0.id == order.id }
        orderToDelete = nil
        appState.dashboardNeedsRefresh = true
    }
}

// MARK: - Order row

private struct OrderRow: View {
    let order: SalesOrder

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(order.invoiceNo)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    statusTag
                }
                HStack(spacing: 4) {
                    if let customer = order.customerName {
                        Text(customer)
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        Text("·").foregroundStyle(OuraTheme.Colors.textTertiary)
                    }
                    if let method = order.paymentMethod {
                        Text(method.capitalized)
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                    }
                    Text("· \(order.items.count) item")
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(order.displayRevenue.rupiahFormatted)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
        }
    }

    private var statusTag: some View {
        Group {
            if order.isCancelled {
                OuraTag(text: "Batal", color: OuraTheme.Colors.dangerText, bg: OuraTheme.Colors.dangerBg)
            } else if order.isPaid {
                OuraTag(text: "Lunas", color: OuraTheme.Colors.greenAccent, bg: OuraTheme.Colors.greenBg)
            } else {
                OuraTag(text: "Pending", color: OuraTheme.Colors.warningText, bg: OuraTheme.Colors.warningBg)
            }
        }
    }
}

// MARK: - Edit sheet

private struct EditPenjualanSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let order: SalesOrder

    @State private var customerName: String
    @State private var selectedMethod: PaymentMethod
    @State private var isSaving = false
    @State private var errorMsg: String?

    init(order: SalesOrder) {
        self.order = order
        _customerName = State(initialValue: order.customerName ?? "")
        _selectedMethod = State(initialValue: PaymentMethod(rawValue: order.paymentMethod ?? "cash") ?? .cash)
    }

    private var isEditable: Bool { !order.isCancelled }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Invoice", value: order.invoiceNo)
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                    LabeledContent("Tanggal") {
                        Text(order.soldAt, style: .date)
                    }
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                } header: { OuraSectionHeader(title: "Detail") }

                if isEditable {
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
                    } header: { OuraSectionHeader(title: "Info Penjualan") }
                }

                Section {
                    ForEach(order.items) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(item.productName ?? "Produk") · \(item.sizeLabel ?? "-")")
                                    .font(.system(size: 14))
                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                                HStack(spacing: 4) {
                                    Text("\(item.qty) pcs × \(item.unitPrice.rupiahFormatted)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                                    if item.discount > 0 {
                                        Text("- \(item.discount.rupiahFormatted)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(OuraTheme.Colors.dangerText)
                                    }
                                }
                            }
                            Spacer()
                            Text(item.lineRevenue.rupiahFormatted)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                        }
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                } header: { OuraSectionHeader(title: "Produk (\(order.items.count))") }
                  footer: {
                      HStack {
                          Spacer()
                          Text("Total: \(order.displayRevenue.rupiahFormatted)")
                              .font(.system(size: 13, weight: .semibold))
                              .foregroundStyle(OuraTheme.Colors.textPrimary)
                      }
                  }

                if !order.isPaid && !order.isCancelled {
                    Section {
                        Button {
                            Task { await markPaid() }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(OuraTheme.Colors.greenAccent)
                                Text("Tandai Lunas")
                                    .foregroundStyle(OuraTheme.Colors.greenAccent)
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(OuraTheme.Colors.greenBg)
                    }
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
            .navigationTitle(order.invoiceNo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
                if isEditable {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Simpan") { Task { await save() } }
                            .foregroundStyle(isSaving ? OuraTheme.Colors.textDisabled : OuraTheme.Colors.accent)
                            .disabled(isSaving)
                    }
                }
            }
        }
    }

    private func save() async {
        isSaving = true; errorMsg = nil; defer { isSaving = false }
        do {
            _ = try await api.updateSalesOrder(
                id: order.id,
                customerName: customerName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : customerName,
                paymentMethod: selectedMethod.rawValue
            )
            dismiss()
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }

    private func markPaid() async {
        isSaving = true; defer { isSaving = false }
        _ = try? await api.markSalesOrderPaid(id: order.id)
        dismiss()
    }
}
