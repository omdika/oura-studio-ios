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

class ReceiptGenerator {
    static func generateTSPL(order: SalesOrder) -> String {
        var body = ""
        
        var y = 5
        let charLimit = 32
        
        func addCenteredText(_ text: String) {
            let trimmed = text.prefix(charLimit)
            let spaces = max(0, (charLimit - trimmed.count) / 2)
            let padded = String(repeating: " ", count: spaces) + trimmed
            body += "TEXT 0,\(y),\"2\",0,1,1,\"\(padded)\"\r\n"
            y += 24
        }
        
        func addLeftRightText(left: String, right: String) {
            let leftMax = max(0, charLimit - right.count - 1)
            let leftTrunc = left.prefix(leftMax)
            let spaces = max(1, charLimit - leftTrunc.count - right.count)
            let line = leftTrunc + String(repeating: " ", count: spaces) + right
            body += "TEXT 0,\(y),\"2\",0,1,1,\"\(line)\"\r\n"
            y += 24
        }
        
        func addSeparator() {
            body += "TEXT 0,\(y),\"2\",0,1,1,\"" + String(repeating: "-", count: charLimit) + "\"\r\n"
            y += 24
        }
        
        func addLeftText(_ text: String) {
            body += "TEXT 0,\(y),\"2\",0,1,1,\"\(text.prefix(charLimit))\"\r\n"
            y += 24
        }
        
        // Header
        addCenteredText("OURA STUDIO")
        addCenteredText("Hand Made by Irma")
        addSeparator()
        
        // Details
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        addLeftRightText(left: "Tanggal:", right: df.string(from: order.soldAt))
        addLeftRightText(left: "Invoice:", right: order.invoiceNo)
        addLeftRightText(left: "Kasir:", right: "Irma")
        addSeparator()
        
        // Item Header
        addLeftRightText(left: "Item(Qty)", right: "Subtotal")
        addSeparator()
        
        // Items
        for item in order.items {
            let qtyStr = "\(Int(item.qty))x"
            let name = item.productName ?? "Produk"
            let size = item.sizeLabel ?? "-"
            let title = "\(name) (\(size))"
            let revStr = item.lineRevenue.rupiahFormattedNoSymbol
            
            if title.count + qtyStr.count + 1 + revStr.count <= charLimit {
                addLeftRightText(left: "\(title) \(qtyStr)", right: revStr)
            } else {
                addLeftText(title)
                addLeftRightText(left: "  \(qtyStr) x \(item.effectivePrice.rupiahFormattedNoSymbol)", right: revStr)
            }
        }
        addSeparator()
        
        // Totals
        let originalTotal = order.items.reduce(0.0) { $0 + ($1.unitPrice * Double($1.qty)) }
        let totalDiscount = order.items.reduce(0.0) { $0 + ($1.discount * Double($1.qty)) }
        
        addLeftRightText(left: "Total Belanja:", right: originalTotal.rupiahFormattedNoSymbol)
        if totalDiscount > 0 {
            addLeftRightText(left: "Diskon:", right: "-\(totalDiscount.rupiahFormattedNoSymbol)")
        }
        addLeftRightText(left: "Total Bayar:", right: order.displayRevenue.rupiahFormattedNoSymbol)
        
        let isCash = order.paymentMethod?.lowercased() == "cash"
        if isCash && order.isPaid {
            addLeftRightText(left: "Bayar:", right: order.displayRevenue.rupiahFormattedNoSymbol)
            addLeftRightText(left: "Kembali:", right: "0")
        } else {
            addLeftRightText(left: "Status:", right: order.isPaid ? "LUNAS (\(order.paymentMethod?.uppercased() ?? "CASH"))" : "BELUM LUNAS")
        }
        addSeparator()
        
        // Footer
        addCenteredText("TERIMA KASIH")
        addCenteredText("TELAH BERBELANJA")
        addSeparator()
        
        // Social Media QR Codes
        addCenteredText("[ Instagram ]")
        body += "QRCODE 120,\(y),L,4,A,0,M,2,\"https://www.instagram.com/ourastudio20\"\r\n"
        y += 120
        addCenteredText("ourastudio20")
        addSeparator()
        
        addCenteredText("[ TikTok ]")
        body += "QRCODE 120,\(y),L,4,A,0,M,2,\"https://www.tiktok.com/@ourastudio20\"\r\n"
        y += 120
        addCenteredText("@ourastudio20")
        addSeparator()
        
        // Dynamically calculate height in mm based on y (content height)
        // 8 dots = 1 mm. Let's add 10 mm safety margin so it feeds past the cutter.
        let heightMm = Int(ceil(Double(y) / 8.0)) + 10
        
        var tspl = ""
        tspl += "SIZE 48 mm,\(heightMm) mm\r\n"
        tspl += "GAP 0 mm,0 mm\r\n" // continuous paper, no gap
        tspl += "CLS\r\n"
        tspl += "DIRECTION 1\r\n"
        tspl += "REFERENCE 0,0\r\n"
        
        tspl += body
        
        // Print command
        tspl += "PRINT 1,1\r\n"
        
        // Cut paper
        tspl += "CUT\r\n"
        
        return tspl
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
        let totalLines = 26 + (order.items.count * 2) + 12
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
            addCenteredText("Hand Made by Irma", font: regularFont)
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
            
            addCenteredText("[ Instagram ]", font: boldFont)
            addCenteredText("ourastudio20", font: regularFont)
            addSeparator()
            
            addCenteredText("[ TikTok ]", font: boldFont)
            addCenteredText("@ourastudio20", font: regularFont)
            addSeparator()
        }
        
        return data
    }
}
