import Foundation
import UIKit
import PDFKit

extension Double {
    var rupiahFormattedNoSymbol: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.groupingSeparator = "."
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: self)) ?? "0"
    }
}

/// Hasil generate struk: byte ESC/POS + estimasi durasi cetak fisik (untuk
/// busy-window guard di TSPLPrinterService).
struct ReceiptJob {
    let bytes: Data
    let printSecondsEstimate: TimeInterval
}

class ReceiptGenerator {
    // STRUK PAKAI ESC/POS, LABEL TETAP TSPL — alasan (Sharkpos X265L):
    // Printer ekosistem Eleph-label ini punya DUA MODE persisten yang diganti
    // via TAHAN tombol FEED 5 detik ("Shift to Label mode" / "Shift to Receipt
    // mode", lalu printer mati sendiri):
    //   Label mode   -> parser TSPL/CPCL untuk kertas gap (label QR).
    //   Receipt mode -> printer struk ESC/POS untuk kertas continuous.
    // Job TSPL/CPCL yang dikirim saat printer dalam Receipt mode dicetak
    // sebagai TEKS MENTAH baris-per-baris (bukti: semua foto). Job teks biasa
    // dalam Label mode diabaikan (blank). Jadi bahasa harus sesuai mode:
    // struk = ESC/POS dan printer WAJIB dalam Receipt mode (lihat hint UI di
    // SettingsView + EditPenjualanSheet). Salah mode = salah output, dan itu
    // masalah prosedur tombol, BUKAN bug bytes.
    // Hanya perintah ESC/POS paling universal: ESC @, ESC a n, GS ! n,
    // teks + LF. Tanpa CUT (tak ada cutter). Feed sobek via LF kosong akhir.
    static func generateESCPOS(order: SalesOrder) -> ReceiptJob {
        // Sanitasi KHUSUS ESC/POS: hanya 0x20-0x7E yang boleh lolos. Byte
        // < 0x20 (termasuk ESC 0x1B!) adalah prefix perintah — teks user yang
        // mengandungnya akan merusak framing. Non-ASCII dibuang (tak ada glyph).
        func clean(_ text: String) -> String {
            String(text.unicodeScalars
                .filter { $0.value >= 0x20 && $0.value <= 0x7E }
                .map { Character($0) })
        }

        var out = Data()
        func raw(_ bytes: UInt8...) { out.append(contentsOf: bytes) }
        func line(_ s: String) {
            // Potong 32 kolom (font A 48mm); akhiri baris dengan LF.
            // LF saja (tanpa CR): CR diabaikan sebagian firmware, LF universal.
            let clipped = String(clean(s).prefix(32))
            out.append(contentsOf: (clipped + "\n").data(using: .ascii) ?? Data())
        }
        func padded(left: String, right: String) {
            let r = clean(right)
            let leftMax = max(0, 32 - r.count - 1)
            let l = String(clean(left).prefix(leftMax))
            let spaces = max(1, 32 - l.count - r.count)
            line(l + String(repeating: " ", count: spaces) + r)
        }
        func dashes() { line(String(repeating: "-", count: 32)) }

        let ESC: UInt8 = 0x1B, GS: UInt8 = 0x1D
        raw(ESC, 0x40) // ESC @ : init

        // Header tengah + judul double-size
        raw(ESC, 0x61, 0x01) // ESC a 1 : center
        raw(GS, 0x21, 0x11)  // GS ! 0x11 : double W+H
        line("OURA STUDIO")
        raw(GS, 0x21, 0x00)  // normal kembali
        line("Handmade by Irma")
        raw(ESC, 0x61, 0x00) // ESC a 0 : left
        dashes()

        // Details
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        padded(left: "Tanggal:", right: df.string(from: order.soldAt))
        padded(left: "Invoice:", right: order.invoiceNo)
        padded(left: "Kasir:", right: "Irma")
        dashes()

        // Items
        padded(left: "Item(Qty)", right: "Subtotal")
        dashes()
        for item in order.items {
            let qtyStr = "\(Int(item.qty))x"
            let name = item.productName ?? "Produk"
            let size = item.sizeLabel ?? "-"
            let title = "\(name) (\(size))"
            let revStr = item.lineRevenue.rupiahFormattedNoSymbol
            if title.count + qtyStr.count + 1 + revStr.count <= 32 {
                padded(left: "\(title) \(qtyStr)", right: revStr)
            } else {
                line(title)
                padded(left: "- \(qtyStr) @ \(item.effectivePrice.rupiahFormattedNoSymbol)", right: revStr)
            }
        }
        dashes()

        // Totals
        let originalTotal = order.items.reduce(0.0) { $0 + ($1.unitPrice * Double($1.qty)) }
        let totalDiscount = order.items.reduce(0.0) { $0 + ($1.discount * Double($1.qty)) }
        padded(left: "Total Belanja:", right: originalTotal.rupiahFormattedNoSymbol)
        if totalDiscount > 0 {
            padded(left: "Diskon:", right: "-\(totalDiscount.rupiahFormattedNoSymbol)")
        }
        padded(left: "Total Bayar:", right: order.displayRevenue.rupiahFormattedNoSymbol)
        let isCash = order.paymentMethod?.lowercased() == "cash"
        if isCash && order.isPaid {
            padded(left: "Bayar:", right: order.displayRevenue.rupiahFormattedNoSymbol)
            padded(left: "Kembali:", right: "0")
        } else {
            padded(left: "Status:", right: order.isPaid ? "LUNAS (\(order.paymentMethod?.uppercased() ?? "CASH"))" : "BELUM LUNAS")
        }
        dashes()

        // Footer tengah
        raw(ESC, 0x61, 0x01)
        line("TERIMA KASIH")
        line("TELAH BERBELANJA")
        raw(ESC, 0x61, 0x00)
        dashes()
        raw(ESC, 0x61, 0x01)
        line("IG : ourastudio20")
        line("TikTok : @ourastudio20")
        raw(ESC, 0x61, 0x00)
        dashes()

        // Feed kosong untuk ruang sobek (tanpa cutter).
        out.append(contentsOf: Array(repeating: UInt8(0x0A), count: 5))

        let lineCount = out.filter { $0 == 0x0A }.count
        let estSeconds = 2.0 + Double(lineCount) * 0.12
        return ReceiptJob(bytes: out, printSecondsEstimate: estSeconds)
    }

