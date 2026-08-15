import SwiftUI

// MARK: - Shared mock top bar components

private struct TopBarCurrent: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())
            Text("Scrunchie Katun · XS")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Simpan Perubahan") {}
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

private struct TopBarOptionA: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())
            Text("Scrunchie Katun · XS")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Simpan Perubahan") {}
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.accentColor)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

private struct TopBarOptionB: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())
            Text("Scrunchie Katun · XS")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Batalkan") {}
                .font(.system(size: 14))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

private struct MockFormContent: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(["benang all color per unit (pcs)", "label kain per unit (pcs)", "label kertas per unit (pcs)", "plastik packing besar per unit (pcs)"], id: \.self) { label in
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.secondaryLabel))
                    HStack {
                        Text("1")
                            .font(.system(size: 15))
                        Spacer()
                        Text("pcs")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
    }
}

// MARK: - Preview A: Capsule button di top bar

private struct OptionAView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OPSI A — Capsule di top bar")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            Divider()
            TopBarOptionA()
            Divider().opacity(0.4)
            MockFormContent()
            Spacer()
            // Bottom: hapus jadi teks plain
            Button("Hapus Resep Ini") {}
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.red)
                .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Preview B: Sticky bottom button

private struct OptionBView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OPSI B — Sticky bottom button (rekomendasi)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            Divider()
            TopBarOptionB()
            Divider().opacity(0.4)
            MockFormContent()
            Spacer()
            // Hapus jadi teks plain
            Button("Hapus Resep Ini") {}
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.red)
                .padding(.vertical, 12)
            // Sticky bottom save
            Divider().opacity(0.4)
            Button("Simpan Perubahan") {}
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Preview Current (referensi)

private struct CurrentView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SEKARANG (referensi)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            Divider()
            TopBarCurrent()
            Divider().opacity(0.4)
            MockFormContent()
            Spacer()
            // Hapus masih full button merah
            HStack {
                Spacer()
                Text("Hapus Resep Ini")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.red)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Previews

#Preview("Sekarang") {
    CurrentView()
        .frame(width: 390, height: 650)
}

#Preview("Opsi A — Capsule") {
    OptionAView()
        .frame(width: 390, height: 650)
}

#Preview("Opsi B — Sticky Bottom") {
    OptionBView()
        .frame(width: 390, height: 650)
}
