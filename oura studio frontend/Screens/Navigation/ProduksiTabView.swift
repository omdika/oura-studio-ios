import SwiftUI

private enum ProduksiTab: Int, CaseIterable {
    case bahan, resep, optimasi, produksi

    var title: String {
        switch self {
        case .bahan:    return "Bahan"
        case .resep:    return "Resep"
        case .optimasi: return "Optimasi"
        case .produksi: return "Produksi"
        }
    }
}

struct ProduksiTabView: View {
    @EnvironmentObject private var appState: AppState

    private var selected: ProduksiTab {
        ProduksiTab(rawValue: appState.produksiSubTabIndex) ?? .bahan
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Produksi")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, OuraTheme.Spacing.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .background(OuraTheme.Colors.background)

            segmentPicker
                .padding(.horizontal, OuraTheme.Spacing.horizontal)
                .padding(.bottom, 10)
                .background(OuraTheme.Colors.background)

            Divider()
                .overlay(OuraTheme.Colors.separator)

            ZStack {
                switch selected {
                case .bahan:
                    NavigationStack { BahanListView() }
                case .resep:
                    NavigationStack { ResepListView() }
                case .optimasi:
                    NavigationStack { OptimasiView(onLayoutSaved: { appState.produksiSubTabIndex = ProduksiTab.produksi.rawValue }) }
                case .produksi:
                    NavigationStack { ProduksiBatchView() }
                }
            }
            .animation(.none, value: selected)
        }
        .background(OuraTheme.Colors.background)
    }

    private var segmentPicker: some View {
        HStack(spacing: 6) {
            ForEach(ProduksiTab.allCases, id: \.rawValue) { tab in
                Button {
                    appState.produksiSubTabIndex = tab.rawValue
                } label: {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected == tab ? .white : OuraTheme.Colors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selected == tab ? OuraTheme.Colors.accent : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.18), value: selected)
                .accessibilityLabel(tab.title)
                .accessibilityIdentifier("subtab-\(tab.title.lowercased())")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
