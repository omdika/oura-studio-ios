
import Foundation
import CoreBluetooth
import Combine

class TSPLPrinterService: NSObject, ObservableObject {
    @Published var centralManager: CBCentralManager!
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    var writableCharacteristic: CBCharacteristic?
    @Published var connectionStatus: String = "Disconnected"

    private var autoConnectUUIDString: String? {
        UserDefaults.standard.string(forKey: "printerUUIDString")
    }

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func attemptAutoConnect() {
        guard centralManager.state == .poweredOn else { return }
        guard let uuidString = autoConnectUUIDString, !uuidString.isEmpty,
              let uuid = UUID(uuidString: uuidString) else {
            print("No saved printer UUID for auto-connect.")
            return
        }
        
        connectionStatus = "Auto-reconnecting..."
        print("Attempting auto-connect to saved printer UUID: \(uuidString)")
        
        let retrieved = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = retrieved.first {
            print("Found saved peripheral in retrieved list, connecting...")
            connect(to: peripheral)
        } else {
            print("Saved peripheral not found in retrieved list. Scanning for nearby peripherals...")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    func startScanningForPeripherals() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth is not powered on.")
            return
        }
        discoveredPeripherals.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        connectionStatus = "Scanning..."
        print("Started scanning for peripherals...")
    }

    func stopScanningForPeripherals() {
        centralManager.stopScan()
        if connectedPeripheral == nil {
            connectionStatus = "Disconnected"
        }
        print("Stopped scanning for peripherals.")
    }

    func connect(to peripheral: CBPeripheral) {
        centralManager.stopScan()
        connectedPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
        connectionStatus = "Connecting to \(peripheral.name ?? "Unknown Device")..."
        print("Attempting to connect to \(peripheral.name ?? "Unknown Device")...")
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        writableCharacteristic = nil
        connectionStatus = "Disconnected"
        print("Disconnected from peripheral.")
    }

    func printReceipt(order: SalesOrder) {
        guard let peripheral = connectedPeripheral, let characteristic = writableCharacteristic else {
            print("Printer not connected or writable characteristic not found.")
            connectionStatus = "Printer tidak terhubung"
            attemptAutoConnect()
            return
        }

        connectionStatus = "Mencetak..."

        let tsplCommands = ReceiptGenerator.generateTSPL(order: order)
        print("Generated TSPL Commands:\n\(tsplCommands)")

        guard let data = tsplCommands.data(using: .ascii) else {
            connectionStatus = "Gagal memproses data"
            return
        }

        let chunkSize = peripheral.maximumWriteValueLength(for: .withoutResponse)
        var offset = 0

        while offset < data.count {
            let chunk = data.subdata(in: offset..<min(offset + chunkSize, data.count))
            peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)
            offset += chunkSize
        }
        connectionStatus = "Struk dicetak"
    }

    func printLabel(qrData: String, width: Double, height: Double, gap: Double, quantity: Int) {
        guard let peripheral = connectedPeripheral, let characteristic = writableCharacteristic else {
            print("Printer not connected or writable characteristic not found.")
            connectionStatus = "Print Error: Not connected or no writable characteristic"
            return
        }

        connectionStatus = "Printing..."

        var tsplCommands = ""

        // Setup commands
        tsplCommands += "SIZE \(width) mm,\\(height) mm\\r\\n"
        tsplCommands += "GAP \(gap) mm,0 mm\\r\\n"
        tsplCommands += "CLS\\r\\n" // Clear buffer
        tsplCommands += "DIRECTION 1\\r\\n" // Print direction (configurable if needed)
        tsplCommands += "REFERENCE 0,0\\r\\n" // Origin point (configurable if needed)
        tsplCommands += "SET TEAR ON\\r\\n" // Enable tear-off mode

        // QR Code command - positions need to be calculated based on label size
        // For 33x15mm, a reasonable cell_width might be 2 or 3.
        // Assuming QR code should be roughly centered
        let qrX = Int(width * 8 / 2) - 20 // Example: center horizontally, adjust as needed
        let qrY = Int(height * 8 / 2) - 20 // Example: center vertically, adjust as needed
        let cellWidth = 3 // Adjust for desired QR code size
        tsplCommands += "QRCODE \\(qrX),\\(qrY),L,\\(cellWidth),A,0,M,20,\"\\(qrData)\"\\r\\n"

        // Print command
        tsplCommands += "PRINT \\(quantity),1\\r\\n"

        print("Generated TSPL Commands:\\n\\(tsplCommands)")

        // Send commands in chunks if necessary
        let data = tsplCommands.data(using: .ascii)!
        let chunkSize = peripheral.maximumWriteValueLength(for: .withoutResponse) // Use .withResponse if needed, but .withoutResponse is common for printers
        var offset = 0

        while offset < data.count {
            let chunk = data.subdata(in: offset..<min(offset + chunkSize, data.count))
            peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)
            offset += chunkSize
            // Add a small delay between chunks if the printer struggles with rapid writes
            // Thread.sleep(forTimeInterval: 0.01)
        }
        connectionStatus = "Print command sent"
    }

}

