import SwiftUI
import CoreBluetooth

struct PrinterSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tsplPrinterService: TSPLPrinterService

    @AppStorage("printerUUIDString") private var printerUUIDString: String = ""
    @AppStorage("printerName") private var printerName: String = ""

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Status Bluetooth")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tsplPrinterService.connectionStatus)
                        // Bedakan "connect" vs "siap cetak": service-discovery
                        // BLE butuh waktu setelah connect sebelum karakteristik
                        // tulis ditemukan. Sheet baru tutup saat siap cetak.
                        if tsplPrinterService.connectedPeripheral != nil && !tsplPrinterService.isPrinterReady {
                            Text("Menghubungkan layanan printer...")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Section(header: Text("Perangkat Ditemukan")) {
                    if tsplPrinterService.discoveredPeripherals.isEmpty {
                        Text("Tidak ada printer ditemukan. Pastikan Bluetooth printer Anda aktif dan dalam mode pairing.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(tsplPrinterService.discoveredPeripherals, id: \.identifier) { peripheral in
                            Button {
                                tsplPrinterService.connect(to: peripheral)
                            } label: {
                                HStack {
                                    Text(peripheral.name ?? "Unknown Device")
                                    Spacer()
                                    if tsplPrinterService.connectedPeripheral?.identifier == peripheral.identifier {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Pilih Printer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batalkan") {
                        tsplPrinterService.stopScanningForPeripherals()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if tsplPrinterService.centralManager.isScanning {
                            tsplPrinterService.stopScanningForPeripherals()
                        } else {
                            tsplPrinterService.startScanningForPeripherals()
                        }
                    }) {
                        Image(systemName: tsplPrinterService.centralManager.isScanning ? "stop.circle.fill" : "arrow.clockwise.circle.fill")
                    }
                }
            }
            .onAppear {
                tsplPrinterService.startScanningForPeripherals()
            }
            .onDisappear {
                tsplPrinterService.stopScanningForPeripherals()
            }
            .onChange(of: tsplPrinterService.connectedPeripheral) { newPeripheral in
                // Simpan pilihan segera, tapi JANGAN dismiss di sini:
                // service/characteristic discovery belum selesai sehingga
                // writableCharacteristic masih nil (cetak pertama gagal).
                if let peripheral = newPeripheral {
                    printerUUIDString = peripheral.identifier.uuidString
                    printerName = peripheral.name ?? "Unknown Device"
                }
            }
            .onChange(of: tsplPrinterService.isPrinterReady) { ready in
                // Tutup hanya setelah karakteristik tulis valid ditemukan —
                // pola yang membuat label QR selalu sukses dicetak berulang.
                if ready && tsplPrinterService.connectedPeripheral != nil {
                    dismiss()
                }
            }
        }
    }
}
