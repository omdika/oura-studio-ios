import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var api: APIService

    @State private var settings: [SettingItem] = []
    @State private var editedValues: [String: Double] = [:]
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMsg: String?
    @State private var savedKeys: Set<String> = []

    private var grouped: [(category: String, items: [SettingItem])] {
        let dict = Dictionary(grouping: settings, by: { $0.category })
        return dict.sorted { $0.key < $1.key }
               .map { (category: $0.key, items: $0.value.sorted { $0.key < $1.key }) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuraTheme.Spacing.sectionGap) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else {
                    ForEach(grouped, id: \.category) { group in
                        settingGroup(group)
                    }
                }

                if let err = errorMsg {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.dangerText)
                        .padding(12)
                        .background(OuraTheme.Colors.dangerBg)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                }
            }
            .padding(.horizontal, OuraTheme.Spacing.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(OuraTheme.Colors.background)
        .task { await load() }
    }

    private func settingGroup(_ group: (category: String, items: [SettingItem])) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            OuraSectionHeader(title: group.category)

            VStack(spacing: 0) {
                ForEach(group.items) { item in
                    SettingRow(
                        item: item,
                        currentValue: editedValues[item.key] ?? item.value,
                        isSaved: savedKeys.contains(item.key),
                        onChange: { newVal in
                            editedValues[item.key] = newVal
                            savedKeys.remove(item.key)
                        },
                        onSave: { Task { await save(item) } }
                    )
                    if item.id != group.items.last?.id {
                        Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                    }
                }
            }
            .ouraCard()
        }
    }

    private func load() async {
        isLoading = true
        settings = (try? await api.getSettings()) ?? []
        isLoading = false
    }

    private func save(_ item: SettingItem) async {
        isSaving = true; errorMsg = nil; defer { isSaving = false }
        let value = editedValues[item.key] ?? item.value
        do {
            _ = try await api.patchSetting(key: item.key, value: value)
            savedKeys.insert(item.key)
            editedValues.removeValue(forKey: item.key)
            await load()
        } catch let e as APIError { errorMsg = e.errorDescription }
        catch { errorMsg = error.localizedDescription }
    }
}

// MARK: - Setting row

private struct SettingRow: View {
    let item: SettingItem
    let currentValue: Double
    let isSaved: Bool
    let onChange: (Double) -> Void
    let onSave: () -> Void

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    private var isDirty: Bool {
        abs((Double(text.replacingOccurrences(of: ",", with: ".")) ?? item.value) - item.value) > 0.001
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)

            HStack(spacing: 8) {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .focused($isFocused)
                    .onChange(of: text) { _, new in
                        let normalized = new.replacingOccurrences(of: ",", with: ".")
                        if let v = Double(normalized) { onChange(v) }
                    }

                if isSaved {
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
        .onAppear { text = formatValue(item.value) }
    }

    private func formatValue(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
    }
}
