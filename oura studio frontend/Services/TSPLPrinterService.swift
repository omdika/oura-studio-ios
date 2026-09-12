
import Foundation
import CoreBluetooth

class TSPLPrinterService: NSObject, ObservableObject {
    @Published var centralManager: CBCentralManager!
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var connectionStatus: String = "Disconnected"

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
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
        connectionStatus = "Disconnected"
        print("Disconnected from peripheral.")
    }
}

// MARK: - CBCentralManagerDelegate
extension TSPLPrinterService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on.")
            connectionStatus = "Ready to scan"
        case .poweredOff:
            print("Bluetooth is powered off.")
            connectionStatus = "Bluetooth Off"
            discoveredPeripherals.removeAll()
            connectedPeripheral = nil
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
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown Device"). Error: \(error?.localizedDescription ?? "No error")")
        connectionStatus = "Disconnected"
        connectedPeripheral = nil
        // Optionally, restart scanning or notify user
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
            // Here you would typically identify the write characteristic
            // peripheral.setNotifyValue(true, for: characteristic) // If you need notifications
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
