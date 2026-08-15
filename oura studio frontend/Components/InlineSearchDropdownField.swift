import SwiftUI

/// Inline searchable dropdown — shows results directly below the field (no separate modal sheet).
/// Use this inside custom VStack layouts (not inside Form rows).
struct InlineSearchDropdownField: View {
    let label: String
    @Binding var selectedId: UUID?
    @Binding var selectedName: String
    let items: [(id: UUID, name: String)]
    var placeholder: String = "Cari..."
    var onCreateNew: ((String) -> Void)? = nil

    @State private var query: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var focused: Bool

    private var filtered: [(id: UUID, name: String)] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return Array(items.prefix(6)) }
        return items.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private var showDropdown: Bool {
        isEditing && (focused || !filtered.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            if !isEditing && !selectedName.isEmpty {
                // Selected state
                HStack {
                    Text(selectedName)
                        .font(.system(size: 15))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Spacer()
                    Button("Ubah") {
                        query = selectedName
                        isEditing = true
                        focused = true
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(OuraTheme.Colors.surfaceSheet)
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                        .stroke(OuraTheme.Colors.border, lineWidth: 1)
                )
            } else {
                // Search input
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                    TextField(placeholder, text: $query)
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focused)
                        .onChange(of: focused) { _, isFocused in
                            if isFocused { isEditing = true }
                        }
                        .accessibilityIdentifier("inline-search-\(label)")
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(OuraTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(OuraTheme.Colors.surfaceSheet)
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                        .stroke(focused ? OuraTheme.Colors.accent : OuraTheme.Colors.border, lineWidth: 1)
                )
                .onAppear { if isEditing { focused = true } }

                // Inline results — always visible when there are items or a create option
                if !filtered.isEmpty || onCreateNew != nil {
                    VStack(spacing: 0) {
                        ForEach(filtered, id: \.id) { item in
                            Button {
                                selectedId = item.id
                                selectedName = item.name
                                query = ""
                                isEditing = false
                                focused = false
                            } label: {
                                HStack {
                                    Text(item.name)
                                        .font(.system(size: 14))
                                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if selectedId == item.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(OuraTheme.Colors.accent)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            .background(OuraTheme.Colors.surfaceCard)
                            .accessibilityIdentifier("item-\(item.name)")
                            if item.id != filtered.last?.id {
                                Divider()
                                    .padding(.leading, 12)
                                    .overlay(OuraTheme.Colors.separator)
                            }
                        }

                        if let create = onCreateNew {
                            let trimmed = query.trimmingCharacters(in: .whitespaces)
                            let exactMatch = !trimmed.isEmpty && filtered.contains(where: {
                                $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
                            })
                            if !exactMatch {
                                if !filtered.isEmpty {
                                    Divider().overlay(OuraTheme.Colors.separator)
                                }
                                Button {
                                    create(trimmed)
                                    if !trimmed.isEmpty {
                                        selectedName = trimmed
                                        query = ""
                                        isEditing = false
                                        focused = false
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(OuraTheme.Colors.accent)
                                            .font(.system(size: 14))
                                        Text(trimmed.isEmpty ? "Tambah Baru" : "Tambah \"\(trimmed)\"")
                                            .font(.system(size: 14))
                                            .foregroundStyle(OuraTheme.Colors.accent)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                .background(OuraTheme.Colors.surfaceCard)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                            .stroke(OuraTheme.Colors.border, lineWidth: 1)
                    )
                }
            }
        }
        .onChange(of: selectedId) { _, newId in
            if newId != nil {
                isEditing = false
                focused = false
                query = ""
            }
        }
    }
}