// MARK: - CBCentralManagerDelegate
extension TSPLPrinterService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on.")
            connectionStatus = "Ready to scan"
            attemptAutoConnect()
        case .poweredOff:
            print("Bluetooth is powered off.")
            connectionStatus = "Bluetooth Off"
            discoveredPeripherals.removeAll()
            connectedPeripheral = nil
            writableCharacteristic = nil
        case .resetting:
            print("Bluetooth is resetting.")
            connectionStatus = "Resetting"
        case .unauthorized:
            print("Bluetooth is unauthorized.")
            connectionStatus = "Unauthorized"
        case .unknown:
            print("Bluetooth state is unknown.")
            connectionStatus = "Unknown State"
        case .unsupported:
            print("Bluetooth is unsupported on this device.")
            connectionStatus = "Unsupported"
        @unknown default:
            print("A new Bluetooth state was added that is not yet handled.")
            connectionStatus = "Unknown New State"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
            print("Discovered peripheral: \(peripheral.name ?? "Unknown"), RSSI: \(RSSI)")
        }

        // Auto-connect if we found our saved printer
        if let uuidString = autoConnectUUIDString,
           peripheral.identifier.uuidString == uuidString {
            print("Discovered saved printer in scan, auto-connecting...")
            connect(to: peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown Device").")
        connectionStatus = "Connected to \(peripheral.name ?? "Unknown Device")"
        peripheral.delegate = self
        peripheral.discoverServices(nil) // Discover all services
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "Unknown Device"). Error: \(error?.localizedDescription ?? "Unknown error")")
        connectionStatus = "Failed to connect"
        connectedPeripheral = nil
        writableCharacteristic = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown Device"). Error: \(error?.localizedDescription ?? "No error")")
        connectionStatus = "Disconnected"
        connectedPeripheral = nil
        writableCharacteristic = nil
        
        // If it was an unexpected disconnection, we can attempt to auto-reconnect
        if error != nil {
            print("Unexpected disconnection. Attempting auto-reconnect...")
            attemptAutoConnect()
        }
    }
}

// MARK: - CBPeripheralDelegate
extension TSPLPrinterService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        guard let services = peripheral.services else { return }
        for service in services {
            print("Discovered service: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics for service \(service.uuid): \(error.localizedDescription)")
            return
        }
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            print("Discovered characteristic for service \(service.uuid): \(characteristic.uuid), properties: \(characteristic.properties)")
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                writableCharacteristic = characteristic
                print("Identified writable characteristic: \(characteristic.uuid)")
                // Break after finding the first writable characteristic, or refine logic if multiple are possible
                // For simplicity, we assume one primary write characteristic for printing
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        // Handle incoming data if this is a notify/read characteristic
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        print("Successfully wrote value to characteristic \(characteristic.uuid)")
    }
}
