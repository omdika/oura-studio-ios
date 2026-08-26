import SwiftUI

struct BerandaView: View {
    @EnvironmentObject private var api: APIService
    @EnvironmentObject private var appState: AppState

    @State private var dashboard: DashboardSummary?
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var showTambahPembelian = false
    @State private var showTambahPenjualan = false
    @State private var showQRScanner = false
    @State private var alertDisplayCount = 4

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return "Selamat pagi"
        case 11..<15: return "Selamat siang"
        case 15..<18: return "Selamat sore"
        default:      return "Selamat malam"
        }
    }

    private var todayFormatted: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "id_ID")
        fmt.dateFormat = "EEEE, d MMMM yyyy"
        return fmt.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OuraTheme.Spacing.sectionGap) {
                    headerSection
                    salesCard
                    
                    quickActionsSection
                    
                    if let dash = dashboard, !dash.lowStockAlerts.isEmpty {
                        stockAlertsSection(dash.lowStockAlerts)
                    }
                    
                    // Modul Kasir Penjualan Kilat kini berada di dalam ScrollView,
                    // di urutan terbawah, sehingga sejajar 100% simetris secara horizontal!
                    salesCapsuleSection
                }
                .padding(.horizontal, OuraTheme.Spacing.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .refreshable { await loadDashboard() }
            .background(OuraTheme.Colors.background)
            .navigationBarHidden(true)
            .sheet(isPresented: $showTambahPembelian) {
                TambahPembelianSheet(preselectedMaterial: nil)
            }
            .sheet(isPresented: $showTambahPenjualan) {
                TambahPenjualanSheet()
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerSheet(mode: .sellOnly)
                    .environmentObject(api)
            }
        }
        .task { await loadDashboard() }
        .onChange(of: appState.dashboardNeedsRefresh) { needsRefresh in
            if needsRefresh {
                appState.dashboardNeedsRefresh = false
                Task { await loadDashboard() }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OURA STUDIOS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.accent)
                    .kerning(1.6)
                Text(greeting)
                    .font(.system(size: 27, weight: .heavy))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .tracking(-0.3)
            }
            Spacer()
            Text(todayFormatted)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
        }
        .padding(.top, 8)
    }

    // MARK: - Sales card

    private var salesCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OuraTheme.Radius.large)
                .fill(OuraTheme.Colors.accentGradient)

            VStack(alignment: .leading, spacing: 0) {
                Text("Pendapatan Hari Ini")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 6)

                if isLoading {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.25))
                        .frame(width: 180, height: 36)
                        .padding(.bottom, 14)
                } else {
                    Text((dashboard?.todayRevenue ?? 0).rupiahFormatted)
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundStyle(.white)
                        .tracking(-0.5)
                        .padding(.bottom, 14)
                }

                Divider()
                    .overlay(.white.opacity(0.3))
                    .padding(.bottom, 12)

                HStack {
                    statPill(
                        icon: "cart.fill",
                        label: "\(dashboard?.todayOrderCount ?? 0) transaksi"
                    )
                    Spacer()
                    statPill(
                        icon: "shippingbox.fill",
                        label: "\(dashboard?.todayUnitsSold ?? 0) item terjual"
                    )
                    Spacer()
                    statPill(
                        icon: "chart.line.uptrend.xyaxis",
                        label: String(format: "%.0f%% margin", (dashboard?.avgMarginPct ?? 0) * 100)
                    )
                }
            }
            .padding(OuraTheme.Spacing.cardPad + 4)
        }
        .shadow(color: OuraTheme.Colors.accent.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    private func statPill(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.9))
    }

    // MARK: - Stock alerts (Horizontal Scroll - Super Thin & Extended 50% horizontally)

    private func stockAlertsSection(_ alerts: [LowStockAlert]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                OuraSectionHeader(title: "Peringatan Stok")
                Spacer()
                Text("\(alerts.count) item")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(alerts) { alert in
                        stockAlertCard(alert)
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 2)
            }
        }
    }

    private func stockAlertCard(_ alert: LowStockAlert) -> some View {
        let isOut = alert.currentStockQty == 0
        return HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(isOut ? OuraTheme.Colors.dangerText : OuraTheme.Colors.warningText)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(alert.productName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text("Ukuran \(alert.sizeLabel) · \(alert.currentStockQty) pcs tersisa")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isOut ? OuraTheme.Colors.dangerText : OuraTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            OuraTag(
                text: isOut ? "Habis" : "Menipis",
                color: isOut ? OuraTheme.Colors.dangerText : OuraTheme.Colors.warningText,
                bg:    isOut ? OuraTheme.Colors.dangerBg   : OuraTheme.Colors.warningBg
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 260, height: 46) // Extended 50% horizontally (from 175 to 260)!
        .background(OuraTheme.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(OuraTheme.Colors.border, lineWidth: 0.75)
        )
    }

    // MARK: - Quick actions (Simetris 2x2 Grid - Larger Robust Size)

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            OuraSectionHeader(title: "Aksi Cepat")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                quickActionTile(
                    icon: "cart.badge.plus",
                    title: "Beli Bahan",
                    color: OuraTheme.Colors.blueAccent,
                    bg: OuraTheme.Colors.blueBg
                ) { showTambahPembelian = true }

                quickActionTile(
                    icon: "hammer.fill",
                    title: "Catat Produksi",
                    color: OuraTheme.Colors.accent,
                    bg: OuraTheme.Colors.accentLight
                ) {
                    appState.produksiSubTabIndex = 3 // ProduksiTab.produksi
                    appState.selectedTab = 1
                }

                quickActionTile(
                    icon: "scissors",
                    title: "Optimasi Pola",
                    color: OuraTheme.Colors.purple,
                    bg: OuraTheme.Colors.purpleBg
                ) {
                    appState.produksiSubTabIndex = 2 // ProduksiTab.optimasi
                    appState.selectedTab = 1
                }

                quickActionTile(
                    icon: "chart.bar.xaxis",
                    title: "Laporan Laba",
                    color: OuraTheme.Colors.purple,
                    bg: OuraTheme.Colors.purpleBg
                ) {
                    appState.selectedTab = 4 // tab Lainnya (Reports)
                }
            }
        }
    }

    private func quickActionTile(
        icon: String,
        title: String,
        color: Color,
        bg: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(bg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12) // Enlarged vertical spacing to fill empty spaces robustly
            .background(OuraTheme.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(OuraTheme.Colors.border, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sales Capsule Bottom Section (Vivid Emerald vs Terracotta Contrast Gradient)

    private var salesCapsuleSection: some View {
        let greenGrad = LinearGradient(
            colors: [Color(red: 0.18, green: 0.68, blue: 0.38), Color(red: 0.08, green: 0.48, blue: 0.24)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let terracottaGrad = LinearGradient(
            colors: [Color(red: 0.90, green: 0.38, blue: 0.20), Color(red: 0.75, green: 0.24, blue: 0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return VStack(alignment: .leading, spacing: 10) {
            Text("KASIR PENJUALAN KILAT")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .kerning(1.2)
            
            HStack(spacing: 12) {
                // Catat Penjualan (Manual)
                Button {
                    showTambahPenjualan = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "bag.badge.plus")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(.white.opacity(0.18))
                            .clipShape(Circle())
                        
                        VStack(spacing: 2) {
                            Text("Catat Penjualan")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(.white)
                            Text("Input Manual")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(greenGrad)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color(red: 0.15, green: 0.55, blue: 0.30).opacity(0.20), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                
                // Scan & Jual (QR Scanner)
                Button {
                    showQRScanner = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(.white.opacity(0.18))
                            .clipShape(Circle())
                        
                        VStack(spacing: 2) {
                            Text("Scan & Jual")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(.white)
                            Text("Pindai QR")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(terracottaGrad)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color(red: 0.75, green: 0.24, blue: 0.12).opacity(0.20), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Data

    private func loadDashboard() async {
        isLoading = true
        errorMsg = nil
        do {
            dashboard = try await api.getDashboard()
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }
}
