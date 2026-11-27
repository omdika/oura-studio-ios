import SwiftUI
import Vision
import VisionKit

/// Reusable UIViewControllerRepresentable wrapping Apple DataScannerViewController.
/// Extracted from QRScannerSheet so it can be shared with StokOpnameScannerView etc.
struct DataScannerRepresentable: UIViewControllerRepresentable {
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
