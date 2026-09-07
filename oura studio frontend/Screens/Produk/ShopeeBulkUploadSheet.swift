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
    
    var scrunchieCount: Int {
        products.filter { $0.category == "scrunchie" && !$0.isArchived }.count
    }
    
    var pouchCount: Int {
        products.filter { $0.category == "pouch" && !$0.isArchived }.count
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
                        
                        Text("Gunakan fitur ekspor massal untuk menghasilkan file Excel template Shopee yang berisi detail produk Scrunchie dan Pouch siap unggah.")
                            .font(.system(size: 14))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                    .padding(.top, 16)
                    
                    // Summary Section
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
                    
                    // Actions
                    VStack(spacing: 12) {
                        OuraPrimaryButton(
                            title: "Unduh Template Shopee",
                            isLoading: isDownloading,
                            action: downloadExcel
                        )
                        .disabled(isLoading)
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
                let url = try await api.downloadShopeeBulkUploadExcel()
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
