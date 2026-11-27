import SwiftUI

/// Sheet tambah produk baru/terlewat di tengah sesi stok opname.
/// Digunakan untuk produk yang belum punya QR (belum terdaftar atau terlewat).
struct StokOpnameNewProductSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let sessionId: UUID

    @State private var productName: String = ""
    @State private var sku: String = ""
    @State private var sizeLabel: String = ""
    @State private var fabricVariant: String = ""
    @State private var scannedQty: String = ""
    @State private var isSaving = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nama Produk", text: $productName)
                        .font(.system(size: 14))
                    TextField("SKU (biarkan kosong untuk auto)", text: $sku)
                        .font(.system(size: 14))
                        .autocapitalization(.allCharacters)
                    TextField("Ukuran (mis. M, L)", text: $sizeLabel)
                        .font(.system(size: 14))
                    TextField("Varian Kain (opsional)", text: $fabricVariant)
                        .font(.system(size: 14))
                    TextField("Jumlah Fisik (pcs)", text: $scannedQty)
                        .font(.system(size: 14))
                        .keyboardType(.numberPad)
                } header: {
                    OuraSectionHeader(title: "Produk Baru / Terlewat")
                } footer: {
                    Text("Produk akan didaftarkan baru dan langsung masuk ke hitungan opname.")
                        .font(.system(size: 12))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(OuraTheme.Colors.background)
            .navigationTitle("Tambah Produk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan & Masukkan") {
                        Task { await save() }
                    }
                    .foregroundStyle(OuraTheme.Colors.accent)
                    .disabled(!canSave || isSaving)
                }
            }
            .alert("Error", isPresented: .constant(errorMsg != nil)) {
                Button("OK") { errorMsg = nil }
            } message: {
                Text(errorMsg ?? "")
            }
        }
    }

    private var canSave: Bool {
        !productName.isEmpty && !sizeLabel.isEmpty && (Int(scannedQty) ?? 0) > 0
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            // 1. Buat produk baru
            let product = try await api.createProduct(name: productName, sku: sku.isEmpty ? nil : sku, category: nil)

            // 2. Buat ukuran (product_size) untuk produk ini
            let _ = try await api.createProductSize(
                sku: product.sku,
                sizeLabel: sizeLabel,
                fabricVariantName: fabricVariant.isEmpty ? nil : fabricVariant,
                reorderMinQty: nil,
                productName: productName
            )

            // 3. Dapatkan product_size yang baru dibuat (ambil dari getProductSizes)
            let sizes = try await api.getProductSizes(sku: product.sku, productName: productName)
            guard let newSize = sizes.first(where: { $0.sizeLabel == sizeLabel && $0.fabricVariantName == (fabricVariant.isEmpty ? nil : fabricVariant) }) else {
                throw APIError.serverError(500, "Gagal menemukan ukuran yang baru dibuat")
            }

            // 4. Tambahkan ke item opname
            let qty = Int(scannedQty) ?? 0
            let _ = try await api.addStockOpnameItem(
                sessionId: sessionId,
                productSizeId: newSize.id,
                scannedQty: Double(qty),
                note: "Produk baru ditambahkan selama opname"
            )

            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                if let apiErr = error as? APIError {
                    errorMsg = apiErr.errorDescription
                } else {
                    errorMsg = error.localizedDescription
                }
            }
        }
    }
}
