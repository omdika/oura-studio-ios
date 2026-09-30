import UIKit

struct ImageCompressor {
    /// Kompresi gambar menjadi biner JPEG yang berukuran di bawah maxBytes (default 700 KB).
    /// Dipakai saat upload foto varian — baik take photo langsung (kamera) maupun dari galeri.
    static func compressToJPEG(image: UIImage, maxBytes: Int = 716800) -> Data? {
        // Langsung perkecil dimensi di awal agar foto kamera/galeri resolusi besar
        // tidak perlu iterasi kualitas berkali-kali. Max 1600px di sisi terpanjang.
        var workingImage = image
        let maxDimension: CGFloat = 1600
        let longestSide = max(image.size.width, image.size.height)
        if longestSide > maxDimension && longestSide > 0 {
            let scale = maxDimension / longestSide
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            workingImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        var quality: CGFloat = 1.0
        // Konversi tipe file apa pun (HEIC, PNG) ke JPEG biner dasar
        guard var data = workingImage.jpegData(compressionQuality: quality) else { return nil }

        // Skenario A: Jika sudah di bawah 700 KB, kembalikan langsung
        if data.count <= maxBytes {
            return data
        }

        // Skenario B: Turunkan kualitas biner secara progresif (1.0 -> 0.1)
        while data.count > maxBytes && quality > 0.1 {
            quality -= 0.15
            if let compressedData = workingImage.jpegData(compressionQuality: quality) {
                data = compressedData
            }
        }

        // Skenario C: Jika kualitas 0.1 masih terlalu besar, kurangi resolusi pixel (downscale) secara berulang
        var size = workingImage.size
        while data.count > maxBytes && size.width > 200 {
            size = CGSize(width: size.width * 0.8, height: size.height * 0.8)
            
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let resizedImage = renderer.image { _ in
                workingImage.draw(in: CGRect(origin: .zero, size: size))
            }
            
            quality = 0.8
            if let resizedData = resizedImage.jpegData(compressionQuality: quality) {
                data = resizedData
                // Lakukan kompresi biner lagi pada gambar yang sudah dikecilkan dimensinya
                while data.count > maxBytes && quality > 0.1 {
                    quality -= 0.15
                    if let compressedData = resizedImage.jpegData(compressionQuality: quality) {
                        data = compressedData
                    }
                }
            }
        }
        
        return data.count <= maxBytes ? data : nil
    }
}