    /// Render byte ESC/POS untuk log: ESC/LF/glyph tak-cetak jadi readable.
    nonisolated static func debugESCPOS(_ data: Data) -> String {
        var s = ""
        s.reserveCapacity(data.count + 64)
        for b in data {
            switch b {
            case 0x1B: s += "<ESC>"
            case 0x0A: s += "<LF>\n"
            case 0x0D: s += "<CR>"
            case 0x20...0x7E: s += String(UnicodeScalar(b))
            default: s += String(format: "<%02X>", b)
            }
        }
        return s
    }
}

class ReceiptPDFGenerator {
    static func generatePDF(order: SalesOrder) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Oura Studio",
            kCGPDFContextTitle: "Invoice \(order.invoiceNo)"
        ] as [CFString : Any]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // 57mm is roughly 161.5 pt (72 points per inch, 25.4 mm per inch. 57 * 72 / 25.4 = 161.57 points).
        // Let's use 162 pt width.
        let width: CGFloat = 162
        let lineSpacing: CGFloat = 14
        let totalLines = 26 + (order.items.count * 2) + 8
        let height: CGFloat = CGFloat(totalLines) * lineSpacing
        
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        
        let data = renderer.pdfData { (context) in
            context.beginPage()
            
            var y: CGFloat = 10
            let charLimit = 32
            
            func addCenteredText(_ text: String, font: UIFont) {
                let trimmed = String(text.prefix(charLimit))
                let spaces = max(0, (charLimit - trimmed.count) / 2)
                let padded = String(repeating: " ", count: spaces) + trimmed
                
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphStyle
                ]
                
                let size = (padded as NSString).size(withAttributes: attributes)
                let rect = CGRect(x: 0, y: y, width: width, height: size.height)
                (padded as NSString).draw(in: rect, withAttributes: attributes)
                y += lineSpacing
            }
            
            func addLeftRightText(left: String, right: String, font: UIFont) {
                let leftMax = max(0, charLimit - right.count - 1)
                let leftTrunc = String(left.prefix(leftMax))
                let spaces = max(1, charLimit - leftTrunc.count - right.count)
                let line = leftTrunc + String(repeating: " ", count: spaces) + right
                
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .left
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphStyle
                ]
                
                let size = (line as NSString).size(withAttributes: attributes)
                let rect = CGRect(x: 0, y: y, width: width, height: size.height)
                (line as NSString).draw(in: rect, withAttributes: attributes)
                y += lineSpacing
            }
            
            func addLeftText(_ text: String, font: UIFont) {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .left
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphStyle
                ]
                
                let size = (text as NSString).size(withAttributes: attributes)
                let rect = CGRect(x: 0, y: y, width: width, height: size.height)
                (text as NSString).draw(in: rect, withAttributes: attributes)
                y += lineSpacing
            }
            
            func addSeparator() {
                addCenteredText(String(repeating: "-", count: charLimit), font: UIFont.monospacedSystemFont(ofSize: 7, weight: .regular))
            }
            
            let boldFont = UIFont.monospacedSystemFont(ofSize: 8, weight: .bold)
            let regularFont = UIFont.monospacedSystemFont(ofSize: 7, weight: .regular)
            
            // Header
            addCenteredText("OURA STUDIO", font: boldFont)
            addCenteredText("Handmade by Irma", font: regularFont)
            addSeparator()
            
            // Details
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm"
            addLeftRightText(left: "Tanggal:", right: df.string(from: order.soldAt), font: regularFont)
            addLeftRightText(left: "Invoice:", right: order.invoiceNo, font: regularFont)
            addLeftRightText(left: "Kasir:", right: "Irma", font: regularFont)
            addSeparator()
            
            // Item Header
            addLeftRightText(left: "Item(Qty)", right: "Subtotal", font: boldFont)
            addSeparator()
            
            // Items
            for item in order.items {
                let qtyStr = "\(Int(item.qty))x"
                let name = item.productName ?? "Produk"
                let size = item.sizeLabel ?? "-"
                let title = "\(name) (\(size))"
                let revStr = item.lineRevenue.rupiahFormattedNoSymbol
                
                if title.count + qtyStr.count + 1 + revStr.count <= charLimit {
                    addLeftRightText(left: "\(title) \(qtyStr)", right: revStr, font: regularFont)
                } else {
                    addLeftText(title, font: regularFont)
                    addLeftRightText(left: "  \(qtyStr) x \(item.effectivePrice.rupiahFormattedNoSymbol)", right: revStr, font: regularFont)
                }
            }
            addSeparator()
            
            // Totals
            let originalTotal = order.items.reduce(0.0) { $0 + ($1.unitPrice * Double($1.qty)) }
            let totalDiscount = order.items.reduce(0.0) { $0 + ($1.discount * Double($1.qty)) }
            
            addLeftRightText(left: "Total Belanja:", right: originalTotal.rupiahFormattedNoSymbol, font: regularFont)
            if totalDiscount > 0 {
                addLeftRightText(left: "Diskon:", right: "-\(totalDiscount.rupiahFormattedNoSymbol)", font: regularFont)
            }
            addLeftRightText(left: "Total Bayar:", right: order.displayRevenue.rupiahFormattedNoSymbol, font: boldFont)
            
            let isCash = order.paymentMethod?.lowercased() == "cash"
            if isCash && order.isPaid {
                addLeftRightText(left: "Bayar:", right: order.displayRevenue.rupiahFormattedNoSymbol, font: regularFont)
                addLeftRightText(left: "Kembali:", right: "0", font: regularFont)
            } else {
                addLeftRightText(left: "Status:", right: order.isPaid ? "LUNAS (\(order.paymentMethod?.uppercased() ?? "CASH"))" : "BELUM LUNAS", font: regularFont)
            }
            addSeparator()
            
            // Footer
            addCenteredText("TERIMA KASIH", font: boldFont)
            addCenteredText("TELAH BERBELANJA", font: regularFont)
            addSeparator()
            
            // Social media - 2 lines, no QR codes.
            addCenteredText("IG : ourastudio20", font: regularFont)
            addCenteredText("TikTok : @ourastudio20", font: regularFont)
            addSeparator()
        }
        
        return data
    }
}
