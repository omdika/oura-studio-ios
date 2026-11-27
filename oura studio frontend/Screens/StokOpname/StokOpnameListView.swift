import SwiftUI

/// Layar daftar sesi stok opname. Entry point dari tab Lainnya.
struct StokOpnameListView: View {
    @EnvironmentObject private var api: APIService
    @State private var sessions: [StockOpnameSession] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var showingNewSession = false

    var body: some View {
        Group {
            if isLoading && sessions.isEmpty {
                ProgressView("Memuat…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 48))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                    Text("Belum ada sesi stok opname")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Text("Mulai sesi baru untuk menghitung stok fisik produk dengan scan QR.")
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Buat Opname Baru") {
                        showingNewSession = true
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(OuraTheme.Colors.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OuraTheme.Colors.background)
            } else {
                List {
                    ForEach(sessions) { session in
                        NavigationLink(value: session) {
                            sessionRow(session)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(OuraTheme.Colors.background)
            }
        }
        .navigationTitle("Stok Opname")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewSession = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
        }
        .navigationDestination(for: StockOpnameSession.self) { session in
            if session.status == "completed" {
                StokOpnameResultView(session: session)
                    .environmentObject(api)
            } else {
                StokOpnameScannerView(session: session)
                    .environmentObject(api)
            }
        }
        .refreshable {
            await loadSessions()
        }
        .task {
            await loadSessions()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stockOpnameDidCreateSession)) { _ in
            Task {
                await loadSessions()
            }
        }
        .onAppear {
            Task {
                await loadSessions()
            }
        }
        .alert("Error", isPresented: .constant(errorMsg != nil)) {
            Button("OK") { errorMsg = nil }
        } message: {
            Text(errorMsg ?? "")
        }
        .sheet(isPresented: $showingNewSession) {
            StokOpnameNewSessionSheet()
                .environmentObject(api)
        }
    }

    private func sessionRow(_ session: StockOpnameSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.statusLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(session.statusBadgeColor)
                    .clipShape(Capsule())
                Spacer()
                Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
            }
            Text("\(session.itemCount) item • \(String(format: "%.0f", session.totalVarianceValue)) Rp variansi")
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
            if let note = session.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await api.getStockOpnameSessions()
            await MainActor.run {
                sessions = resp.data
            }
        } catch {
            await MainActor.run {
                if let apiErr = error as? APIError {
                    errorMsg = apiErr.errorDescription
                } else {
                    errorMsg = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - New Session Sheet

struct StokOpnameNewSessionSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss
    @State private var note: String = ""
    @State private var isSaving = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Catatan opname (opsional)", text: $note)
                        .font(.system(size: 14))
                } header: {
                    OuraSectionHeader(title: "Sesi Baru")
                }
            }
            .scrollContentBackground(.hidden)
            .background(OuraTheme.Colors.background)
            .navigationTitle("Buat Sesi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        Task { await save() }
                    }
                    .foregroundStyle(OuraTheme.Colors.accent)
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: .constant(errorMsg != nil)) {
                Button("OK") { errorMsg = nil }
            } message: {
                Text(errorMsg ?? "")
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let session = try await api.createStockOpnameSession(note: note.isEmpty ? nil : note)
            await MainActor.run {
                dismiss()
            }
            // Navigasi ke scanner akan ditangani oleh parent melalui notification atau state
            // Untuk sekarang, dismiss sheet dan biarkan parent refresh
            NotificationCenter.default.post(name: .stockOpnameDidCreateSession, object: session.id)
        } catch {
            await MainActor.run {
                if let apiErr = error as? APIError {
                    errorMsg = apiErr.errorDescription
                } else {
                    errorMsg = error.localizedDescription
                }
            }
        }
    }
}

extension Notification.Name {
    static let stockOpnameDidCreateSession = Notification.Name("stockOpnameDidCreateSession")
}

// MARK: - Color helper (model-agnostic)

extension StockOpnameSession {
    var statusBadgeColor: Color {
        switch status {
        case "completed": return .green
        case "cancelled": return .red
        case "in_progress": return .blue
        default: return .gray
        }
    }
}
