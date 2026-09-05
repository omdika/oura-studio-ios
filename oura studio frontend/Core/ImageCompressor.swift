import UIKit

struct ImageCompressor {
    /// Kompresi gambar menjadi biner JPEG yang berukuran di bawah maxBytes (default 1.8 MB)
    static func compressToJPEG(image: UIImage, maxBytes: Int = 1887436) -> Data? {
        var quality: CGFloat = 1.0
        // Konversi tipe file apa pun (HEIC, PNG) ke JPEG biner dasar
        guard var data = image.jpegData(compressionQuality: quality) else { return nil }
        
        // Skenario A: Jika sudah di bawah 1.8 MB, kembalikan langsung
        if data.count <= maxBytes {
            return data
        }
        
        // Skenario B: Turunkan kualitas biner secara progresif (1.0 -> 0.1)
        while data.count > maxBytes && quality > 0.1 {
            quality -= 0.15
            if let compressedData = image.jpegData(compressionQuality: quality) {
                data = compressedData
            }
        }
        
        // Skenario C: Jika kualitas 0.1 masih terlalu besar, kurangi resolusi pixel (downscale) secara berulang
        var size = image.size
        while data.count > maxBytes && size.width > 200 {
            size = CGSize(width: size.width * 0.8, height: size.height * 0.8)
            
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
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
