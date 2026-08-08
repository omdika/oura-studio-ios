import SwiftUI

// Known settings definitions — always shown even when DB is empty.
// PATCH /settings is an upsert, so saving here works whether the row exists or not.
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

struct SettingsView: View {
    @EnvironmentObject private var api: APIService

    @State private var dbValues: [String: Double] = [:]
    @State private var editedValues: [String: Double] = [:]
    @State private var savedKeys: Set<String> = []
    @State private var isLoading = true
    @State private var isSaving: Set<String> = []
    @State private var errorMsg: String?

    private var grouped: [(category: String, defs: [SettingDef])] {
        let dict = Dictionary(grouping: knownSettings, by: { $0.category })
        return dict.sorted { $0.key < $1.key }
                   .map { (category: $0.key, defs: $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuraTheme.Spacing.sectionGap) {
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
            }
            .padding(.horizontal, OuraTheme.Spacing.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(OuraTheme.Colors.background)
        .refreshable { await load() }
        .task { await load() }
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
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
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
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
        isSaving.remove(def.key)
    }
}

// MARK: - Setting row

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
                    .onChange(of: text) { _, new in
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
        .onChange(of: displayValue) { _, v in
            if !isFocused { text = formatValue(v) }
        }
    }

    private func formatValue(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
    }
}
