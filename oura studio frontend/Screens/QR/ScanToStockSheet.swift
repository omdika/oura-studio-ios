import SwiftUI

struct ScanToStockSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let size: ProductSizeDetail
    let dismissParent: () -> Void

    @State private var qty: Int = 1
    @State private var reason: StockReason = .production
    @State private var note: String = ""
    @State private var isSaving = false
    @State private var errorMsg: String?
    @State private var didSucceed = false

    enum StockReason: String, CaseIterable {
        case production = "production"
        case adjustment = "adjustment"
        var displayName: String { self == .production ? "Dari Produksi" : "Koreksi Stok" }
    }

    private var canSave: Bool { qty >= 1 && !isSaving }

    var body: some View {
        NavigationStack {
            if didSucceed {
                successView
            } else {
                formView
            }
        }
        .presentationDetents([.medium])
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
                    Text("Stok saat ini: \(size.currentStockQty) pcs")
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }
            .listSectionSeparator(.hidden)

            Section {
                HStack {
                    Text("Jumlah Masuk")
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

                        Button { qty += 1 } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(OuraTheme.Colors.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Alasan")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    HStack(spacing: 8) {
                        ForEach(StockReason.allCases, id: \.self) { r in
                            let selected = reason == r
                            Button { reason = r } label: {
                                Text(r.displayName)
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
                            .animation(.easeInOut(duration: 0.15), value: reason)
                        }
                    }
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                TextField("Catatan (opsional)", text: $note)
                    .font(.system(size: 14))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            } header: {
                OuraSectionHeader(title: "Stok Masuk")
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
        .navigationTitle("Stok Masuk")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Batal") { dismiss() }
                    .foregroundStyle(OuraTheme.Colors.accent)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Simpan") { Task { await save() } }
                        .foregroundStyle(canSave ? OuraTheme.Colors.accent : OuraTheme.Colors.textDisabled)
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Success view

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(OuraTheme.Colors.greenAccent)
            Text("Stok masuk \(qty) pcs")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
            Text(size.displayLabel)
                .font(.system(size: 15))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Text("Stok baru: ~\(size.currentStockQty + qty) pcs")
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
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
            _ = try await api.adjustStock(
                sku: size.productSku,
                sizeId: size.id,
                qty: qty,
                reason: reason.rawValue,
                note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note
            )
            didSucceed = true
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
