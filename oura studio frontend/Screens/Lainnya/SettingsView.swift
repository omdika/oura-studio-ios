import SwiftUI
import CoreBluetooth

struct SettingsView: View {
    @EnvironmentObject private var api: APIService
    @EnvironmentObject private var tsplPrinterService: TSPLPrinterService

    @State private var dbValues: [String: Double] = [:]
    @State private var editedValues: [String: Double] = [:]
    @State private var savedKeys: Set<String> = []
    @State private var isLoading = true
    @State private var isSaving: Set<String> = []
    @State private var errorMsg: String?
    @State private var isShowingPrinterSelection: Bool = false

    // Thermal Printer Settings
    @AppStorage("labelWidth") private var labelWidth: Double = 33.0
    @AppStorage("labelHeight") private var labelHeight: Double = 15.0
    @AppStorage("labelGap") private var labelGap: Double = 2.0
    @AppStorage("printerUUIDString") private var printerUUIDString: String = ""
    @AppStorage("printerName") private var printerName: String = ""
    @AppStorage("labelIncludePrice") private var labelIncludePrice: Bool = false

    private var grouped: [(category: String, defs: [SettingDef])] {
        let dict = Dictionary(grouping: knownSettings, by: { $0.category })
        return dict.sorted { $0.key < $1.key }
                   .map { (category: $0.key, defs: $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuraTheme.Spacing.sectionGap) {
                // MARK: - Pengaturan Umum
                Section {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    } else {
                        if let err = errorMsg {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(OuraTheme.Colors.dangerText)
                                    .font(.system(size: 14))
                                Text(err)
                                    .font(.system(size: 13))
                                    .foregroundStyle(OuraTheme.Colors.dangerText)
                            }
                            .padding(12)
                            .background(OuraTheme.Colors.dangerBg)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                        }

                        ForEach(grouped, id: \.category) { group in
                            settingGroup(group)
                        }
                    }
                } header: {
                    OuraSectionHeader(title: "Pengaturan Umum")
                }
                .padding(.bottom, OuraTheme.Spacing.sectionGap)

                // MARK: - Intercept Harga Event
                Section {
                    NavigationLink {
                        EventPriceAdjustmentView()
                    } label: {
                        HStack {
                            Text("Intercept / Ubah Harga Event")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        .padding()
                        .background(OuraTheme.Colors.surfaceSheet)
                        .cornerRadius(OuraTheme.Radius.medium)
                    }
                    .buttonStyle(.plain)
                    .ouraCard()
                } header: {
                    OuraSectionHeader(title: "Pengaturan Harga")
                }
                .padding(.bottom, OuraTheme.Spacing.sectionGap)

                // MARK: - Pengaturan Printer Thermal
                Section {
                    VStack(spacing: 0) {
                        SettingRow(
                            def: .init(key: "label_width", displayName: "Lebar Label", unit: "mm", category: "Printer Thermal", hint: "Lebar fisik label thermal dalam milimeter.", defaultValue: 33.0),
                            displayValue: labelWidth,
                            isSaving: false, isSaved: false, isDirty: false,
                            onChange: { labelWidth = $0 },
                            onSave: { }
                        )
                        Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                        SettingRow(
                            def: .init(key: "label_height", displayName: "Tinggi Label", unit: "mm", category: "Printer Thermal", hint: "Tinggi fisik label thermal dalam milimeter.", defaultValue: 15.0),
                            displayValue: labelHeight,
                            isSaving: false, isSaved: false, isDirty: false,
                            onChange: { labelHeight = $0 },
                            onSave: { }
                        )
                        Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                        SettingRow(
                            def: .init(key: "label_gap", displayName: "Jarak Antar Label", unit: "mm", category: "Printer Thermal", hint: "Jarak antar label (gap) dalam milimeter.", defaultValue: 2.0),
                            displayValue: labelGap,
                            isSaving: false, isSaved: false, isDirty: false,
                            onChange: { labelGap = $0 },
                            onSave: { }
                        )
                        Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                        LabelPriceRadioGroup(isOn: $labelIncludePrice)
                        Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)

                        Button {
                            isShowingPrinterSelection = true
                        } label: {
                            HStack {
                                Text("Pilih Printer Bluetooth")
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(tsplPrinterService.connectedPeripheral?.name ?? "Tidak Terhubung")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(tsplPrinterService.connectedPeripheral != nil ? OuraTheme.Colors.greenAccent : OuraTheme.Colors.textTertiary)
                                    Text(bluetoothStatusText)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            .padding()
                            .background(OuraTheme.Colors.surfaceSheet)
                            .cornerRadius(OuraTheme.Radius.medium)
                        }
                        .buttonStyle(.plain)
                    }
                    .ouraCard()

                    // X265L dual-mode: bahasa harus sesuai mode printer.
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.accent)
                            .padding(.top, 1)
                        Text("Printer ini punya 2 mode: Label (kertas label, untuk QR) dan Receipt (kertas struk). Ganti mode: nyalakan printer, TAHAN tombol FEED 5 detik sampai tercetak \"Shift to ... mode\", lalu nyalakan lagi.")
                            .font(.system(size: 12))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                } header: {
                    OuraSectionHeader(title: "Pengaturan Printer Thermal")
                }
            }
            .padding(.horizontal, OuraTheme.Spacing.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(OuraTheme.Colors.background)
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $isShowingPrinterSelection) {
            PrinterSelectionView()
                .environmentObject(tsplPrinterService)
        }
    }

    private var bluetoothStatusText: String {
        switch tsplPrinterService.bluetoothState {
        case .poweredOn:
            return tsplPrinterService.isScanning ? "Sedang mencari..." : "Siap"
        case .poweredOff:
            return "Mati"
        case .resetting:
            return "Mengatur ulang"
        case .unauthorized:
            return "Tidak diizinkan"
        case .unsupported:
            return "Tidak didukung"
        case .unknown:
            return "Menginisialisasi..."
        @unknown default:
            return "Status tidak diketahui"
        }
    }

    private func settingGroup(_ group: (category: String, defs: [SettingDef])) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            OuraSectionHeader(title: group.category)

            VStack(spacing: 0) {
                ForEach(group.defs, id: \.key) { def in
                    let currentDB = dbValues[def.key] ?? def.defaultValue
                    let edited = editedValues[def.key]
                    let displayVal = edited ?? currentDB
                    let saving = isSaving.contains(def.key)
                    let saved = savedKeys.contains(def.key)
                    let dirty = edited != nil && abs(edited! - currentDB) > 0.001

                    SettingRow(
                        def: def,
                        displayValue: displayVal,
                        isSaving: saving,
                        isSaved: saved,
                        isDirty: dirty,
                        onChange: { newVal in
                            editedValues[def.key] = newVal
                            savedKeys.remove(def.key)
                        },
                        onSave: { Task { await save(def) } }
                    )
                    if def.key != group.defs.last?.key {
                        Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                    }
                }
            }
            .ouraCard()
        }
    }

    private func load() async {
        isLoading = true; errorMsg = nil
        do {
            let items = try await api.getSettings()
            dbValues = Dictionary(uniqueKeysWithValues: items.map { ($0.key, $0.value) })
        } catch {
            // Pembatalan task (.task di-cancel saat pindah tab/segmen, atau
            // URLSession dibatalkan) bukan error — abaikan agar banner
            // "Koneksi gagal: cancelled" tidak muncul. APIService membungkus
            // pembatalan jadi APIError.networkError(URLError.cancelled),
            // jadi cek underlying error, bukan hanya CancellationError.
            if isTaskCancellation(error) {
                isLoading = false
                return
            }
            if let e = error as? APIError {
                errorMsg = e.errorDescription
            } else {
                errorMsg = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func save(_ def: SettingDef) async {
        let value = editedValues[def.key] ?? dbValues[def.key] ?? def.defaultValue
        isSaving.insert(def.key)
        errorMsg = nil
        do {
            let result = try await api.patchSetting(key: def.key, value: value)
            dbValues[def.key] = result.value
            editedValues.removeValue(forKey: def.key)
            savedKeys.insert(def.key)
        } catch {
            if isTaskCancellation(error) {
                isSaving.remove(def.key)
                return
            }
            if let e = error as? APIError {
                errorMsg = e.errorDescription
            } else {
                errorMsg = error.localizedDescription
            }
        }
        isSaving.remove(def.key)
    }

    /// True jika error hanyalah pembatalan task (pindah tab/segmen, view hilang,
    /// refresh tertimpa) — bukan kegagalan jaringan/server yang perlu ditampilkan.
    private func isTaskCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlErr = error as? URLError, urlErr.code == .cancelled { return true }
        let nsErr = error as NSError
        if nsErr.domain == NSURLErrorDomain && nsErr.code == NSURLErrorCancelled { return true }
        if let apiErr = error as? APIError,
           case .networkError(let underlying) = apiErr {
            return isTaskCancellation(underlying)
        }
        return false
    }
}

// MARK: - Known Settings
private struct SettingDef {
    let key: String
    let displayName: String
    let unit: String
    let category: String
    let hint: String
    let defaultValue: Double
}

private let knownSettings: [SettingDef] = [
    SettingDef(
        key: "labor_rate_per_minute",
        displayName: "Tarif Tenaga Kerja",
        unit: "Rp/menit",
        category: "Tenaga Kerja",
        hint: "Dasar perhitungan HPP labor. Contoh: 100 = Rp 100/menit.",
        defaultValue: 0
    ),
    SettingDef(
        key: "default_overhead_per_unit",
        displayName: "Overhead per Unit",
        unit: "Rp/pcs",
        category: "Overhead",
        hint: "Biaya tidak langsung per unit produksi (listrik, sewa, dll).",
        defaultValue: 0
    ),
    SettingDef(
        key: "pooled_material_rate:thread",
        displayName: "Benang per Unit",
        unit: "Rp/pcs",
        category: "Bahan Pooled",
        hint: "Estimasi biaya benang per unit. Dibagi rata ke semua produk.",
        defaultValue: 0
    ),
    SettingDef(
        key: "pooled_material_rate:packaging",
        displayName: "Packaging per Unit",
        unit: "Rp/pcs",
        category: "Bahan Pooled",
        hint: "Estimasi biaya packaging per unit.",
        defaultValue: 0
    ),
]

// MARK: - Setting Row
private struct SettingRow: View {
    let def: SettingDef
    let displayValue: Double
    let isSaving: Bool
    let isSaved: Bool
    let isDirty: Bool
    let onChange: (Double) -> Void
    let onSave: () -> Void

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(def.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Text(def.unit)
                    .font(.system(size: 11))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }

            Text(def.hint)
                .font(.system(size: 11))
                .foregroundStyle(OuraTheme.Colors.textTertiary)

            HStack(spacing: 8) {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .focused($isFocused)
                    .onChange(of: text) { new in
                        let normalized = new.replacingOccurrences(of: ",", with: ".")
                        if let v = Double(normalized) { onChange(v) }
                    }

                if isSaving {
                    ProgressView().scaleEffect(0.8)
                } else if isSaved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(OuraTheme.Colors.greenAccent)
                        .font(.system(size: 18))
                } else if isDirty || isFocused {
                    Button("Simpan") { onSave() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(OuraTheme.Colors.accentLight)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(OuraTheme.Colors.surfaceSheet)
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                    .stroke(isFocused ? OuraTheme.Colors.accent : OuraTheme.Colors.border, lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear { text = formatValue(displayValue) }
        .onChange(of: displayValue) { v in
            if !isFocused { text = formatValue(v) }
        }
    }

    private func formatValue(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
    }
}

// MARK: - Label Price Radio Group (v3.61: Sertakan Harga)
struct LabelPriceRadioGroup: View {
    @Binding var isOn: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Sertakan Harga di Label")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
            }
            Text("Jika aktif, harga jual akan dicetak di atas ukuran pada label thermal & PDF.")
                .font(.system(size: 11))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
            HStack(spacing: 16) {
                RadioOptionButton(title: "Ya", selected: isOn) { isOn = true }
                RadioOptionButton(title: "Tidak", selected: !isOn) { isOn = false }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct RadioOptionButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? OuraTheme.Colors.accent : OuraTheme.Colors.border)
                Text(title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? OuraTheme.Colors.textPrimary : OuraTheme.Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}
