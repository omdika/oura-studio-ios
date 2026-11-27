import SwiftUI

struct ChipSingleSelect<T: Hashable>: View {
    let label: String
    @Binding var selected: T?
    let options: [(value: T, title: String)]
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            if !compact {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: compact ? 6 : 8) {
                    ForEach(options, id: \.value) { opt in
                        let isSelected = selected == opt.value
                        Button {
                            selected = isSelected ? nil : opt.value
                        } label: {
                            Text(opt.title)
                                .font(.system(size: compact ? 12 : 13, weight: .semibold))
                                .foregroundStyle(
                                    isSelected ? .white : OuraTheme.Colors.textSecondary
                                )
                                .padding(.horizontal, compact ? 10 : 14)
                                .padding(.vertical, compact ? 6 : 7)
                                .background(
                                    isSelected
                                        ? OuraTheme.Colors.accent
                                        : OuraTheme.Colors.surfaceSheet
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(
                                        isSelected ? Color.clear : OuraTheme.Colors.border,
                                        lineWidth: 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: selected)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}
