import SwiftUI

struct SearchableDropdownField: View {
    let label: String
    @Binding var selectedId: UUID?
    @Binding var selectedName: String
    let items: [(id: UUID, name: String)]
    var placeholder: String = "Pilih..."
    var onCreateNew: ((String) -> Void)? = nil

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)

            Button {
                isExpanded = true
            } label: {
                HStack {
                    Text(selectedName.isEmpty ? placeholder : selectedName)
                        .font(.system(size: 15))
                        .foregroundStyle(
                            selectedName.isEmpty
                                ? OuraTheme.Colors.textTertiary
                                : OuraTheme.Colors.textPrimary
                        )
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(OuraTheme.Colors.surfaceSheet)
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                        .stroke(OuraTheme.Colors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectedName.isEmpty ? label : selectedName)
            .accessibilityIdentifier("dropdown-\(label)")
        }
        .sheet(isPresented: $isExpanded) {
            SearchPickerContent(
                label: label,
                items: items,
                isExpanded: $isExpanded,
                selectedId: $selectedId,
                selectedName: $selectedName,
                onCreateNew: onCreateNew
            )
        }
    }
}

private struct SearchPickerContent: View {
    let label: String
    let items: [(id: UUID, name: String)]
    @Binding var isExpanded: Bool
    @Binding var selectedId: UUID?
    @Binding var selectedName: String
    var onCreateNew: ((String) -> Void)?

    @State private var query: String = ""

    private var filtered: [(id: UUID, name: String)] {
        query.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                    TextField("Cari \(label.lowercased())...", text: $query)
                        .font(.system(size: 15))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("search-picker-\(label)")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(OuraTheme.Colors.surfaceSheet)
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                    .stroke(OuraTheme.Colors.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().overlay(OuraTheme.Colors.separator)

                ScrollView {
                    VStack(spacing: 0) {
                        if let create = onCreateNew {
                            Button {
                                let q = query
                                DispatchQueue.main.async { isExpanded = false }
                                create(q)
                            } label: {
                                Label(
                                    query.isEmpty ? "Tambah Baru" : "Tambah \"\(query)\"",
                                    systemImage: "plus.circle.fill"
                                )
                                .foregroundStyle(OuraTheme.Colors.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                            .background(OuraTheme.Colors.surfaceCard)
                            Divider().padding(.leading, 16).overlay(OuraTheme.Colors.separator)
                        }

                        ForEach(filtered, id: \.id) { item in
                            Button {
                                selectedId = item.id
                                selectedName = item.name
                                DispatchQueue.main.async { isExpanded = false }
                            } label: {
                                HStack {
                                    Text(item.name)
                                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                                    Spacer()
                                    if selectedId == item.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(OuraTheme.Colors.accent)
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .background(OuraTheme.Colors.surfaceCard)
                            .accessibilityIdentifier("item-\(item.name)")

                            if item.id != filtered.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                                    .overlay(OuraTheme.Colors.separator)
                            }
                        }
                    }
                    .background(OuraTheme.Colors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }

                Spacer(minLength: 0)
            }
            .background(OuraTheme.Colors.background)
            .navigationTitle(label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { isExpanded = false }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
        }
    }
}
