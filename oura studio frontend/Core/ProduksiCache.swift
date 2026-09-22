import Foundation
import Combine

// MARK: - Cache untuk section Produksi (Bahan / Resep / Optimasi / Produksi)
// Setiap tab sebelumnya me-recreate view via ProduksiTabView.switch → @State hilang → selalu full reload.
// Dengan cache ini, switching tab menampilkan data instan dari memory, lalu soft-reload di background.

final class ProduksiCache: ObservableObject {
    // TTL untuk menentukan apakah data masih fresh. Soft-reload tetap jalan meski valid, hanya tanpa spinner.
    private let ttl: TimeInterval = 60

    struct Timestamped<T> {
        var value: T?
        var timestamp: Date?
        var isValid: Bool {
            guard let ts = timestamp else { return false }
            return Date().timeIntervalSince(ts) < 60
        }
    }

    // Bahan
    @Published var bahan = Timestamped<[Material]>()
    // Resep
    @Published var resep = Timestamped<[PatternSpec]>()
    // Optimasi
    struct OptimasiData {
        let materials: [Material]
        let specs: [PatternSpec]
        let settings: [SettingItem]
        let fabricPurchases: [(material: Material, purchase: MaterialPurchase)]
    }
    @Published var optimasi = Timestamped<OptimasiData>()
    // Produksi
    struct ProduksiData {
        let batches: [ProductionBatch]
        let materials: [Material]
        let specs: [PatternSpec]
        let settings: [SettingItem]
    }
    @Published var produksi = Timestamped<ProduksiData>()

    // MARK: - Helpers
    func setBahan(_ v: [Material]) { bahan = Timestamped(value: v, timestamp: Date()) }
    func setResep(_ v: [PatternSpec]) { resep = Timestamped(value: v, timestamp: Date()) }
    func setOptimasi(materials: [Material], specs: [PatternSpec], settings: [SettingItem], fabricPurchases: [(Material, MaterialPurchase)]) {
        optimasi = Timestamped(value: OptimasiData(materials: materials, specs: specs, settings: settings, fabricPurchases: fabricPurchases), timestamp: Date())
    }
    func setProduksi(batches: [ProductionBatch], materials: [Material], specs: [PatternSpec], settings: [SettingItem]) {
        produksi = Timestamped(value: ProduksiData(batches: batches, materials: materials, specs: specs, settings: settings), timestamp: Date())
    }

    func invalidateAll() {
        bahan = Timestamped(); resep = Timestamped(); optimasi = Timestamped(); produksi = Timestamped()
    }
    func invalidateBahan() { bahan = Timestamped() }
    func invalidateResep() { resep = Timestamped() }
    func invalidateOptimasi() { optimasi = Timestamped() }
    func invalidateProduksi() { produksi = Timestamped() }
}
