
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
    /// true selama satu job struk sedang dikirim ke printer. Mencegah dua burst
    /// tulis tumpang-tindih — penyebab klasik "cetak pertama OK, berikutnya gagal".
    @Published var isPrinting: Bool = false
    /// true bila service-discovery selesai DAN karakteristik tulis valid sudah
    /// ditemukan. Sheet pemilih printer menunggu flag ini (bukan sekadar
    /// connect) sebelum dismiss, agar tombol Cetak tidak ditekan saat
    /// writableCharacteristic masih nil.
    @Published var isPrinterReady: Bool = false

    // MARK: - Paced receipt sender (struk saja; printLabel TIDAK diubah)

    /// Antrean chunk job struk yang sedang berjalan (supaya didWriteValueFor
    /// bisa melanjutkan rantai write-with-response tanpa menyentuh jalur label).
    private var receiptChunks: [Data] = []
    private var receiptIndex: Int = 0
    private weak var receiptPeripheral: CBPeripheral?
    private var receiptCharacteristic: CBCharacteristic?
    private var receiptWriteType: CBCharacteristicWriteType = .withoutResponse
    private let receiptSendQueue = DispatchQueue(label: "oura.printer.receipt-send")
    /// Jeda antar chunk untuk .withoutResponse. Printer UART BLE portabel
    /// (TSPL/CPCL) tidak sanggup menerima burst ~2KB sekaligus; buffer penuh ->
    /// paket dibuang -> job berikutnya gagal sampai power-cycle.
    /// Payload label kecil (1-2 chunk) sehingga lolos; struk besar sehingga gagal.
    private let RECEIPT_CHUNK_DELAY: TimeInterval = 0.03 // 30 ms
    /// Jeda antar chunk untuk .withResponse. ACK BLE hanya berarti modul BLE
    /// menerima paket — BUKAN print-head selesai. Jeda ini memberi waktu drain
    /// UART modul->printer antar chunk.
    private let RECEIPT_WR_DELAY: TimeInterval = 0.06 // 60 ms

    // MARK: - Busy-window guard antar job struk
    //
    // Temuan dari log lapangan: BLE melaporkan "Successfully wrote" untuk
    // SEMUA chunk job ke-2 (write-with-response ter-ACK modul BLE), namun
    // kertas tidak keluar. Artinya byte berhenti di modul BLE-UART
    // (karakteristik 49535343-...) karena print-engine masih mencetak job
    // ke-1 secara fisik (~80mm struk butuh >2 dtk) dan printer portabel ini
    // tidak mem-buffer job baru selama mencetak — byte hilang TANPA error.
    // Label lolos karena kecil (1 chunk) dan natural-terjeda oleh alur UI.
    //
    // Perbaikan: setelah satu job struk selesai dikirim, printer dianggap
    // SIBUK selama estimasi durasi cetak fisik. Job baru dalam window itu
    // TIDAK langsung ditembak — melainkan diantre SATU slot dan dikirim
    // otomatis saat window habis. Ini meniru perilaku "tunggu kertas selesai
    // keluar" yang secara natural terjadi pada alur label QR yang sukses.

    /// Batas waktu printer diperkirakan masih mencetak job sebelumnya.
    private var receiptBusyUntil: Date = .distantPast
    /// Estimasi durasi cetak job yang sedang berjalan (detik).
    private var receiptPrintSeconds: TimeInterval = 0
    /// Nomor urut job — penjaga agar callback tertunda milik job lama tidak
    /// bisa memajukan/menyelesaikan job baru.
    private var receiptJobSeq: Int = 0
    /// Job struk yang menunggu window sibuk habis (satu slot, terbaru menang).
    private var pendingReceiptOrder: SalesOrder?
    private var pendingReceiptWorkItem: DispatchWorkItem?
    /// Waktu selesai-kirim job terakhir — untuk log diagnostik jeda antar job.
    private var lastReceiptSentAt: Date?
    private static let bootTime = Date()

    /// Estimasi durasi cetak fisik: base render + tinggi/kecepatan konservatif
    /// head portable (~30mm/dtk). 80mm -> ~4,7 dtk. Sengaja konservatif: yang
    /// penting printer SUDAH idle saat job berikutnya tiba.
    nonisolated static func estimatedReceiptPrintSeconds(heightMm: Int) -> TimeInterval {
        2.0 + Double(max(30, heightMm)) / 30.0
    }

    // MARK: - Wake + resync preamble antar job struk
    //
    // Bukti log: job ke-2 dikirim 20,4 dtk SETELAH job ke-1 selesai (busy-window
    // sudah lama habis), byte identik, semua chunk ter-ACK modul BLE, tapi
    // kertas diam dan printer tidak membalas apa pun. Jadi byte hilang BUKAN
    // karena tabrakan dengan cetakan sebelumnya, melainkan karena sisi
    // print-engine/MCU sudah tidak mendengarkan: pola klasik printer thermal
    // portabel yang (a) MCU-nya tidur setelah idle belasan detik sementara
    // modul BLE tetap terjaga dan tetap me-ACK, atau (b) parser TSPL-nya
    // butuh resync setelah satu job continuous-paper selesai.
    // Label QR lolos karena selalu dicetak beruntun saat printer terjaga.
    //
    // Mitigasi buta-model yang aman: bila jeda sejak kirim-terakhir > ambang,
    // kirim dulu preamble secukupnya ("\r\nCLS\r\n" = akhiri baris sampah yang
    // mungkin menggantung + bersihkan buffer; no-op bila printer sehat),
    // beri jeda bangun, BARU kirim job. Aktivitas UART membangunkan MCU yang
    // tidur; CLS me-resync parser yang desync. Tanpa jeda ini, byte job
    // langsung masuk ke kehampaan.

    /// Bila idle lebih lama dari ini sejak kirim-terakhir, pakai preamble.
    private let RECEIPT_WAKE_IDLE_THRESHOLD: TimeInterval = 5.0
    /// Jeda setelah preamble agar MCU sempat bangun sebelum job tiba.
    private let RECEIPT_WAKE_DELAY: TimeInterval = 0.8
    private let RECEIPT_WAKE_PAYLOAD = "\r\nCLS\r\n"
    /// true bila write-withResponse yang outstanding adalah preamble wake
    /// (ACK-nya JANGAN dihitung sebagai ACK chunk).
    private var receiptWakeOutstanding = false

    /// Log diagnostik ber-stempel waktu untuk korelasi jeda antar job.
    private func rlog(_ msg: String) {
        let t = Date().timeIntervalSince(Self.bootTime)
        print(String(format: "[R+%07.2fs] %@", t, msg))
    }

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
        pendingReceiptWorkItem?.cancel()
        pendingReceiptWorkItem = nil
        pendingReceiptOrder = nil
        receiptBusyUntil = .distantPast
        receiptWakeOutstanding = false
        connectedPeripheral = nil
        writableCharacteristic = nil
        isPrinterReady = false
        // Batalkan status job struk yang mungkin sedang berjalan agar busy
        // guard tidak macet selamanya setelah disconnect di tengah cetak.
        receiptChunks = []
        receiptIndex = 0
        receiptPeripheral = nil
        receiptCharacteristic = nil
        isPrinting = false
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

        let job = ReceiptGenerator.generateTSPL(order: order)
        print("Generated TSPL Commands:\n\(job.commands)")

        // allowLossyConversion:true — sama seperti jalur label yang selalu
        // sukses. Strict .ascii mengembalikan nil untuk SATU saja karakter
        // non-ASCII (nama produk/pelanggan) sehingga cetak gagal total.
        // (generateTSPL sudah sanitasi, ini jaring pengaman lapis kedua.)
        guard let data = job.commands.data(using: .ascii, allowLossyConversion: true), !data.isEmpty else {
            connectionStatus = "Gagal memproses data"
            return
        }

        let now = Date()
        if let last = lastReceiptSentAt {
            rlog(String(format: "printReceipt %@ gap=%.1fs since last send-end (busyUntil in %.1fs)",
                        order.invoiceNo, now.timeIntervalSince(last),
                        receiptBusyUntil.timeIntervalSince(now)))
        }

        // Kasus 1: pengiriman masih berjalan -> antre (terbaru menang).
        // Kasus 2: printer diperkirakan masih mencetak fisik job sebelumnya
        // (busy-window) -> antre dan kirim otomatis saat window habis.
        // Menembak byte dalam kondisi ini = byte hilang diam-diam di modul
        // BLE-UART (bukti: log "Successfully wrote" semua tapi kertas diam).
        if isPrinting || now < receiptBusyUntil {
            let wait = isPrinting ? nil as TimeInterval? : receiptBusyUntil.timeIntervalSince(now)
            if let w = wait {
                rlog(String(format: "printer busy-window: queue %@, auto-send in %.1fs", order.invoiceNo, w))
            } else {
                rlog("send in progress: queue \(order.invoiceNo)")
            }
            queuePendingReceipt(order: order, delay: wait)
            DispatchQueue.main.async {
                self.connectionStatus = "Menunggu printer siap..."
            }
            return
        }

        startReceiptSend(order: order, data: data, heightMm: job.heightMm,
                         peripheral: peripheral, characteristic: characteristic)
    }

    /// Antre satu job struk; dikirim otomatis setelah `delay` (atau segera
    /// setelah pengiriman berjalan selesai bila delay nil). Terbaru menang.
    private func queuePendingReceipt(order: SalesOrder, delay: TimeInterval?) {
        pendingReceiptWorkItem?.cancel()
        pendingReceiptOrder = order
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard let pending = self.pendingReceiptOrder else { return }
            if self.isPrinting || Date() < self.receiptBusyUntil {
                // Belum aman juga — jadwal ulang pemeriksaan.
                self.rlog("pending \(pending.invoiceNo): still busy, re-check in 0.5s")
                self.queuePendingReceipt(order: pending, delay: 0.5)
                return
            }
            self.pendingReceiptOrder = nil
            self.rlog("pending \(pending.invoiceNo): window clear, sending now")
            self.printReceipt(order: pending)
        }
        pendingReceiptWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + (delay ?? 0.5), execute: item)
    }

    private func startReceiptSend(order: SalesOrder, data: Data, heightMm: Int,
                                  peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        let chunkSize = max(1, peripheral.maximumWriteValueLength(for: writeType))
        rlog("send \(order.invoiceNo): type=\(writeType == .withoutResponse ? "withoutResponse" : "withResponse") chunk=\(chunkSize) bytes=\(data.count) height=\(heightMm)mm")

        var chunks: [Data] = []
        var offset = 0
        while offset < data.count {
            chunks.append(data.subdata(in: offset..<min(offset + chunkSize, data.count)))
            offset += chunkSize
        }

        receiptJobSeq += 1
        let seq = receiptJobSeq
        receiptPrintSeconds = Self.estimatedReceiptPrintSeconds(heightMm: heightMm)
        // Preamble bila printer mungkin sudah idle-tidur/desync.
        let idleGap = lastReceiptSentAt.map { Date().timeIntervalSince($0) }
        let needWake = idleGap == nil || idleGap! > RECEIPT_WAKE_IDLE_THRESHOLD
        rlog("send \(order.invoiceNo): seq=\(seq) chunks=\(chunks.count) estPrint=\(String(format: "%.1f", receiptPrintSeconds))s idleGap=\(idleGap.map { String(format: "%.1f", $0) } ?? "first")s wake=\(needWake)")

        DispatchQueue.main.async {
            self.isPrinting = true
            self.connectionStatus = "Mencetak..."
        }
        receiptChunks = chunks
        receiptIndex = 0
        receiptPeripheral = peripheral
        receiptCharacteristic = characteristic
        receiptWriteType = writeType
        receiptWakeOutstanding = false

        guard let wakeData = RECEIPT_WAKE_PAYLOAD.data(using: .ascii), needWake else {
            sendFirstReceiptChunk(seq: seq)
            return
        }
        // Kirim preamble dulu; chunk[0] menyusul setelah ACK (+ jeda bangun
        // untuk withResponse) atau setelah jeda bangun (withoutResponse).
        if writeType == .withResponse {
            receiptWakeOutstanding = true
            rlog("send \(order.invoiceNo): seq=\(seq) wake preamble sent, awaiting ACK")
            peripheral.writeValue(wakeData, for: characteristic, type: .withResponse)
        } else {
            receiptSendQueue.async { [weak self] in
                guard let self, seq == self.receiptJobSeq else { return }
                guard let p = self.receiptPeripheral, let c = self.receiptCharacteristic else {
                    self.finishReceipt(success: false, status: "Printer terputus saat mencetak")
                    return
                }
                self.rlog("send: wake preamble sent, waiting \(self.RECEIPT_WAKE_DELAY)s")
                p.writeValue(wakeData, for: c, type: .withoutResponse)
                Thread.sleep(forTimeInterval: self.RECEIPT_WAKE_DELAY)
                self.pumpWithoutResponseChunks(seq: seq)
            }
        }
    }

    /// Kirim chunk[0] job struk (dipakai saat tanpa preamble).
    private func sendFirstReceiptChunk(seq: Int) {
        guard seq == receiptJobSeq,
              let peripheral = receiptPeripheral,
              let characteristic = receiptCharacteristic,
              !receiptChunks.isEmpty else {
            finishReceipt(success: false, status: "Printer terputus saat mencetak")
            return
        }
        if receiptWriteType == .withResponse {
            // Rantai via didWriteValueFor: chunk berikutnya HANYA dikirim
            // setelah ACK + jeda drain UART (lihat RECEIPT_WR_DELAY).
            peripheral.writeValue(receiptChunks[0], for: characteristic, type: .withResponse)
        } else {
            receiptSendQueue.async { [weak self] in
                self?.pumpWithoutResponseChunks(seq: seq)
            }
        }
    }

    /// Pompa chunk .withoutResponse satu-per-satu dengan jeda + gate
    /// canSendWriteWithoutResponse. Berjalan di receiptSendQueue (bukan main).
    private func pumpWithoutResponseChunks(seq: Int) {
        guard seq == receiptJobSeq,
              let peripheral = receiptPeripheral,
              let characteristic = receiptCharacteristic else {
            finishReceipt(success: false, status: "Printer terputus saat mencetak")
            return
        }
        while receiptIndex < receiptChunks.count {
            if seq != receiptJobSeq { return } // job diganti, berhenti diam
            // Gate: tunggu sampai stack BLE siap (maks ~2 dtk per chunk)
            // sebelum mendorong chunk berikutnya ke buffer printer.
            var waited = 0
            while !peripheral.canSendWriteWithoutResponse && waited < 40 {
                Thread.sleep(forTimeInterval: 0.05)
                waited += 1
            }
            if !peripheral.canSendWriteWithoutResponse {
                rlog("send stalled: BLE stack not ready, aborting job.")
                finishReceipt(success: false, status: "Printer sibuk, coba lagi")
                return
            }
            // Putus bila koneksi/perangkat berubah di tengah jalan.
            if peripheral.state != .connected || characteristic != receiptCharacteristic {
                rlog("send aborted: peripheral disconnected or characteristic changed.")
                finishReceipt(success: false, status: "Printer terputus saat mencetak")
                return
            }
            peripheral.writeValue(receiptChunks[receiptIndex], for: characteristic, type: .withoutResponse)
            receiptIndex += 1
            if receiptIndex < receiptChunks.count {
                Thread.sleep(forTimeInterval: RECEIPT_CHUNK_DELAY)
            }
        }
        finishReceipt(success: true, status: "Struk dicetak")
    }

    private func finishReceipt(success: Bool, status: String) {
        receiptChunks = []
        receiptIndex = 0
        receiptPeripheral = nil
        receiptCharacteristic = nil
        receiptWakeOutstanding = false
        let now = Date()
        lastReceiptSentAt = now
        if success {
            // Kunci busy-window: byte sudah terkirim SEMUA, tapi kertas baru
            // SELESAI keluar ~estPrint detik lagi. Job yang ditembak dalam
            // window ini hilang diam-diam di modul BLE-UART.
            receiptBusyUntil = now.addingTimeInterval(receiptPrintSeconds)
            rlog(String(format: "job finished OK: busy-window %.1fs", receiptPrintSeconds))
        } else {
            // Gagal kirim: jangan kunci lama, biarkan retry cepat.
            receiptBusyUntil = now.addingTimeInterval(1.0)
        }
        rlog("Receipt job finished (success=\(success)): \(status)")
        DispatchQueue.main.async {
            self.isPrinting = false
            // Bila ada job antre, status "Menunggu..." milik antrean yang
            // akan segera dikirim — jangan timpa dengan status selesai.
            if self.pendingReceiptOrder == nil {
                self.connectionStatus = status
            }
        }
    }

    /// Isi caption label thermal — per field agar layout terstruktur per baris
    /// (SKU besar, nama/varian kecil, size jelas), bukan satu string di-wrap.
    struct ThermalLabelContent {
        let sku: String
        let productName: String
        let fabricVariantName: String?
        let sizeLabel: String
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

    /// Caption TERSTRUKTUR per baris dengan hierarki font tetap:
    ///   Baris 1: SKU — font "3" -> "2" -> "1", otomatis mengecil sampai muat
    ///     (tidak pernah terpotong kanan kecuali SKU > 12 char).
    ///   Baris 2-3: Nama produk — font "1" (sekecil mungkin), maks 2 baris.
    ///   Baris 4: Varian kain — font "1", 1 baris (dilewati bila tidak ada).
    ///   Size saja ("XXL", tanpa prefix) — font "2", dipin di bawah dengan
    ///     margin 16 dots (~2mm) agar tidak mepet garis bawah label.
    /// Blok teks RATA ATAS (SKU sejajar atas QR, y=2). Step antar baris longgar
    /// agar tidak tumpuk. Lebar char dikalibrasi dari hasil cetak fisik printer
    /// ini (font "3" ≈ 18 dots, "2" ≈ 15, "1" ≈ 10) + margin kanan 14 dots
    /// (~1.75mm) toleransi geser label saat feed.
    nonisolated static func structuredCaptionCommands(content: ThermalLabelContent, textX: Int, labelHeightDots: Int, maxWidthDots: Int) -> String {
        let skuClean = sanitizeForTSPL(content.sku)
        let nameClean = sanitizeForTSPL(content.productName)
        let fabricClean: String? = {
            guard let raw = content.fabricVariantName else { return nil }
            let s = sanitizeForTSPL(raw)
            return s.isEmpty ? nil : s
        }()
        let sizeClean = sanitizeForTSPL(content.sizeLabel)
        guard !skuClean.isEmpty else { return "" }

        // Size dipin di bawah label dengan margin 16 dots (~2mm) agar tidak
        // mepet garis bawah.
        let sizeY = max(2, labelHeightDots - 36)

        var y = 2 // RATA ATAS sejajar QR
        var out = ""

        // SKU — auto-shrink 3 tier sampai terlihat semua: "3" (muat 7 char)
        // -> "2" (muat 8 char) -> "1" (muat 12 char, truncate hanya bila lebih).
        let skuMax3 = max(4, maxWidthDots / 18)
        let skuMax2 = max(4, maxWidthDots / 15)
        let skuMax1 = max(4, maxWidthDots / 10)
        if skuClean.count <= skuMax3 {
            out += "TEXT \(textX),\(y),\"3\",0,1,1,\"\(skuClean)\"\r\n"
            y += 30
        } else if skuClean.count <= skuMax2 {
            out += "TEXT \(textX),\(y),\"2\",0,1,1,\"\(skuClean)\"\r\n"
            y += 26
        } else {
            let t = skuClean.count > skuMax1 ? String(skuClean.prefix(max(0, skuMax1 - 3))) + "..." : skuClean
            out += "TEXT \(textX),\(y),\"1\",0,1,1,\"\(t)\"\r\n"
            y += 20
        }

        // Nama produk — font "1", maks 2 baris, dibatasi ruang sebelum size.
        let nameMax = skuMax1
        let roomForName = max(0, sizeY - y)
        let nameAllowed = max(1, min(2, roomForName / 20))
        var nameLines = wordWrap(nameClean.isEmpty ? "-" : nameClean, maxChars: nameMax)
        if nameLines.count > nameAllowed {
            nameLines = Array(nameLines.prefix(nameAllowed))
            var last = nameLines[nameLines.count - 1]
            if last.count > nameMax - 3 {
                last = String(last.prefix(max(0, nameMax - 3))) + "..."
            } else {
                last += "..."
            }
            nameLines[nameLines.count - 1] = last
        }
        for line in nameLines {
            out += "TEXT \(textX),\(y),\"1\",0,1,1,\"\(line)\"\r\n"
            y += 20
        }

        // Varian — font "1", 1 baris, hanya bila masih ada ruang sebelum size.
        if let fabric = fabricClean, y + 20 <= sizeY {
            let t = fabric.count > nameMax ? String(fabric.prefix(max(0, nameMax - 3))) + "..." : fabric
            out += "TEXT \(textX),\(y),\"1\",0,1,1,\"\(t)\"\r\n"
            y += 20
        }

        // Size saja tanpa prefix ("XXL") — font "2", selalu di posisi sizeY.
        let sizeMax = skuMax2
        var sizeText = sizeClean.isEmpty ? "-" : sizeClean
        if sizeText.count > sizeMax {
            sizeText = String(sizeText.prefix(max(0, sizeMax - 3))) + "..."
        }
        out += "TEXT \(textX),\(sizeY),\"2\",0,1,1,\"\(sizeText)\"\r\n"
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

    func printLabel(qrData: String, content: ThermalLabelContent? = nil, width: Double, height: Double, gap: Double, quantity: Int) {
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

        if let content = content {
            // QR rapat ke kiri (x=2) + caption 4 dots dari QR agar seluruh
            // blok teks geser kiri dan margin kanan lebih lega.
            let qrX = 2
            let qrY = max(2, (labelHeightDots - qrDots) / 2) // center vertikal
            tsplCommands += "QRCODE \(qrX),\(qrY),L,\(cellWidth),A,0,M,20,\"\(qrData)\"\r\n"

            // Margin kanan 14 dots (~1.75mm) toleransi geser label saat feed.
            let textX = qrX + qrDots + 4
            let maxTextW = max(40, labelWidthDots - textX - 14)
            tsplCommands += Self.structuredCaptionCommands(
                content: content,
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
            self.isPrinterReady = false
            self.isPrinting = false
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
            self.isPrinterReady = false
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown Device"). Error: \(error?.localizedDescription ?? "No error")")
        DispatchQueue.main.async {
            self.connectionStatus = "Disconnected"
            self.connectedPeripheral = nil
            self.writableCharacteristic = nil
            self.isPrinterReady = false
            self.pendingReceiptWorkItem?.cancel()
            self.pendingReceiptWorkItem = nil
            self.pendingReceiptOrder = nil
            self.receiptBusyUntil = .distantPast
            self.receiptWakeOutstanding = false
            // Bebaskan busy guard bila disconnect terjadi di tengah job struk.
            self.receiptChunks = []
            self.receiptIndex = 0
            self.receiptPeripheral = nil
            self.receiptCharacteristic = nil
            self.isPrinting = false
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

            // Pilih kandidat tulis TERBAIK, bukan yang terakhir ditemukan:
            // FFE1 (UART printer umum) > writeWithoutResponse lain > write.
            // Tanpa ini, writableCharacteristic bisa tertimpa karakteristik
            // tulis yang salah sehingga cetak kedua gagal walau connect OK.
            let isWritable = characteristic.properties.contains(.write)
            let isWNR = characteristic.properties.contains(.writeWithoutResponse)
            if isWritable || isWNR {
                let isUART = characteristic.uuid.uuidString.uppercased().hasPrefix("FFE1")
                let current = self.writableCharacteristic
                let currentIsUART = current?.uuid.uuidString.uppercased().hasPrefix("FFE1") ?? false
                let currentIsWNR = current?.properties.contains(.writeWithoutResponse) ?? false
                let shouldReplace: Bool = {
                    guard let _ = current else { return true }
                    if isUART && !currentIsUART { return true }
                    if currentIsUART && !isUART { return false }
                    // Sama-sama (non-)UART: jangan downgrade WNR -> write.
                    if isWNR && !currentIsWNR { return true }
                    return false
                }()
                if shouldReplace {
                    DispatchQueue.main.async {
                        self.writableCharacteristic = characteristic
                        self.isPrinterReady = true
                    }
                    print("Identified writable characteristic: \(characteristic.uuid)")
                }
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
        // Handle incoming data if this is a notify/read characteristic.
        // Stempel waktu membantu diagnosis (mis. status "selesai cetak").
        if let data = characteristic.value {
            let t = Date().timeIntervalSince(Self.bootTime)
            print(String(format: "[R+%07.2fs] Received data from printer: %@", t, data.map { String(format: "%02x", $0) }.joined()))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            // Gagal di tengah rantai struk with-response: bebaskan busy guard.
            if peripheral === receiptPeripheral && characteristic == receiptCharacteristic && !receiptChunks.isEmpty {
                receiptSendQueue.async { [weak self] in
                    self?.finishReceipt(success: false, status: "Gagal mencetak struk")
                }
            }
            return
        }
        print("Successfully wrote value to characteristic \(characteristic.uuid)")
        // Lanjutkan rantai chunk struk with-response. (Jalur label tidak
        // memakai antrean ini — receiptPeripheral hanya diset oleh printReceipt
        // — sehingga perilaku printLabel TIDAK berubah.)
        if peripheral === receiptPeripheral,
           characteristic == receiptCharacteristic,
           receiptWriteType == .withResponse,
           !receiptChunks.isEmpty {
            let seq = receiptJobSeq
            if receiptWakeOutstanding {
                // ACK ini milik preamble wake, BUKAN chunk: jangan majukan
                // receiptIndex. Beri jeda bangun lalu mulai dari chunk[0].
                receiptWakeOutstanding = false
                rlog("wake preamble ACKed (seq=\(seq)), starting job in \(RECEIPT_WAKE_DELAY)s")
                DispatchQueue.main.asyncAfter(deadline: .now() + RECEIPT_WAKE_DELAY) { [weak self] in
                    guard let self, seq == self.receiptJobSeq else { return }
                    guard peripheral === self.receiptPeripheral,
                          characteristic == self.receiptCharacteristic,
                          self.receiptWriteType == .withResponse,
                          !self.receiptChunks.isEmpty else { return }
                    peripheral.writeValue(self.receiptChunks[0], for: characteristic, type: .withResponse)
                }
                return
            }
            // Jeda drain UART antar chunk: ACK BLE != print-head menerima.
            DispatchQueue.main.asyncAfter(deadline: .now() + RECEIPT_WR_DELAY) { [weak self] in
                guard let self, seq == self.receiptJobSeq else { return }
                guard peripheral === self.receiptPeripheral,
                      characteristic == self.receiptCharacteristic,
                      self.receiptWriteType == .withResponse,
                      !self.receiptChunks.isEmpty else { return }
                self.receiptIndex += 1
                if self.receiptIndex < self.receiptChunks.count {
                    peripheral.writeValue(self.receiptChunks[self.receiptIndex], for: characteristic, type: .withResponse)
                } else {
                    self.receiptSendQueue.async { [weak self] in
                        self?.finishReceipt(success: true, status: "Struk dicetak")
                    }
                }
            }
        }
    }
}
