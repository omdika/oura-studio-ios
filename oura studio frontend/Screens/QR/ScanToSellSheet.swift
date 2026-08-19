import SwiftUI

struct ScanToSellSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let size: ProductSizeDetail
    let dismissParent: () -> Void

    @State private var qty: Int = 1
    @State private var unitPrice: Double
    @State private var discount: Double = 0
    @State private var paymentMethod: PaymentMethod = .cash
    @State private var customerName: String = ""
    @State private var isSaving = false
    @State private var errorMsg: String?
    @State private var didSucceed = false

    init(size: ProductSizeDetail, dismissParent: @escaping () -> Void) {
        self.size = size
        self.dismissParent = dismissParent
        _unitPrice = State(initialValue: size.sellingPrice ?? 0)
    }

    private var canSave: Bool {
        qty >= 1 && qty <= size.currentStockQty && unitPrice > 0 && !isSaving
    }

    private var totalAmount: Double {
        max(0, (unitPrice - discount)) * Double(qty)
    }

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
    }

    // MARK: - Form

    private var formView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(size.productName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Text(size.displayLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    Text("Stok tersedia: \(size.currentStockQty) pcs")
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }
            .listSectionSeparator(.hidden)

            Section {
                HStack {
                    Text("Jumlah")
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

                        Button { if qty < size.currentStockQty { qty += 1 } } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(qty < size.currentStockQty
                                    ? OuraTheme.Colors.accent : OuraTheme.Colors.border)
                        }
                        .buttonStyle(.plain)
                        .disabled(qty >= size.currentStockQty)
                    }
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                CurrencyInputField(label: "Harga Jual", value: Binding(
                    get: { unitPrice > 0 ? unitPrice : nil },
                    set: { unitPrice = $0 ?? 0 }
                ))
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                CurrencyInputField(label: "Diskon", value: Binding(
                    get: { discount > 0 ? discount : nil },
                    set: { discount = $0 ?? 0 }
                ))
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            } header: {
                OuraSectionHeader(title: "Detail Penjualan")
            }
            .listSectionSeparator(.hidden)

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Metode Bayar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PaymentMethod.allCases, id: \.self) { method in
                                let selected = paymentMethod == method
                                Button { paymentMethod = method } label: {
                                    Text(method.displayName)
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
                                .animation(.easeInOut(duration: 0.15), value: paymentMethod)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                TextField("Nama pembeli (opsional)", text: $customerName)
                    .font(.system(size: 14))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            } header: {
                OuraSectionHeader(title: "Pembayaran")
            }
            .listSectionSeparator(.hidden)

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
        .navigationTitle("Catat Penjualan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Batal") { dismiss() }
                    .foregroundStyle(OuraTheme.Colors.accent)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider().overlay(OuraTheme.Colors.separator)
                Button {
                    Task { await save() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Simpan · \(totalAmount.rupiahFormatted)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canSave
                        ? OuraTheme.Colors.accentGradient
                        : LinearGradient(colors: [OuraTheme.Colors.border],
                                         startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .padding(16)
            }
            .background(OuraTheme.Colors.background)
        }
    }

    // MARK: - Success view

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(OuraTheme.Colors.greenAccent)
            Text("Terjual \(qty) pcs")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
            Text(size.displayLabel)
                .font(.system(size: 15))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Text(totalAmount.rupiahFormatted)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.accent)
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

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMsg = nil
        defer { isSaving = false }
        do {
            let req = CreateSalesOrderRequest(
                customerName: customerName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : customerName,
                paymentMethod: paymentMethod.rawValue,
                marketplaceFeePct: paymentMethod == .marketplace ? 0.05 : nil,
                items: [CreateSalesOrderRequest.ItemInput(
                    productSizeId: size.id,
                    qty: qty,
                    unitPrice: unitPrice,
                    discount: discount > 0 ? discount : nil
                )]
            )
            _ = try await api.createSalesOrder(req)
            didSucceed = true
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
