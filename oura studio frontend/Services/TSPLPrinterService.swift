
import Foundation
import CoreBluetooth
import Combine

// Standard TSPL Printer Service UUIDs (common across most BLE thermal printers)
let TSPL_SERVICE_UUIDS: [CBUUID] = [
    CBUUID(string: "FFE0"),        // Generic UART service (many printers use this)
    CBUUID(string: "0000180A-0000-1000-8000-00805F9B34FB"), // Device Information Service
]

let TSPL_CHARACTERISTIC_UUIDS: [CBUUID] = [
    CBUUID(string: "FFE1"),        // Generic UART RX/TX (most common)
    CBUUID(string: "2A29"),        // Manufacturer Name String
]

class TSPLPrinterService: NSObject, ObservableObject {
    @Published var centralManager: CBCentralManager!
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var bluetoothState: CBManagerState = .unknown
    var writableCharacteristic: CBCharacteristic?
    @Published var connectionStatus: String = "Initializing..."
    @Published var isScanning: Bool = false

    private var autoConnectUUIDString: String? {
        UserDefaults.standard.string(forKey: "printerUUIDString")
    }
    
    // Scanning timeout timer
    private var scanningTimeoutTimer: Timer?
    private let SCAN_TIMEOUT_INTERVAL: TimeInterval = 15.0 // 15 seconds

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    deinit {
        stopScanningForPeripherals()
    }

