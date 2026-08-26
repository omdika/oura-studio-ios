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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: OuraTheme.Spacing.sectionGap) {
                        headerSection
                        salesCard
                        quickActionsSection
                        if let dash = dashboard, !dash.lowStockAlerts.isEmpty {
                            stockAlertsSection(dash.lowStockAlerts)
                        }
                    }
                    .padding(.horizontal, OuraTheme.Spacing.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .refreshable { await loadDashboard() }

                salesCapsuleSection
            }
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

    // MARK: - Stock alerts (Horizontal Scroll)

    private func stockAlertsSection(_ alerts: [LowStockAlert]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                OuraSectionHeader(title: "Peringatan Stok")
                Spacer()
                Text("\(alerts.count) item")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(alerts) { alert in
                        stockAlertCard(alert)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
    }

    private func stockAlertCard(_ alert: LowStockAlert) -> some View {
        let isOut = alert.currentStockQty == 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Ukuran \(alert.sizeLabel)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                Spacer()
                OuraTag(
                    text: isOut ? "Habis" : "Menipis",
                    color: isOut ? OuraTheme.Colors.dangerText : OuraTheme.Colors.warningText,
                    bg:    isOut ? OuraTheme.Colors.dangerBg   : OuraTheme.Colors.warningBg
                )
            }
            
            Text(alert.productName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
                .lineLimit(1)
            
            Text("\(alert.currentStockQty) pcs tersisa")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isOut ? OuraTheme.Colors.dangerText : OuraTheme.Colors.textSecondary)
        }
        .padding(12)
        .frame(width: 165)
        .background(OuraTheme.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: OuraTheme.Radius.card)
                .stroke(OuraTheme.Colors.border, lineWidth: 0.75)
        )
    }

    // MARK: - Quick actions (Simetris 2x2 Grid)

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OuraSectionHeader(title: "Aksi Cepat")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 52, height: 52)
                    .background(bg)
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.standard))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(OuraTheme.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: OuraTheme.Radius.card)
                    .stroke(OuraTheme.Colors.border, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sales Capsule Bottom Section

    private var salesCapsuleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KASIR PENJUALAN KILAT")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .kerning(1.2)
                .padding(.horizontal, OuraTheme.Spacing.horizontal)
            
            HStack(spacing: 12) {
                // Catat Penjualan (Manual)
                Button {
                    showTambahPenjualan = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bag.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.greenAccent)
                            .frame(width: 38, height: 38)
                            .background(OuraTheme.Colors.greenBg)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Catat Penjualan")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                            Text("Input Manual")
                                .font(.system(size: 10))
                                .foregroundStyle(OuraTheme.Colors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(OuraTheme.Colors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: OuraTheme.Radius.card)
                            .stroke(OuraTheme.Colors.border, lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
                
                // Scan & Jual (QR Scanner)
                Button {
                    showQRScanner = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.accent)
                            .frame(width: 38, height: 38)
                            .background(OuraTheme.Colors.accentLight)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scan & Jual")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                            Text("Pindai QR")
                                .font(.system(size: 10))
                                .foregroundStyle(OuraTheme.Colors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(OuraTheme.Colors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: OuraTheme.Radius.card)
                            .stroke(OuraTheme.Colors.border, lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, OuraTheme.Spacing.horizontal)
        }
        .padding(.vertical, 14)
        .background(OuraTheme.Colors.surfaceSheet)
        .overlay(
            VStack {
                Divider().overlay(OuraTheme.Colors.separator)
                Spacer()
            }
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: -4)
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
