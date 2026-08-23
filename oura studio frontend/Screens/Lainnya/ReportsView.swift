import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var api: APIService

    var body: some View {
        List {
            Section {
                NavigationLink(destination: SalesReportDetailView()) {
                    reportRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Laporan Penjualan",
                        subtitle: "Pendapatan & profit per periode",
                        color: OuraTheme.Colors.blueAccent,
                        bg: OuraTheme.Colors.blueBg
                    )
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowSeparatorTint(OuraTheme.Colors.separator)

                NavigationLink(destination: MarginRankingView()) {
                    reportRow(
                        icon: "trophy.fill",
                        title: "Ranking Margin Produk",
                        subtitle: "Produk dengan margin tertinggi",
                        color: OuraTheme.Colors.warningText,
                        bg: OuraTheme.Colors.warningBg
                    )
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowSeparatorTint(OuraTheme.Colors.separator)

                NavigationLink(destination: WasteReportView()) {
                    reportRow(
                        icon: "scissors",
                        title: "Analisis Waste Kain",
                        subtitle: "Persentase sisa kain per bahan",
                        color: OuraTheme.Colors.dangerText,
                        bg: OuraTheme.Colors.dangerBg
                    )
                }
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowSeparatorTint(OuraTheme.Colors.separator)
            } header: {
                OuraSectionHeader(title: "Laporan Tersedia")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(OuraTheme.Colors.background)
    }

    private func reportRow(icon: String, title: String, subtitle: String, color: Color, bg: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Shared report state helpers

private func reportErrorView(icon: String, message: String) -> some View {
    VStack(spacing: 12) {
        Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 32))
            .foregroundStyle(OuraTheme.Colors.warningText)
        Text("Gagal memuat laporan")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(OuraTheme.Colors.textPrimary)
        Text(message)
            .font(.system(size: 12))
            .foregroundStyle(OuraTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

private func reportEmptyView(icon: String, title: String, subtitle: String) -> some View {
    VStack(spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 32))
            .foregroundStyle(OuraTheme.Colors.textTertiary)
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(OuraTheme.Colors.textPrimary)
        Text(subtitle)
            .font(.system(size: 13))
            .foregroundStyle(OuraTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

// MARK: - Sales Report Detail

struct SalesReportDetailView: View {
    @EnvironmentObject private var api: APIService

    @State private var report: SalesReport?
    @State private var byProduct: [SalesByProductItem] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var fromDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var toDate: Date = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuraTheme.Spacing.sectionGap) {
                VStack(alignment: .leading, spacing: 10) {
                    OuraSectionHeader(title: "Rentang Waktu")
                    DateRangeField(from: $fromDate, to: $toDate) {
                        Task { await load() }
                    }
                }
                .padding(OuraTheme.Spacing.cardPad)
                .ouraCard()

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else if let msg = errorMsg {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                            .foregroundStyle(OuraTheme.Colors.warningText)
                        Text("Gagal memuat laporan")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                        Text(msg)
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                } else if let r = report, r.points.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 28))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                        Text("Belum ada transaksi di periode ini")
                            .font(.system(size: 14))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                } else if let r = report {
                    VStack(alignment: .leading, spacing: 12) {
                        OuraSectionHeader(title: "Ringkasan")
                        HStack {
                            summaryCell("Total Pendapatan", value: r.totalRevenue.rupiahFormatted)
                            Spacer()
                            summaryCell("Total Profit", value: r.totalProfit.rupiahFormatted)
                            Spacer()
                            summaryCell("Transaksi", value: "\(r.points.reduce(0) { $0 + $1.orderCount })")
                        }
                        .padding(OuraTheme.Spacing.cardPad)
                        .ouraCard()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        OuraSectionHeader(title: "Per Periode")
                        VStack(spacing: 0) {
                            ForEach(r.points) { point in
                                HStack {
                                    Text(point.period)
                                        .font(.system(size: 13))
                                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(point.totalRevenue.rupiahFormatted)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                                        Text("\(point.orderCount) transaksi")
                                            .font(.system(size: 11))
                                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                if point.id != r.points.last?.id {
                                    Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                                }
                            }
                        }
                        .ouraCard()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        OuraSectionHeader(title: "Per Barang")
                        if byProduct.isEmpty {
                            Text("Belum ada barang terjual di periode ini")
                                .font(.system(size: 13))
                                .foregroundStyle(OuraTheme.Colors.textTertiary)
                                .padding(OuraTheme.Spacing.cardPad)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .ouraCard()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(byProduct) { item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.displayLabel)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                                            Text("\(item.qtySold) pcs terjual")
                                                .font(.system(size: 11))
                                                .foregroundStyle(OuraTheme.Colors.textTertiary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(item.revenue.rupiahFormatted)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                                            Text("profit \(item.profit.rupiahFormatted)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(item.profit >= 0 ? OuraTheme.Colors.greenAccent : OuraTheme.Colors.dangerText)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    if item.id != byProduct.last?.id {
                                        Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                                    }
                                }
                            }
                            .ouraCard()
                        }
                    }
                }
            }
            .padding(.horizontal, OuraTheme.Spacing.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(OuraTheme.Colors.background)
        .navigationTitle("Laporan Penjualan")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func summaryCell(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundStyle(OuraTheme.Colors.textTertiary)
            Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(OuraTheme.Colors.textPrimary)
        }
    }

    private func load() async {
        isLoading = true
        errorMsg = nil
        do {
            report = try await api.getSalesReport(from: fromDate, to: toDate)
            // Separate endpoint/call -- don't let a failure here blank out the period summary
            // that already loaded successfully above.
            byProduct = (try? await api.getSalesByProduct(from: fromDate, to: toDate)) ?? []
        } catch {
            report = nil
            byProduct = []
            errorMsg = error.localizedDescription
            print("🔴 [SalesReport] load error: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Margin Ranking

struct MarginRankingView: View {
    @EnvironmentObject private var api: APIService

    @State private var ranking: [MarginRankingItem] = []
    @State private var isLoading = true
    @State private var errorMsg: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let msg = errorMsg {
                reportErrorView(icon: "trophy.fill", message: msg)
            } else if ranking.isEmpty {
                reportEmptyView(
                    icon: "trophy.fill",
                    title: "Belum ada data margin",
                    subtitle: "Atur HPP dan harga jual di halaman produk agar ranking margin bisa ditampilkan"
                )
            } else {
                List {
                    ForEach(Array(ranking.enumerated()), id: \.element.id) { idx, item in
                        HStack(spacing: 12) {
                            Text("#\(idx + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(idx < 3 ? OuraTheme.Colors.accent : OuraTheme.Colors.textTertiary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.fabricVariantName.map { "\(item.productName) · \($0)" } ?? "\(item.productName) · \(item.sizeLabel)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                                Text("HPP \(item.hpp.rupiahFormatted) · Jual \(item.sellingPrice.rupiahFormatted)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.0f%%", item.marginPct * 100))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(
                                        item.marginPct >= 0.3 ? OuraTheme.Colors.greenAccent : OuraTheme.Colors.warningText
                                    )
                                Text("margin")
                                    .font(.system(size: 10))
                                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                            }
                        }
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .listRowSeparatorTint(OuraTheme.Colors.separator)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(OuraTheme.Colors.background)
            }
        }
        .navigationTitle("Ranking Margin")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMsg = nil
        do {
            ranking = try await api.getMarginRanking()
        } catch {
            errorMsg = error.localizedDescription
            ranking = []
            print("🔴 [MarginRanking] error: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Waste Report

struct WasteReportView: View {
    @EnvironmentObject private var api: APIService

    @State private var wasteItems: [WasteByMaterial] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var fromDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var toDate: Date = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuraTheme.Spacing.sectionGap) {
                VStack(alignment: .leading, spacing: 10) {
                    OuraSectionHeader(title: "Rentang Waktu")
                    DateRangeField(from: $fromDate, to: $toDate) {
                        Task { await load() }
                    }
                }
                .padding(OuraTheme.Spacing.cardPad)
                .ouraCard()

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else if let msg = errorMsg {
                    reportErrorView(icon: "scissors", message: msg)
                } else if wasteItems.isEmpty {
                    reportEmptyView(
                        icon: "scissors",
                        title: "Belum ada data waste",
                        subtitle: "Data waste diambil dari layout potong yang sudah dikonfirmasi di tab Produksi"
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(wasteItems.sorted { $0.avgWastePct > $1.avgWastePct }) { item in
                            HStack {
                                Text(item.materialName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "%.1f%% waste", item.avgWastePct * 100))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(
                                            item.avgWastePct > 0.2 ? OuraTheme.Colors.dangerText : OuraTheme.Colors.greenAccent
                                        )
                                    Text("\(item.totalWasteAreaCm2, specifier: "%.0f") cm²")
                                        .font(.system(size: 11))
                                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            if item.id != wasteItems.last?.id {
                                Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                            }
                        }
                    }
                    .ouraCard()
                }
            }
            .padding(.horizontal, OuraTheme.Spacing.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(OuraTheme.Colors.background)
        .navigationTitle("Waste Kain")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMsg = nil
        do {
            wasteItems = try await api.getWasteByMaterial(from: fromDate, to: toDate)
        } catch {
            errorMsg = error.localizedDescription
            wasteItems = []
            print("🔴 [WasteReport] error: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Date Range Field

private struct DateRangeField: View {
    @Binding var from: Date
    @Binding var to: Date
    var onApply: () -> Void = {}

    @State private var showPicker = false

    var body: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundStyle(OuraTheme.Colors.accent)
                Text(rangeLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(OuraTheme.Colors.surfaceSheet)
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
            .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                .stroke(OuraTheme.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            DateRangePickerSheet(initialFrom: from, initialTo: to) { newFrom, newTo in
                from = newFrom
                to = newTo
                onApply()
            }
        }
    }

    private var rangeLabel: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "id_ID")
        fmt.dateFormat = "d MMM"
        let fmtFull = DateFormatter()
        fmtFull.locale = Locale(identifier: "id_ID")
        fmtFull.dateFormat = "d MMM yyyy"
        return "\(fmt.string(from: from)) – \(fmtFull.string(from: to))"
    }
}

// MARK: - Date Range Picker Sheet

private struct DateRangePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onApply: (Date, Date) -> Void

    @State private var from: Date
    @State private var to: Date

    private let cal = Calendar.current

    init(initialFrom: Date, initialTo: Date, onApply: @escaping (Date, Date) -> Void) {
        _from = State(initialValue: initialFrom)
        _to = State(initialValue: initialTo)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preset chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("7 Hari") { applyDays(7) }
                        chip("30 Hari") { applyDays(30) }
                        chip("Bulan Ini") { applyThisMonth() }
                        chip("Bulan Lalu") { applyLastMonth() }
                        chip("3 Bulan") { applyDays(90) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                Divider().overlay(OuraTheme.Colors.separator)

                // Date picker rows
                VStack(spacing: 0) {
                    HStack {
                        Text("Dari")
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                        Spacer()
                        DatePicker("Dari", selection: $from, in: ...to, displayedComponents: .date)
                            .labelsHidden()
                            .tint(OuraTheme.Colors.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(OuraTheme.Colors.surfaceCard)

                    Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)

                    HStack {
                        Text("Sampai")
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                        Spacer()
                        DatePicker("Sampai", selection: $to, in: from..., displayedComponents: .date)
                            .labelsHidden()
                            .tint(OuraTheme.Colors.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(OuraTheme.Colors.surfaceCard)
                }
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                    .stroke(OuraTheme.Colors.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()
            }
            .background(OuraTheme.Colors.background)
            .navigationTitle("Pilih Periode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terapkan") {
                        onApply(from, to)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func chip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(OuraTheme.Colors.surfaceSheet)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(OuraTheme.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func applyDays(_ days: Int) {
        to = Date()
        from = cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    private func applyThisMonth() {
        let now = Date()
        from = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        to = now
    }

    private func applyLastMonth() {
        let now = Date()
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        to = cal.date(byAdding: .day, value: -1, to: startOfThisMonth) ?? now
        from = cal.date(from: cal.dateComponents([.year, .month], from: to)) ?? to
    }
}