    func attemptAutoConnect() {
        guard bluetoothState == .poweredOn else { 
            print("Bluetooth not ready for auto-connect. State: \(bluetoothState)")
            return 
        }
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
            startScanningForPeripherals()
        }
    }

    func startScanningForPeripherals() {
        guard bluetoothState == .poweredOn else {
            print("Bluetooth is not powered on. State: \(bluetoothState)")
            connectionStatus = "Bluetooth not ready"
            return
        }
        
        // Stop any existing scan
        centralManager.stopScan()
        
        discoveredPeripherals.removeAll()
        isScanning = true
        connectionStatus = "Scanning..."
        print("Started scanning for BLE peripherals (including generic/Sharpos printers)...")
        
        // Scan with nil services to discover all devices (some printers don't advertise standard UUIDs)
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
        // Set a timeout to stop scanning after 15 seconds
        scanningTimeoutTimer = Timer.scheduledTimer(withTimeInterval: SCAN_TIMEOUT_INTERVAL, repeats: false) { [weak self] _ in
            self?.stopScanningForPeripherals()
            print("Scanning timeout reached - stopping scan")
        }
    }

    func stopScanningForPeripherals() {
        centralManager.stopScan()
        isScanning = false
        scanningTimeoutTimer?.invalidate()
        scanningTimeoutTimer = nil
        
        if connectedPeripheral == nil {
            connectionStatus = "Disconnected"
        }
        print("Stopped scanning for peripherals.")
    }

    func connect(to peripheral: CBPeripheral) {
        centralManager.stopScan()
        isScanning = false
        scanningTimeoutTimer?.invalidate()
        scanningTimeoutTimer = nil
        
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

        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        let chunkSize = peripheral.maximumWriteValueLength(for: writeType)
        print("Writing receipt with type \(writeType == .withoutResponse ? "withoutResponse" : "withResponse"), chunk size: \(chunkSize)")
        var offset = 0

        while offset < data.count {
            let chunk = data.subdata(in: offset..<min(offset + chunkSize, data.count))
            peripheral.writeValue(chunk, for: characteristic, type: writeType)
            offset += chunkSize
        }
        connectionStatus = "Struk dicetak"
    }

    /// Caption gaya A4 persis seperti `QRGeneratorView.generatePDF`:
    /// `"SKU - Nama - Size - Varian"` (tanpa varian bila nil).
    static func labelCaption(productSku: String, productName: String, sizeLabel: String, fabricVariantName: String?) -> String {
        if let fabric = fabricVariantName, !fabric.isEmpty {
            return "\(productSku) - \(productName) - \(sizeLabel) - \(fabric)"
        }
        return "\(productSku) - \(productName) - \(sizeLabel)"
    }

    /// Bersihkan teks agar aman untuk perintah TSPL TEXT (ASCII, tanpa kutip/baris baru).
    nonisolated static func sanitizeForTSPL(_ text: String) -> String {
        var out = text.replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "·", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        // Collapse spasi ganda dari hasil replace di atas
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        // Buang karakter non-ASCII agar data(using: .ascii) tidak gagal
        out = String(out.unicodeScalars.filter { $0.isASCII }.map { Character($0) })
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// Bungkus caption ke beberapa baris TEXT dengan font dinamis multi-tier:
    /// pilih font TERBESAR yang membuat seluruh caption muat di ruang tersisa
    /// (font "3" -> "2" -> "1"). Tidak ada truncate kecuali pengaman terakhir
    /// bila caption ekstrem (font "1" pun tidak muat).
    /// Mengembalikan baris-baris perintah `TEXT x,y,"font",0,1,1,"..."`.
    nonisolated static func captionTextCommands(caption: String, textX: Int, labelHeightDots: Int, maxWidthDots: Int) -> String {
        let clean = sanitizeForTSPL(caption)
        guard !clean.isEmpty else { return "" }

        // Lebar karakter mono per font built-in TSPL (dots): "3" = 16x24, "2" = 12x20, "1" = 8x12.
        // Tinggi baris diberi jarak baca: "3" = 26, "2" = 22, "1" = 14.
        struct Tier { let font: String; let charW: Int; let lineStep: Int }
        let tiers = [
            Tier(font: "3", charW: 16, lineStep: 26),
            Tier(font: "2", charW: 12, lineStep: 22),
            Tier(font: "1", charW: 8, lineStep: 14),
        ]

        var pickedFont = "1"
        var pickedStep = 14
        var pickedLines: [String] = []

        for t in tiers {
            let maxChars = max(4, maxWidthDots / t.charW)
            let maxLines = max(1, (labelHeightDots - 8) / t.lineStep)
            let lines = wordWrap(clean, maxChars: maxChars)
            if lines.count <= maxLines {
                pickedFont = t.font; pickedStep = t.lineStep; pickedLines = lines
                break
            }
            // Simpan hasil tier terkecil sebagai fallback pengaman
            pickedFont = t.font; pickedStep = t.lineStep; pickedLines = lines
        }

        // Pengaman terakhir: bila tier terkecil pun overflow, potong dengan "..."
        // (seharusnya tidak terjadi untuk caption produk normal).
        let smallest = tiers.last!
        let maxLinesFinal = max(1, (labelHeightDots - 8) / smallest.lineStep)
        if pickedFont == smallest.font, pickedLines.count > maxLinesFinal {
            let maxChars = max(4, maxWidthDots / smallest.charW)
            pickedLines = Array(pickedLines.prefix(maxLinesFinal))
            if var last = pickedLines.last {
                if last.count > maxChars - 3 {
                    last = String(last.prefix(max(0, maxChars - 3))) + "..."
                } else {
                    last += "..."
                }
                pickedLines[pickedLines.count - 1] = last
            }
        }

        // Blok teks di-center vertikal dalam label agar selalu rapi
        let blockH = pickedLines.count * pickedStep
        let topY = max(4, (labelHeightDots - blockH) / 2)

        var out = ""
        for (i, line) in pickedLines.enumerated() {
            let y = topY + i * pickedStep
            out += "TEXT \(textX),\(y),\"\(pickedFont)\",0,1,1,\"\(line)\"\r\n"
        }
        return out
    }

    /// Greedy word-wrap sederhana berdasarkan spasi.
    nonisolated static func wordWrap(_ text: String, maxChars: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            let w = String(word)
            if current.isEmpty {
                // Kata tunggal yang lebih panjang dari batas: potong keras
                if w.count > maxChars {
                    var rest = w
                    while !rest.isEmpty {
                        lines.append(String(rest.prefix(maxChars)))
                        rest = String(rest.dropFirst(maxChars))
                    }
                } else {
                    current = w
                }
            } else if current.count + 1 + w.count <= maxChars {
                current += " " + w
            } else {
                lines.append(current)
                if w.count > maxChars {
                    var rest = w
                    while !rest.isEmpty {
                        lines.append(String(rest.prefix(maxChars)))
                        rest = String(rest.dropFirst(maxChars))
                    }
                    current = ""
                } else {
                    current = w
                }
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines.isEmpty ? [text] : lines
    }

    func printLabel(qrData: String, caption: String? = nil, width: Double, height: Double, gap: Double, quantity: Int) {
        guard let peripheral = connectedPeripheral, let characteristic = writableCharacteristic else {
            print("Printer not connected or writable characteristic not found.")
            connectionStatus = "Print Error: Not connected or no writable characteristic"
            return
        }

        connectionStatus = "Printing..."

        var tsplCommands = ""

        // Setup commands
        tsplCommands += "SIZE \(width) mm,\(height) mm\r\n"
        tsplCommands += "GAP \(gap) mm,0 mm\r\n"
        tsplCommands += "CLS\r\n" // Clear buffer
        tsplCommands += "DIRECTION 1\r\n" // Print direction (configurable if needed)
        tsplCommands += "REFERENCE 0,0\r\n" // Origin point (configurable if needed)
        tsplCommands += "SET TEAR ON\r\n" // Enable tear-off mode

        // QR Code — ukuran MAKSIMAL yang muat di tinggi label.
        // Data "oura:<UUID>" (41 char, byte mode, ECC L) memakai QR Version 3 = 29x29 modul,
        // jadi cell 4 -> 116 dots = 14.5mm, pas untuk label 15mm. Bila label diset lebih
        // pendek di Pengaturan, cell turun otomatis (4 -> 3 -> 2) agar tidak terpotong.
        let dotsPerMM = 8 // 203 dpi
        let labelHeightDots = Int(height * Double(dotsPerMM))
        let labelWidthDots = Int(width * Double(dotsPerMM))
        let qrModules = 29 // Version 3 minimal untuk payload "oura:<UUID>"
        var cellWidth = 4
        while cellWidth > 2 && qrModules * cellWidth > labelHeightDots - 4 {
            cellWidth -= 1
        }
        let qrDots = qrModules * cellWidth

        if let caption = caption, !caption.trimmingCharacters(in: .whitespaces).isEmpty {
            let qrX = 6
            let qrY = max(2, (labelHeightDots - qrDots) / 2) // center vertikal
            tsplCommands += "QRCODE \(qrX),\(qrY),L,\(cellWidth),A,0,M,20,\"\(qrData)\"\r\n"

            // Ruang tersisa di kanan QR dimaksimalkan untuk caption (margin kecil 4-6 dots)
            let textX = qrX + qrDots + 6
            let maxTextW = max(40, labelWidthDots - textX - 4)
            tsplCommands += Self.captionTextCommands(
                caption: caption,
                textX: textX,
                labelHeightDots: labelHeightDots,
                maxWidthDots: maxTextW
            )
        } else {
            // Legacy: QR di tengah (perilaku lama bila tanpa caption)
            let qrX = Int(width * 8 / 2) - 20
            let qrY = Int(height * 8 / 2) - 20
            tsplCommands += "QRCODE \(qrX),\(qrY),L,\(cellWidth),A,0,M,20,\"\(qrData)\"\r\n"
        }

        // Print command
        tsplCommands += "PRINT \(quantity),1\r\n"

        print("Generated TSPL Commands:\n\(tsplCommands)")

        // Send commands in chunks if necessary
        guard let data = tsplCommands.data(using: .ascii, allowLossyConversion: true) else {
            connectionStatus = "Gagal memproses data label"
            return
        }
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        let chunkSize = peripheral.maximumWriteValueLength(for: writeType)
        print("Writing label with type \(writeType == .withoutResponse ? "withoutResponse" : "withResponse"), chunk size: \(chunkSize)")
        var offset = 0

        while offset < data.count {
            let chunk = data.subdata(in: offset..<min(offset + chunkSize, data.count))
            peripheral.writeValue(chunk, for: characteristic, type: writeType)
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
        // Update bluetoothState synchronously to avoid race conditions in auto-connect check
        self.bluetoothState = central.state
        
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on.")
            self.connectionStatus = "Ready to scan"
            attemptAutoConnect()
        case .poweredOff:
            print("Bluetooth is powered off.")
            self.connectionStatus = "Bluetooth Off"
            self.discoveredPeripherals.removeAll()
            self.connectedPeripheral = nil
            self.writableCharacteristic = nil
            stopScanningForPeripherals()
        case .resetting:
            print("Bluetooth is resetting.")
            self.connectionStatus = "Resetting"
        case .unauthorized:
            print("Bluetooth is unauthorized.")
            self.connectionStatus = "Unauthorized"
        case .unknown:
            print("Bluetooth state is unknown.")
            self.connectionStatus = "Initializing..."
        case .unsupported:
            print("Bluetooth is unsupported on this device.")
            self.connectionStatus = "Unsupported"
        @unknown default:
            print("A new Bluetooth state was added that is not yet handled.")
            self.connectionStatus = "Unknown New State"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Filter out duplicates and devices without names
        DispatchQueue.main.async {
            if !self.discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                // Prioritize devices with local names
                if peripheral.name != nil && !peripheral.name!.isEmpty {
                    self.discoveredPeripherals.append(peripheral)
                    print("Discovered peripheral: \(peripheral.name ?? "Unknown"), RSSI: \(RSSI)")
                }
            }
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
        DispatchQueue.main.async {
            self.connectionStatus = "Connected to \(peripheral.name ?? "Unknown Device")"
        }
        peripheral.delegate = self
        peripheral.discoverServices(nil) // Discover all services to support printers with non-standard service UUIDs
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "Unknown Device"). Error: \(error?.localizedDescription ?? "Unknown error")")
        DispatchQueue.main.async {
            self.connectionStatus = "Failed to connect"
            self.connectedPeripheral = nil
            self.writableCharacteristic = nil
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown Device"). Error: \(error?.localizedDescription ?? "No error")")
        DispatchQueue.main.async {
            self.connectionStatus = "Disconnected"
            self.connectedPeripheral = nil
            self.writableCharacteristic = nil
        }
        
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
            peripheral.discoverCharacteristics(nil, for: service) // Discover all characteristics to find writable ones on any custom UUID
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
            
            // Look for write or writeWithoutResponse capability
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                DispatchQueue.main.async {
                    self.writableCharacteristic = characteristic
                }
                print("Identified writable characteristic: \(characteristic.uuid)")
                // Don't break - continue to see all characteristics
            }
            
            // Also enable notifications if supported for feedback
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
                print("Enabled notifications for characteristic: \(characteristic.uuid)")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        // Handle incoming data if this is a notify/read characteristic
        if let data = characteristic.value {
            print("Received data from printer: \(data.map { String(format: "%02x", $0) }.joined())")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        print("Successfully wrote value to characteristic \(characteristic.uuid)")
    }
}
