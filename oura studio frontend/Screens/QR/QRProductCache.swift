import Foundation
import Combine

/// v3.68 — Instant Scan Cache: katalog `ProductSizeDetail` lokal agar scan QR
/// resolve sinkron (<50ms) tanpa `GET /product-sizes/{id}` per scan.
///
/// Pola POS standar: capture (instan dari cache) → validate (background
/// revalidation) → post (backend tetap validator final saat POST /sales-orders).
/// Frontend-only, zero backend changes. Kompatibel mundur dengan label `oura:UUID`.
@MainActor
final class QRProductCache: ObservableObject {
    static let shared = QRProductCache()

    @Published private(set) var byId: [UUID: ProductSizeDetail] = [:]
    @Published private(set) var lastSyncAt: Date? = nil
    @Published private(set) var isLoading = false

    /// TTL katalog penuh (detik). Default 5 menit sesuai spek v3.68.
    var ttl: TimeInterval = 300
    /// Interval minimum antar revalidasi per-id (detik). Mencegah burst saat scan cepat.
    var perIdRevalidateInterval: TimeInterval = 60

    private var inFlight = false
    private var lastRevalidateAt: [UUID: Date] = [:]

    struct ParsedQR {
        let id: UUID
        /// Harga embedded dari label `oura2:` (rupiah). Nil untuk label lama.
        let embeddedPrice: Double?
    }

    var isFresh: Bool {
        guard let t = lastSyncAt else { return false }
        return Date().timeIntervalSince(t) < ttl
    }

    var count: Int { byId.count }

    /// Teks umur cache untuk chip status, mis. "baru saja" / "3 mnt lalu".
    var ageText: String {
        guard let t = lastSyncAt else { return byId.isEmpty ? "belum dimuat" : "waktu tak diketahui" }
        let s = Int(Date().timeIntervalSince(t))
        if s < 10 { return "baru saja" }
        if s < 60 { return "\(s) dtk lalu" }
        return "\(s / 60) mnt lalu"
    }

    // MARK: - Preload

    /// Muat katalog. v3.69: coba slim dulu (payload ~10× lebih kecil); 404 =
    /// backend lama → full; id yang belum dikenal → full fetch sekali.
    /// Best-effort: gagal jaringan tidak melempar, cache lama tetap dipakai.
    func preload(api: APIService, force: Bool = false) async {
        if inFlight { return }
        if !force && isFresh { return }
        inFlight = true
        isLoading = true
        defer { inFlight = false; isLoading = false }
        do {
            if let slim = try? await api.getSlimProductSizes(), !slim.isEmpty {
                let unknown = applySlimItems(slim)
                if unknown.isEmpty && !byId.isEmpty {
                    lastSyncAt = Date()
                    return
                }
                // Ada id baru (produk baru pasca-cache) → lengkapi via full fetch.
            }
            let all = try await api.getAllProductSizes()
            upsertMany(all)
            lastSyncAt = Date()
        } catch {
            // Best-effort: pertahankan cache lama agar scan tetap instan offline.
        }
    }

    func lookup(_ id: UUID) -> ProductSizeDetail? { byId[id] }

    func upsert(_ d: ProductSizeDetail) { byId[d.id] = d }

    func upsertMany(_ arr: [ProductSizeDetail]) {
        for d in arr { byId[d.id] = d }
    }

    /// Invalidasi proaktif — panggil setelah checkout sukses / adjustStock /
    /// confirmBatch agar preload berikutnya fresh (spek v3.68 §5).
    func invalidate() { lastSyncAt = nil }

    // MARK: - Background revalidation

    func shouldRevalidate(_ id: UUID) -> Bool {
        guard let t = lastRevalidateAt[id] else { return true }
        return Date().timeIntervalSince(t) >= perIdRevalidateInterval
    }

    /// Tandai id baru saja di-fetch (mis. fallback cache-miss) agar tidak
    /// langsung di-revalidasi ulang.
    func noteRevalidated(_ id: UUID) {
        lastRevalidateAt[id] = Date()
    }

    /// Revalidasi batch id (paralel, max 50). Meng-update cache in-place.
    /// Mengembalikan detail fresh per id. Tidak menyentuh `lastSyncAt`
    /// (itu umur katalog penuh, bukan revalidasi parsial).
    @discardableResult
    func revalidate(ids: [UUID], api: APIService) async -> [UUID: ProductSizeDetail] {
        let unique = Array(Set(ids).prefix(50))
        guard !unique.isEmpty else { return [:] }
        var out: [UUID: ProductSizeDetail] = [:]
        await withTaskGroup(of: (UUID, ProductSizeDetail?).self) { group in
            for id in unique {
                group.addTask { (id, try? await api.getProductSizeById(id: id)) }
            }
            for await (id, detail) in group {
                if let d = detail { out[id] = d }
            }
        }
        let now = Date()
        for (id, d) in out {
            byId[id] = d
            lastRevalidateAt[id] = now
        }
        return out
    }

