import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            BerandaView()
                .tabItem { Label("Beranda",  systemImage: "house") }
                .tag(0)

            ProduksiTabView()
                .tabItem { Label("Produksi", systemImage: "square.3.layers.3d.down.right") }
                .tag(1)

            NavigationStack {
                ProdukListView()
            }
            .tabItem { Label("Produk",    systemImage: "tag") }
            .tag(2)

            NavigationStack {
                PenjualanListView()
            }
            .tabItem { Label("Penjualan", systemImage: "cart") }
            .tag(3)

            NavigationStack {
                LainnyaView()
            }
            .tabItem { Label("Lainnya",   systemImage: "square.grid.2x2") }
            .tag(4)
        }
        .tint(OuraTheme.Colors.accent)
        .onAppear { applyTabBarAppearance() }
    }

    private func applyTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.929, green: 0.902, blue: 0.882, alpha: 1.0) // warm beige #EDE6E1

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
