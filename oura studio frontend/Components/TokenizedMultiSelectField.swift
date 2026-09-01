import SwiftUI

struct TokenizedMultiSelectField: View {
    let label: String
    @Binding var selectedIds: [UUID]
    let items: [(id: UUID, name: String)]
    var placeholder: String = "Pilih..."

    @State private var isExpanded: Bool = false
    @State private var query: String = ""

    private var selectedItems: [(id: UUID, name: String)] {
        items.filter { selectedIds.contains($0.id) }
    }

    private var filtered: [(id: UUID, name: String)] {
        query.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)

            Button {
                isExpanded = true
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    if selectedItems.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 15))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                    } else {
                        FlowLayout(spacing: 6) {
                            ForEach(selectedItems, id: \.id) { item in
                                HStack(spacing: 4) {
                                    Text(item.name)
                                        .font(.system(size: 12, weight: .semibold))
                                    Button {
                                        selectedIds.removeAll { $0 == item.id }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                }
                                .foregroundStyle(OuraTheme.Colors.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(OuraTheme.Colors.accentLight)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
            .accessibilityLabel(label)
            .accessibilityIdentifier("tokenized-field-\(label)")
        }
        .fullScreenCover(isPresented: $isExpanded) {
            selectSheet
        }
    }

    private var selectSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                    TextField("Cari...", text: $query)
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
                        ForEach(filtered, id: \.id) { item in
                            let isSelected = selectedIds.contains(item.id)
                            Button {
                                if isSelected {
                                    selectedIds.removeAll { $0 == item.id }
                                } else {
                                    selectedIds.append(item.id)
                                }
                            } label: {
                                HStack {
                                    Text(item.name)
                                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                                    Spacer()
                                    if isSelected {
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Selesai") { isExpanded = false }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
        }
    }
}

// MARK: - Flow layout for token chips

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, maxHeight: CGFloat = 0, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        y += rowHeight
        return CGSize(width: maxWidth, height: y)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
