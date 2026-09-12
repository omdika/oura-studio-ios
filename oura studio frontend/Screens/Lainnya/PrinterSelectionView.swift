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
                    Text(tsplPrinterService.connectionStatus)
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
                if let peripheral = newPeripheral {
                    printerUUIDString = peripheral.identifier.uuidString
                    printerName = peripheral.name ?? "Unknown Device"
                    dismiss()
                }
            }
        }
    }
}
