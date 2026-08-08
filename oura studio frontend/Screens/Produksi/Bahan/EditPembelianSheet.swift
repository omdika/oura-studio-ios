import SwiftUI

struct EditPembelianSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let material: Material
    let purchase: MaterialPurchase
    var onUpdated: ((MaterialPurchase) -> Void)? = nil
    var onDeleted: (() -> Void)? = nil

    @State private var widthCm: Double?
    @State private var lengthCm: Double?
    @State private var qty: Double?
    @State private var totalCost: Double?
    @State private var selectedSupplierId: UUID?
    @State private var selectedSupplierName: String = ""
    @State private var purchasedAt: Date = Date()
    @State private var suppliers: [Supplier] = []
    @State private var isSaving = false
    @State private var showDeleteAlert = false
    @State private var errorMsg: String?

    private var isFabric:   Bool { material.category == .fabric }
    private var isThread:   Bool { material.category == .thread }
    private var isHardware: Bool { material.category == .hardware }
    private var isConsumed: Bool { purchase.isConsumed }

    private var canSave: Bool {
        if isFabric { return (widthCm ?? 0) > 0 && (lengthCm ?? 0) > 0 && (totalCost ?? 0) > 0 }
        return (qty ?? 0) > 0 && (totalCost ?? 0) > 0
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider().overlay(OuraTheme.Colors.separator)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    bahanRow
                    dimensionsBlock
                    costBlock
                    dateSupplierRow
                    if let err = errorMsg {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.dangerText)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(OuraTheme.Colors.dangerBg)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                    }
                }
                .padding(16)
                .padding(.bottom, 8)
            }

            // Save button
            VStack(spacing: 0) {
                Divider().overlay(OuraTheme.Colors.separator)
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Simpan Perubahan")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canSave ? OuraTheme.Colors.accentGradient : LinearGradient(colors: [OuraTheme.Colors.border], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                }
                .buttonStyle(.plain)
                .disabled(!canSave || isSaving)
                .padding(16)
                .padding(.bottom, 4)
            }
            .background(OuraTheme.Colors.background)
        }
        .background(OuraTheme.Colors.background)
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
        .alert("Hapus pembelian ini?", isPresented: $showDeleteAlert) {
            Button("Batal", role: .cancel) {}
            Button("Hapus", role: .destructive) { Task { await delete() } }
        } message: {
            Text("Tindakan ini tidak bisa dibatalkan.")
        }
        .onAppear { loadInitialState() }
        .task { suppliers = (try? await api.getSuppliers()) ?? [] }
    }

    // MARK: - Sheet header

    private var sheetHeader: some View {
        HStack {
            Text("Edit Pembelian")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
            Spacer()
            if !isConsumed {
                Button {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundStyle(OuraTheme.Colors.dangerText)
                        .frame(width: 36, height: 36)
                        .background(OuraTheme.Colors.dangerBg)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(OuraTheme.Colors.surfaceSheet)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(OuraTheme.Colors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Bahan row (locked)

    private var bahanRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Bahan")
            HStack {
                Text(material.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                Text("Ubah")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(OuraTheme.Colors.surfaceSheet.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                    .stroke(OuraTheme.Colors.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Dimensions block

    @ViewBuilder
    private var dimensionsBlock: some View {
        if isConsumed {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(OuraTheme.Colors.warningText)
                Text("Sudah dipakai di produksi — dimensi tidak bisa diubah")
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.warningText)
            }
            .padding(10)
            .background(OuraTheme.Colors.warningBg)
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
        }

        if isFabric {
            HStack(spacing: 12) {
                dimensionField(label: "Lebar (cm)", value: $widthCm, unit: "cm", locked: isConsumed)
                dimensionField(label: "Panjang (cm)", value: $lengthCm, unit: "cm", locked: isConsumed)
            }
        } else if isThread {
            HStack(spacing: 12) {
                if let label = purchase.packageLabel {
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Ukuran Kemasan")
                        Text(label)
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(OuraTheme.Colors.surfaceSheet.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                            .overlay(
                                RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                                    .stroke(OuraTheme.Colors.border, lineWidth: 1)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
                dimensionField(label: "Jumlah (gulung)", value: $qty, unit: "gulung", locked: isConsumed)
            }
        } else {
            dimensionField(
                label: "Jumlah (\(material.purchaseUnit))",
                value: $qty,
                unit: material.purchaseUnit,
                locked: isConsumed
            )
            if isHardware && purchase.lengthCm != nil {
                dimensionField(label: "Panjang (cm)", value: $lengthCm, unit: "cm", locked: isConsumed)
            }
        }
    }

    private func dimensionField(label: String, value: Binding<Double?>, unit: String, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label)
            NumericInputField(label: "", value: value, unit: unit)
                .disabled(locked)
                .opacity(locked ? 0.45 : 1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Cost block

    private var costBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Total Biaya")
            CurrencyInputField(label: "", value: $totalCost)
        }
    }

    // MARK: - Date + Supplier (side-by-side)

    private var dateSupplierRow: some View {
        HStack(alignment: .top, spacing: 12) {
            OuraDatePickerField(label: "Tanggal", date: $purchasedAt)
                .frame(maxWidth: .infinity)

            InlineSearchDropdownField(
                label: "Supplier (opsional)",
                selectedId: $selectedSupplierId,
                selectedName: $selectedSupplierName,
                items: suppliers.map { (id: $0.id, name: $0.name) },
                placeholder: "Cari supplier...",
                onCreateNew: { name in
                    Task {
                        let s = try? await api.createSupplier(name: name)
                        if let s {
                            suppliers.append(s)
                            selectedSupplierId = s.id
                            selectedSupplierName = s.name
                        }
                    }
                }
            )
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(OuraTheme.Colors.textTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // MARK: - Data

    private func loadInitialState() {
        widthCm       = purchase.widthCm
        lengthCm      = purchase.lengthCm
        qty           = purchase.qty
        totalCost     = purchase.totalCost
        purchasedAt   = purchase.purchasedAt
        selectedSupplierId   = purchase.supplierId
        selectedSupplierName = purchase.supplierName ?? ""
    }

    private func save() async {
        isSaving = true
        errorMsg = nil
        defer { isSaving = false }

        do {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withFullDate]

            let req = PatchPurchaseRequest(
                widthCm:     (!isConsumed && isFabric)  ? widthCm  : nil,
                lengthCm:    (!isConsumed && (isFabric || (isHardware && purchase.lengthCm != nil))) ? lengthCm : nil,
                qty:         (!isConsumed && !isFabric) ? qty      : nil,
                totalCost:   totalCost,
                supplierId:  selectedSupplierId,
                supplierName: selectedSupplierId == nil && !selectedSupplierName.isEmpty
                    ? selectedSupplierName : nil,
                purchasedAt: fmt.string(from: purchasedAt)
            )
            let updated = try await api.patchPurchase(
                materialId: material.id,
                purchaseId: purchase.id,
                req
            )
            onUpdated?(updated)
            dismiss()
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func delete() async {
        do {
            try await api.deletePurchase(materialId: material.id, purchaseId: purchase.id)
            onDeleted?()
            dismiss()
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
