import SwiftUI

struct ResepListView: View {
    @EnvironmentObject private var api: APIService

    @State private var specs: [PatternSpec] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var searchText: String = ""
    @State private var showTambah = false

    private var grouped: [(product: String, specs: [PatternSpec])] {
        let filtered = searchText.isEmpty
            ? specs.filter { $0.isActive }
            : specs.filter { $0.isActive && (
                $0.productName.localizedCaseInsensitiveContains(searchText) ||
                $0.sizeLabel.localizedCaseInsensitiveContains(searchText) ||
                $0.fabricMaterialName.localizedCaseInsensitiveContains(searchText)
            )}

        let dict = Dictionary(grouping: filtered, by: { $0.productName })
        return dict.sorted { $0.key < $1.key }
               .map { (product: $0.key, specs: $0.value.sorted { $0.sizeLabel < $1.sizeLabel }) }
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            searchField
                .padding(.horizontal, OuraTheme.Spacing.horizontal)
                .padding(.bottom, 6)

            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMsg {
                    errorView(err)
                } else if grouped.isEmpty {
                    emptyView
                } else {
                    specList
                }
            }
        }
        .background(OuraTheme.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .sheet(isPresented: $showTambah, onDismiss: { Task { await load() } }) {
            TambahResepSheet()
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .center) {
            Text("Resep")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
            Spacer()
            Button { showTambah = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.accent)
                    .frame(width: 32, height: 32)
                    .background(OuraTheme.Colors.accentLight)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tambah Resep")
        }
        .padding(.horizontal, OuraTheme.Spacing.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .font(.system(size: 14))
            TextField("Cari resep pola...", text: $searchText)
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(OuraTheme.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                .stroke(OuraTheme.Colors.border, lineWidth: 0.75)
        )
    }

    private var specList: some View {
        List {
            ForEach(grouped, id: \.product) { group in
                Section {
                    ForEach(group.specs) { spec in
                        NavigationLink(destination: ResepEditorView(spec: spec, onUpdate: { Task { await load() } })) {
                            ResepRow(spec: spec)
                        }
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .listRowSeparatorTint(OuraTheme.Colors.separator)
                    }
                } header: {
                    Text(group.product)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .textCase(.none)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(OuraTheme.Colors.background)
        .refreshable { await load() }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
            Text(searchText.isEmpty ? "Belum ada resep pola" : "Resep tidak ditemukan")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            if searchText.isEmpty {
                Text("Buat resep pola pertama untuk produk Anda")
                    .font(.system(size: 13))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(OuraTheme.Colors.dangerText)
            Text("Gagal memuat resep")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Text(message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Coba Lagi") { Task { await load() } }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        isLoading = true
        errorMsg = nil
        do {
            specs = try await api.getPatternSpecs()
        } catch {
            errorMsg = error.localizedDescription
            specs = []
        }
        isLoading = false
    }
}

// MARK: - Row

private struct ResepRow: View {
    let spec: PatternSpec

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(spec.sizeLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    OuraTag(text: String(format: "%.0f×%.0f cm", spec.cutLengthCm, spec.cutWidthCm))
                }
                Text(spec.fabricMaterialName)
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(spec.estLaborMinutes, specifier: "%.0f") min")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                if spec.usedInBatchCount > 0 {
                    Text("\(spec.usedInBatchCount)× dipakai")
                        .font(.system(size: 11))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                }
            }
        }
    }
}
