import SwiftUI
import VisionKit
import Vision

// MARK: - Scan Mode

enum QRScanMode {
    case any
    case sellOnly
    case stockInOnly
}

// MARK: - Scan State

private enum ScanState: Equatable {
    case scanning
    case resolving
    case resolved(ProductSizeDetail)
    case error(String)

    static func == (lhs: ScanState, rhs: ScanState) -> Bool {
        switch (lhs, rhs) {
        case (.scanning, .scanning):       return true
        case (.resolving, .resolving):     return true
        case (.error(let a), .error(let b)): return a == b
        case (.resolved(let a), .resolved(let b)): return a.id == b.id
        default: return false
        }
    }
}

// MARK: - Sheet

struct QRScannerSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    let mode: QRScanMode

    @State private var scanState: ScanState = .scanning
    @State private var showSellSheet = false
    @State private var showStockSheet = false
    @State private var resolvedSize: ProductSizeDetail? = nil

    private var isScanning: Bool { scanState == .scanning }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable(isActive: isScanning, onScan: handleRawScan)
                        .ignoresSafeArea()
                } else {
                    unsupportedView
                }

                bottomOverlay
                    .animation(.easeInOut(duration: 0.25), value: scanState)
            }
            .navigationTitle("Scan QR Produk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
        }
        .sheet(isPresented: $showSellSheet, onDismiss: {
            if scanState != .scanning { scanState = .scanning }
        }) {
            if let size = resolvedSize {
                ScanToSellSheet(size: size, dismissParent: { dismiss() })
                    .environmentObject(api)
            }
        }
        .sheet(isPresented: $showStockSheet, onDismiss: {
            if scanState != .scanning { scanState = .scanning }
        }) {
            if let size = resolvedSize {
                ScanToStockSheet(size: size, dismissParent: { dismiss() })
                    .environmentObject(api)
            }
        }
    }

    // MARK: - Bottom overlay

    @ViewBuilder
    private var bottomOverlay: some View {
        switch scanState {
        case .scanning:
            scanHint
        case .resolving:
            resolvingCard
        case .resolved(let size):
            resolvedCard(size)
        case .error(let msg):
            errorCard(msg)
        }
    }

    private var scanHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 18))
                .foregroundStyle(OuraTheme.Colors.accent)
            Text("Arahkan kamera ke QR code produk")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
        .padding(.bottom, 44)
    }

    private var resolvingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Mencari produk...")
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(OuraTheme.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
        .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.large)
            .stroke(OuraTheme.Colors.border, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 44)
    }

    private func resolvedCard(_ size: ProductSizeDetail) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(OuraTheme.Colors.border)
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(size.productName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Text(size.displayLabel)
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    HStack(spacing: 16) {
                        Label("Stok: \(size.currentStockQty) pcs", systemImage: "cube.box")
                        if let price = size.sellingPrice {
                            Label(price.rupiahFormatted, systemImage: "tag")
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                }

                if size.isArchived {
                    Text("Varian ini sudah dinonaktifkan.")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.dangerText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OuraTheme.Colors.dangerBg)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                }

                if !size.isArchived {
                    VStack(spacing: 10) {
                        if mode != .stockInOnly {
                            Button {
                                resolvedSize = size
                                showSellSheet = true
                            } label: {
                                Text(size.currentStockQty > 0 ? "Catat Penjualan" : "Stok Habis")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(size.currentStockQty > 0
                                        ? OuraTheme.Colors.accentGradient
                                        : LinearGradient(colors: [OuraTheme.Colors.textDisabled],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                            }
                            .buttonStyle(.plain)
                            .disabled(size.currentStockQty == 0)
                        }

                        if mode != .sellOnly {
                            Button {
                                resolvedSize = size
                                showStockSheet = true
                            } label: {
                                Text("Stok Masuk")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.accent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(OuraTheme.Colors.surfaceSheet)
                                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                                    .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.large)
                                        .stroke(OuraTheme.Colors.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button { scanState = .scanning } label: {
                    Text("Scan Lagi")
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(OuraTheme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, y: -4)
    }

    private func errorCard(_ msg: String) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(OuraTheme.Colors.border)
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(OuraTheme.Colors.dangerText)
                    Text(msg)
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Spacer()
                }
                .padding(12)
                .background(OuraTheme.Colors.dangerBg)
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))

                Button { scanState = .scanning } label: {
                    Text("Scan Lagi")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(OuraTheme.Colors.surfaceSheet)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                        .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.large)
                            .stroke(OuraTheme.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(OuraTheme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, y: -4)
    }

    private var unsupportedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash")
                .font(.system(size: 48))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
            Text("Kamera tidak tersedia")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
            Text("Fitur scan membutuhkan iOS 16+ dan izin kamera.")
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OuraTheme.Colors.background)
    }

    // MARK: - Logic

    private func handleRawScan(_ raw: String) {
        guard raw.hasPrefix("oura:"),
              let uuid = UUID(uuidString: String(raw.dropFirst(5))),
              scanState == .scanning else { return }
        scanState = .resolving
        Task { await resolve(uuid) }
    }

    private func resolve(_ id: UUID) async {
        do {
            let size = try await api.getProductSizeById(id: id)
            scanState = .resolved(size)
        } catch {
            scanState = .error("Produk tidak ditemukan. QR mungkin sudah tidak aktif.")
        }
    }
}

// MARK: - DataScanner wrapper

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let isActive: Bool
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isActive {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var lastScanned: String?

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard case .barcode(let barcode) = addedItems.first,
                  let raw = barcode.payloadStringValue,
                  raw != lastScanned else { return }
            lastScanned = raw
            onScan(raw)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.lastScanned = nil
            }
        }
    }
}
