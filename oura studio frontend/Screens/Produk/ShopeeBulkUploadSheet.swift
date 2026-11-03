import SwiftUI

struct ShopeeBulkUploadSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var isDownloading = false
    @State private var errorMsg: String? = nil
    
    @State private var downloadedURL: URL? = nil
    @State private var showShareSheet = false
    
    // v3.79: mode ekspo + pilihan produk
    @State private var exportMode: ExportMode = .all
    @State private var selectedProductIds: Set<UUID> = []
    
    enum ExportMode: String, CaseIterable, Identifiable {
        case all = "all"
        case selection = "selection"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "Semua Produk Scrunchie & Pouch"
            case .selection: return "Pilih Produk Tertentu"
            }
        }
    }
    
    var scrunchieCount: Int {
        products.filter { $0.category == "scrunchie" && !$0.isArchived }.count
    }
    
    var pouchCount: Int {
        products.filter { $0.category == "pouch" && !$0.isArchived }.count
    }
    
    // v3.79: semua produk non-archived untuk daftar pilihan
    var allNonArchivedProducts: [Product] {
        products.filter { !$0.isArchived }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                OuraTheme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: OuraTheme.Spacing.sectionGap) {
                    // Header Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ekspor Massal Shopee")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                        
                        Text("Gunakan fitur ekspor massal untuk menghasilkan file Excel template Shopee yang berisi detail produk siap unggah.")
                            .font(.system(size: 14))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                    .padding(.top, 16)
                    
                    // v3.79: Mode Ekspor
                    VStack(alignment: .leading, spacing: 12) {
                        OuraSectionHeader(title: "Mode Ekspor")
                            .padding(.horizontal, OuraTheme.Spacing.horizontal)
                        
                        Picker("Mode Ekspor", selection: $exportMode) {
                            ForEach(ExportMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, OuraTheme.Spacing.horizontal)
                        
                        if exportMode == .all {
                            // Summary Section (existing behavior)
                            VStack(alignment: .leading, spacing: 12) {
                                OuraSectionHeader(title: "Ringkasan Produk Siap Ekspor")
                                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                                
                                if isLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .tint(OuraTheme.Colors.accent)
                                        Spacer()
                                    }
                                    .padding(.vertical, 24)
                                    .ouraCard()
                                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                                } else {
                                    VStack(spacing: 0) {
                                        // Scrunchie
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Scrunchie")
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                                                Text("Kategori ID: 100146")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                                            }
                                            Spacer()
                                            OuraTag(text: "\(scrunchieCount) Produk", color: OuraTheme.Colors.accent, bg: OuraTheme.Colors.accentLight)
                                        }
                                        .padding(.all, 16)
                                        
                                        Divider()
                                            .overlay(OuraTheme.Colors.separator)
                                            .padding(.horizontal, 16)
                                        
                                        // Pouch
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Pouch")
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                                                Text("Kategori ID: 101650")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                                            }
                                            Spacer()
                                            OuraTag(text: "\(pouchCount) Produk", color: OuraTheme.Colors.blueAccent, bg: OuraTheme.Colors.blueBg)
                                        }
                                        .padding(.all, 16)
                                    }
                                    .ouraCard()
                                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                                }
                            }
                        } else {
                            // v3.79: Daftar pilihan produk (semua non-archived)
                            VStack(alignment: .leading, spacing: 12) {
                                OuraSectionHeader(title: "Pilih Produk untuk Diekspor")
                                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                                
                                // Tombol Pilih Semua / Kosongkan + ringkasan
                                HStack {
                                    Button(
                                        selectedProductIds.count == allNonArchivedProducts.count && !allNonArchivedProducts.isEmpty
                                            ? "Kosongkan Semua" : "Pilih Semua"
                                    ) {
                                        if selectedProductIds.count == allNonArchivedProducts.count && !allNonArchivedProducts.isEmpty {
                                            selectedProductIds.removeAll()
                                        } else {
                                            selectedProductIds = Set(allNonArchivedProducts.map(\.id))
                                        }
                                    }
                                    .font(.system(size: 13))
                                    .foregroundStyle(OuraTheme.Colors.accent)
                                    
                                    Spacer()
                                    
                                    Text("\(selectedProductIds.count) dari \(allNonArchivedProducts.count) produk")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                                }
                                .padding(.horizontal, OuraTheme.Spacing.horizontal)
                                
                                if isLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .tint(OuraTheme.Colors.accent)
                                        Spacer()
                                    }
                                    .padding(.vertical, 24)
                                    .ouraCard()
                                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                                } else if allNonArchivedProducts.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "tag")
                                            .font(.system(size: 32))
                                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                                        Text("Tidak ada produk tersedia")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                                        Text("Tambah produk terlebih dahulu sebelum mengekspor.")
                                            .font(.system(size: 12))
                                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 24)
                                    .ouraCard()
                                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                                } else {
                                    // Daftar produk dengan checkbox
                                    ScrollView {
                                        VStack(spacing: 0) {
                                            ForEach(allNonArchivedProducts) { product in
                                                let isSelected = selectedProductIds.contains(product.id)
                                                HStack {
                                                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                                        .font(.system(size: 18))
                                                        .foregroundStyle(isSelected ? OuraTheme.Colors.accent : OuraTheme.Colors.textTertiary)
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(product.name)
                                                            .font(.system(size: 14, weight: .medium))
                                                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                                                        Text("\(product.sku) • \(product.category ?? "-")")
                                                            .font(.system(size: 12))
                                                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                                                    }
                                                    Spacer()
                                                }
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    if isSelected {
                                                        selectedProductIds.remove(product.id)
                                                    } else {
                                                        selectedProductIds.insert(product.id)
                                                    }
                                                }
                                                .padding(.horizontal, OuraTheme.Spacing.horizontal)
                                                .padding(.vertical, 10)
                                                if product.id != allNonArchivedProducts.last?.id {
                                                    Divider()
                                                        .padding(.leading, OuraTheme.Spacing.horizontal)
                                                        .overlay(OuraTheme.Colors.separator)
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 260)
                                    .ouraCard()
                                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                                }
                            }
                        }
                    }
                    
                    if let error = errorMsg {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(OuraTheme.Colors.dangerText)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(OuraTheme.Colors.dangerText)
                        }
                        .padding(.all, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OuraTheme.Colors.dangerBg)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.small))
                        .padding(.horizontal, OuraTheme.Spacing.horizontal)
                    }
                    
                    Spacer()
                    
                    // v3.62: Shopee gallery rules info (no template change).
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 12))
                                .foregroundStyle(OuraTheme.Colors.accent)
                            Text("Aturan gambar Shopee (v3.62)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                        }
                        Text("Baris variasi diurut XS→XXL. Baris pertama bawa galeri penuh (cover + 8). Baris ke-2 dst isi foto wakil size itu di kolom Sampul + Foto 1. Pilih 1 Foto Shopee per ukuran di halaman varian; foto pertama galeri jadi cover.")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                            .lineSpacing(3)
                    }
                    .padding(.all, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OuraTheme.Colors.accentLight.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.small))
                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                    
                    // Actions
                    VStack(spacing: 12) {
                        OuraPrimaryButton(
                            title: "Unduh Template Shopee",
                            isLoading: isDownloading,
                            action: downloadExcel
                        )
                        .disabled(isLoading || (exportMode == .selection && selectedProductIds.isEmpty))
                    }
                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Ekspor Shopee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") {
                        dismiss()
                    }
                    .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
            .task {
                await loadProducts()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = downloadedURL {
                    ActivityViewController(activityItems: [url])
                }
            }
        }
    }
    
    private func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await api.getProducts()
        } catch {
            errorMsg = "Gagal memuat daftar produk: \(error.localizedDescription)"
        }
    }
    
    private func downloadExcel() {
        isDownloading = true
        errorMsg = nil
        Task {
            defer { isDownloading = false }
            do {
                // v3.79: kirim daftar ID produk terpilih saat mode selection;
                // mode all mengirim nil (perilaku existing: semua scrunchie+pouch).
                let ids = exportMode == .selection ? Array(selectedProductIds) : nil
                let url = try await api.downloadShopeeBulkUploadExcel(productIds: ids)
                downloadedURL = url
                showShareSheet = true
            } catch let e as APIError {
                errorMsg = e.errorDescription ?? "Gagal mengunduh template Shopee"
            } catch {
                errorMsg = error.localizedDescription
            }
        }
    }
}
