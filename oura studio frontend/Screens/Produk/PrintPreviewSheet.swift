import SwiftUI
import CoreBluetooth
import CoreImage.CIFilterBuiltins

struct PrintPreviewSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tsplPrinterService: TSPLPrinterService

    let productName: String
    let sizes: [ProductSizeDetail]

    @AppStorage("labelWidth") private var labelWidth: Double = 33.0
    @AppStorage("labelHeight") private var labelHeight: Double = 15.0
    @AppStorage("labelGap") private var labelGap: Double = 2.0
    @AppStorage("printerName") private var printerName: String = ""

    @State private var selectedSizeId: UUID?
    @State private var quantity: Int = 1
    @State private var errorMsg: String?
    @State private var isShowingPrinterSelection = false

    private var selectedSize: ProductSizeDetail? {
        sizes.first(where: { $0.id == selectedSizeId })
    }

    init(productName: String, sizes: [ProductSizeDetail]) {
        self.productName = productName
        self.sizes = sizes.filter { !$0.isArchived }
        let activeSizes = sizes.filter { !$0.isArchived }
        self._selectedSizeId = State(initialValue: activeSizes.first?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Preview Label (33x15mm)")) {
                    if let size = selectedSize {
                        ThermalLabelPreviewCard(size: size, qrImage: makeQRImage(for: size.id))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    } else {
                        Text("Silakan pilih varian ukuran terlebih dahulu.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
                
                Section(header: Text("Pilih Ukuran & Varian")) {
                    Picker("Varian", selection: $selectedSizeId) {
                        Text("Pilih varian...").tag(nil as UUID?)
                        ForEach(sizes) { size in
                            Text(size.displayLabel).tag(size.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(header: Text("Koneksi Printer Bluetooth")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tsplPrinterService.connectedPeripheral?.name ?? "Tidak Terhubung")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(tsplPrinterService.connectedPeripheral != nil ? OuraTheme.Colors.greenAccent : OuraTheme.Colors.textTertiary)
                            Text(tsplPrinterService.connectionStatus)
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        Button {
                            isShowingPrinterSelection = true
                        } label: {
                            Text(tsplPrinterService.connectedPeripheral != nil ? "Ubah Printer" : "Pilih Printer")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(OuraTheme.Colors.accentLight)
                                .foregroundColor(OuraTheme.Colors.accent)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if tsplPrinterService.connectedPeripheral == nil {
                        Text("Silakan hubungkan printer thermal Anda terlebih dahulu untuk mencetak.")
                            .font(.system(size: 11))
                            .foregroundStyle(OuraTheme.Colors.warningText)
                    }
                }

                Section(header: Text("Konfigurasi Label (Pengaturan)")) {
                    HStack {
                        Text("Lebar Label").foregroundStyle(.gray)
                        Spacer()
                        Text("\(labelWidth, specifier: "%.1f") mm")
                    }
                    HStack {
                        Text("Tinggi Label").foregroundStyle(.gray)
                        Spacer()
                        Text("\(labelHeight, specifier: "%.1f") mm")
                    }
                    HStack {
                        Text("Jarak Label (Gap)").foregroundStyle(.gray)
                        Spacer()
                        Text("\(labelGap, specifier: "%.1f") mm")
                    }
                }

                Section(header: Text("Jumlah Cetak")) {
                    Stepper(value: $quantity, in: 1...100) {
                        Text("Jumlah: \(quantity) label")
                            .font(.system(size: 14, weight: .medium))
                    }
                }

                if let err = errorMsg {
                    Section {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.dangerText)
                    }
                    .listRowBackground(OuraTheme.Colors.dangerBg)
                }
            }
            .navigationTitle("Cetak Label QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cetak") {
                        printLabels()
                    }
                    .disabled(tsplPrinterService.connectedPeripheral == nil || tsplPrinterService.writableCharacteristic == nil || selectedSizeId == nil || quantity <= 0)
                    .foregroundStyle(tsplPrinterService.connectedPeripheral != nil && selectedSizeId != nil ? OuraTheme.Colors.accent : OuraTheme.Colors.textDisabled)
                }
            }
            .sheet(isPresented: $isShowingPrinterSelection) {
                PrinterSelectionView()
                    .environmentObject(tsplPrinterService)
            }
        }
    }

    private func makeQRImage(for sizeId: UUID) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("oura:\(sizeId.uuidString)".utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImg)
    }

    private func printLabels() {
        errorMsg = nil
        guard let size = selectedSize else {
            errorMsg = "Pilih varian ukuran terlebih dahulu."
            return
        }
        guard tsplPrinterService.connectedPeripheral != nil, tsplPrinterService.writableCharacteristic != nil else {
            errorMsg = "Printer tidak terhubung atau karakteristik tulis tidak ditemukan."
            return
        }

        tsplPrinterService.printLabel(
            qrData: "oura:\(size.id.uuidString)",
            caption: TSPLPrinterService.labelCaption(
                productSku: size.productSku,
                productName: size.productName,
                sizeLabel: size.sizeLabel,
                fabricVariantName: size.fabricVariantName
            ),
            width: labelWidth,
            height: labelHeight,
            gap: labelGap,
            quantity: quantity
        )
        dismiss()
    }
}

// MARK: - Visual Preview Card for 33x15mm Thermal Label
struct ThermalLabelPreviewCard: View {
    let size: ProductSizeDetail
    let qrImage: UIImage?

    /// Font caption mengecil otomatis mengikuti panjang caption (mirip fallback font TSPL).
    private var captionFontSize: CGFloat {
        let len = TSPLPrinterService.labelCaption(
            productSku: size.productSku,
            productName: size.productName,
            sizeLabel: size.sizeLabel,
            fabricVariantName: size.fabricVariantName
        ).count
        if len > 40 { return 8.5 }
        if len > 28 { return 9.5 }
        return 11
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left: QR Code
            if let img = qrImage {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: "qrcode").foregroundColor(.gray))
            }

            // Right: Caption gaya A4 persis seperti hasil cetak thermal
            // ("SKU - Nama - Size - Varian"), font mengecil otomatis bila panjang.
            VStack(alignment: .leading, spacing: 2) {
                Text(TSPLPrinterService.labelCaption(
                    productSku: size.productSku,
                    productName: size.productName,
                    sizeLabel: size.sizeLabel,
                    fabricVariantName: size.fabricVariantName
                ))
                    .font(.system(size: captionFontSize, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(10)
        .background(OuraTheme.Colors.surfaceSheet)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(OuraTheme.Colors.border, lineWidth: 1)
        )
    }
}
