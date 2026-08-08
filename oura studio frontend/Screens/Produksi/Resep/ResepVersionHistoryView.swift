import SwiftUI

struct ResepVersionHistoryView: View {
    @EnvironmentObject private var api: APIService

    let productSizeId: UUID
    let productName: String
    let sizeLabel: String

    @State private var specs: [PatternSpec] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(OuraTheme.Colors.background)
            } else if specs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 36))
                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                    Text("Belum ada riwayat versi")
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OuraTheme.Colors.background)
            } else {
                List {
                    ForEach(specs.sorted { $0.effectiveFrom > $1.effectiveFrom }) { spec in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(spec.effectiveFrom.formatted(.dateTime.day().month().year()))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                                Spacer()
                                if spec.isActive {
                                    OuraTag(text: "Aktif", color: OuraTheme.Colors.greenAccent, bg: OuraTheme.Colors.greenBg)
                                } else if let to = spec.effectiveTo {
                                    Text("Berakhir \(to.formatted(.dateTime.day().month().year()))")
                                        .font(.system(size: 11))
                                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                                }
                            }

                            HStack(spacing: 16) {
                                specBadge(icon: "ruler", label: String(format: "%.0f×%.0f cm", spec.cutLengthCm, spec.cutWidthCm))
                                specBadge(icon: "clock", label: String(format: "%.0f min", spec.estLaborMinutes))
                                specBadge(icon: "hammer", label: "\(spec.usedInBatchCount)× dipakai")
                            }

                            Text(spec.fabricMaterialName)
                                .font(.system(size: 12))
                                .foregroundStyle(OuraTheme.Colors.textSecondary)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                        .listRowSeparatorTint(OuraTheme.Colors.separator)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(OuraTheme.Colors.background)
            }
        }
        .navigationTitle("Riwayat · \(sizeLabel)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func specBadge(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(OuraTheme.Colors.textSecondary)
    }

    private func load() async {
        isLoading = true
        specs = (try? await api.getPatternSpecs(productId: nil, size: nil, fabricMaterialId: nil))?.filter {
            $0.productSizeId == productSizeId
        } ?? []
        isLoading = false
    }
}