    /// Patch entri full dengan field slim (stok, harga, identitas, arsip).
    /// HPP/images/manual dipertahankan. Mengembalikan id slim yang belum ada
    /// di cache (butuh full fetch susulan). Id yang di-patch ditandai revalidated.
    @discardableResult
    func applySlimItems(_ slim: [ProductSizeSlim]) -> [UUID] {
        var unknown: [UUID] = []
        let now = Date()
        for s in slim {
            if let existing = byId[s.id] {
                byId[s.id] = existing.patched(with: s)
                lastRevalidateAt[s.id] = now
            } else {
                unknown.append(s.id)
            }
        }
        return unknown
    }

    /// v3.69: revalidasi via batch slim (`scan-resolve`, di-chunk ≤50/chunk);
    /// backend lama → fallback N× full (backend lama menjawab 404 bila path tak
    /// dikenal, atau 422 karena `scan-resolve` tertelan path `{size_id}`);
    /// error lain → [:] (panggil treat sebagai skip).
    /// Id di `missing_ids` (dihapus server) dikeluarkan dari cache.
    @discardableResult
    func revalidateSmart(ids: [UUID], api: APIService) async -> [UUID: ProductSizeDetail] {
        let unique = Array(Set(ids))
        guard !unique.isEmpty else { return [:] }
        do {
            var slimItems: [ProductSizeSlim] = []
            var idx = 0
            while idx < unique.count {
                let chunk = Array(unique[idx..<min(idx + 50, unique.count)])
                let resp = try await api.scanResolve(ids: chunk)
                for m in resp.missingIds { byId.removeValue(forKey: m) }
                slimItems.append(contentsOf: resp.items)
                idx += 50
            }
            let unknown = applySlimItems(slimItems)
            if !unknown.isEmpty {
                await revalidate(ids: unknown, api: api) // full untuk id baru
            }
            var out: [UUID: ProductSizeDetail] = [:]
            for id in unique {
                if let d = byId[id] { out[id] = d }
            }
            return out
        } catch let e as APIError {
            if case .serverError(let code, _) = e, code == 404 || code == 422 {
                return await revalidate(ids: unique, api: api)
            }
            return [:]
        } catch {
            return [:]
        }
    }

    /// Refresh 1 id dari server + upsert ke cache. Titik tulis stok
    /// (stock-in, quick-adjust, dsb.) wajib memanggil ini agar scan
    /// berikutnya langsung melihat stok/harga terbaru tanpa tunggu TTL.
    @discardableResult
    func refreshOne(id: UUID, api: APIService) async -> ProductSizeDetail? {
        guard let fresh = try? await api.getProductSizeById(id: id) else { return nil }
        upsert(fresh)
        noteRevalidated(id)
        return fresh
    }

    // MARK: - QR parsing (kombinasi, backward-compatible)

    /// - `oura:<uuid>` (label lama, v3.17)
    /// - `oura2:<uuid>:<price>` (label baru v3.68, harga rupiah; segmen nama
    ///   tambahan diabaikan agar generator bebas menambah field)
    /// - Selain itu → nil (scanner abaikan, kamera jalan terus).
    static func parseQR(_ raw: String) -> ParsedQR? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("oura2:") {
            let body = String(s.dropFirst(6))
            let parts = body.split(separator: ":", omittingEmptySubsequences: false)
            guard let first = parts.first, let uuid = UUID(uuidString: String(first)) else { return nil }
            var price: Double? = nil
            if parts.count >= 2 {
                let pStr = String(parts[1]).replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                if let p = Double(pStr), p > 0 { price = p }
            }
            return ParsedQR(id: uuid, embeddedPrice: price)
        }
        guard s.hasPrefix("oura:") else { return nil }
        guard let uuid = UUID(uuidString: String(s.dropFirst(5))) else { return nil }
        return ParsedQR(id: uuid, embeddedPrice: nil)
    }

    func parseQR(_ raw: String) -> ParsedQR? { Self.parseQR(raw) }

    // MARK: - v3.69 Label payload

    /// Payload QR untuk label cetak. Bila `includePrice` ON (toggle "Sertakan
    /// Harga") dan harga ada → `oura2:<uuid>:<rupiah>` (label v2: render instan
    /// tanpa cache); selain itu `oura:<uuid>` (label lama, kompatibel mundur).
    static func qrPayload(sizeId: UUID, sellingPrice: Double?, includePrice: Bool) -> String {
        if includePrice, let p = sellingPrice, p > 0 {
            return "oura2:\(sizeId.uuidString):\(Int(p))"
        }
        return "oura:\(sizeId.uuidString)"
    }
}
