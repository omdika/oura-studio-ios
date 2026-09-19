import AudioToolbox
import UIKit

/// Centralised haptic + audible feedback for QR scan results.
/// Success = single high beep + success haptic.
/// Error   = low beep (double) + error haptic — clearly distinguishable saat hectic.
enum ScanFeedback {
    /// Dipanggil ketika QR berhasil discan dan produk valid / stok tersedia.
    static func success() {
        // Haptic — light success
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // Audible — short high beep (SMSReceived_Alert-like, ID 1054)
        AudioServicesPlaySystemSound(1054)
        // Second vibrate layer for extra punch on silent-adjacent devices
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Dipanggil ketika QR discan tapi gagal (stok habis / stok penuh / produk tidak ditemukan / QR invalid).
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        // Audible error — lower/longer tone (ID 1053) — kontras dengan 1054
        AudioServicesPlaySystemSound(1053)
        // Double-tap pattern biar beda jelas dari success (single beep)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            AudioServicesPlaySystemSound(1053)
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}
