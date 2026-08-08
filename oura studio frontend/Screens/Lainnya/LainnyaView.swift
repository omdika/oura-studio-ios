import SwiftUI

struct LainnyaView: View {
    @EnvironmentObject private var appState: AppState

    enum SegmentTab: Int, CaseIterable {
        case laporan, pengaturan
        var title: String { self == .laporan ? "Laporan" : "Pengaturan" }
    }

    @State private var selectedTab: SegmentTab = .laporan
    @State private var showLogoutAlert = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(SegmentTab.allCases, id: \.rawValue) {
                    Text($0.title).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, OuraTheme.Spacing.horizontal)
            .padding(.vertical, 10)
            .background(OuraTheme.Colors.background)

            Group {
                if selectedTab == .laporan {
                    ReportsView()
                } else {
                    SettingsView()
                }
            }
            .animation(.none, value: selectedTab)
        }
        .background(OuraTheme.Colors.background)
        .navigationTitle("Lainnya")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showLogoutAlert = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(OuraTheme.Colors.dangerText)
                }
            }
        }
        .alert("Keluar dari aplikasi?", isPresented: $showLogoutAlert) {
            Button("Keluar", role: .destructive) { appState.logout() }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Anda akan keluar dari sesi ini.")
        }
    }
}
