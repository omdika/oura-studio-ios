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
                }
                .padding(.horizontal, OuraTheme.Spacing.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(OuraTheme.Colors.background)
            .refreshable { await loadDashboard() }
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

    // MARK: - Stock alerts

    private func stockAlertsSection(_ alerts: [LowStockAlert]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                OuraSectionHeader(title: "Peringatan Stok")
                Spacer()
                Text("\(alerts.count) item")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }

            let shown = Array(alerts.prefix(alertDisplayCount))
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { idx, alert in
                    stockAlertRow(alert)
                    if idx < shown.count - 1 {
                        Divider()
                            .padding(.leading, OuraTheme.Spacing.listItemH)
                            .overlay(OuraTheme.Colors.separator)
                    }
                }
            }
            .ouraCard(OuraTheme.Radius.card)

            if alertDisplayCount < alerts.count {
                Button {
                    alertDisplayCount += 4
                } label: {
                    Text("Muat Lebih Banyak (\(alerts.count - alertDisplayCount) lagi) ↓")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(OuraTheme.Colors.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                                .stroke(OuraTheme.Colors.border, lineWidth: 0.75)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func stockAlertRow(_ alert: LowStockAlert) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(alert.productName)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Text("Ukuran \(alert.sizeLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                let isOut = alert.currentStockQty == 0
                OuraTag(
                    text: isOut ? "Habis" : "Menipis",
                    color: isOut ? OuraTheme.Colors.dangerText : OuraTheme.Colors.warningText,
                    bg:    isOut ? OuraTheme.Colors.dangerBg   : OuraTheme.Colors.warningBg
                )
                Text("\(alert.currentStockQty) pcs")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, OuraTheme.Spacing.listItemH)
        .padding(.vertical, OuraTheme.Spacing.listItemV)
    }

    // MARK: - Quick actions

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
                    icon: "bag.badge.plus",
                    title: "Catat Penjualan",
                    color: OuraTheme.Colors.greenAccent,
                    bg: OuraTheme.Colors.greenBg
                ) { showTambahPenjualan = true }

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
                    icon: "qrcode.viewfinder",
                    title: "Scan & Jual",
                    color: OuraTheme.Colors.accent,
                    bg: OuraTheme.Colors.accentLight
                ) { showQRScanner = true }
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
