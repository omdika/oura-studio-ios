import Foundation
import Combine

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)
    case conflict(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:             return "URL tidak valid"
        case .unauthorized:           return "Sesi kadaluarsa. Silakan masuk kembali."
        case .serverError(_, let m):  return m
        case .decodingError(let e):   return "Decode error: \(e.localizedDescription)"
        case .networkError(let e):    return "Koneksi gagal: \(e.localizedDescription)"
        case .conflict(let m):        return m
        }
    }
}

class APIService: ObservableObject {
    static let shared = APIService()

    var baseURL: String = "https://oura-backend-seoul-763614853578.asia-northeast3.run.app/api/v1"
    var authToken: String? = nil
    var useMock: Bool = false
    var onUnauthorized: (() -> Void)? = nil

    private var session: URLSession = .shared

    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let fmts: [DateFormatter] = [
                { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"; return f }(),
                { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"; return f }(),
                { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }(),
            ]
            for fmt in fmts {
                if let d = fmt.date(from: str) { return d }
            }
            if let d = ISO8601DateFormatter().date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Cannot parse date: \(str)")
        }
        return d
    }()

    private lazy var encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - Core HTTP helpers

    private func buildRequest(_ method: String, path: String, bodyData: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = bodyData
        return req
    }

    private func execute(_ method: String, path: String, bodyData: Data? = nil) async throws -> Data {
        do {
            let req = try buildRequest(method, path: path, bodyData: bodyData)
            let (data, response) = try await session.data(for: req)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 401 {
                    DispatchQueue.main.async { self.onUnauthorized?() }
                    throw APIError.unauthorized
                }
                if http.statusCode == 409 {
                    let msg = (try? decoder.decode([String: String].self, from: data))?["detail"] ?? "Konflik"
                    throw APIError.conflict(msg)
                }
                if http.statusCode >= 400 {
                    let msg = (try? decoder.decode([String: String].self, from: data))?["detail"] ?? "Server error"
                    throw APIError.serverError(http.statusCode, msg)
                }
            }
            return data
        } catch let e as APIError { throw e }
        catch { throw APIError.networkError(error) }
    }

    // Central decode with detailed console logging on failure.
    private func loggedDecode<T: Decodable>(_ type: T.Type, from data: Data, path: String) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch let e as DecodingError {
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            var detail = ""
            switch e {
            case .keyNotFound(let key, let ctx):
                detail = "keyNotFound '\(key.stringValue)' at [\(ctx.codingPath.map(\.stringValue).joined(separator: "."))]"
            case .valueNotFound(let t, let ctx):
                detail = "valueNotFound \(t) at [\(ctx.codingPath.map(\.stringValue).joined(separator: "."))]"
            case .typeMismatch(let t, let ctx):
                detail = "typeMismatch expected \(t) at [\(ctx.codingPath.map(\.stringValue).joined(separator: "."))]"
            case .dataCorrupted(let ctx):
                detail = "dataCorrupted: \(ctx.debugDescription)"
            @unknown default:
                detail = "\(e)"
            }
            print("🔴 [API] DecodingError \(path) → \(type): \(detail)")
            print("🔴 [API] Raw response: \(raw.prefix(800))")
            throw APIError.decodingError(NSError(
                domain: "APIDecoding",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: detail]
            ))
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        let data = try await execute("GET", path: path)
        return try loggedDecode(T.self, from: data, path: path)
    }

    private func post<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        let data = try await execute("POST", path: path, bodyData: try encoder.encode(body))
        return try loggedDecode(T.self, from: data, path: path)
    }

    private func postVoid<B: Encodable>(path: String, body: B) async throws {
        _ = try await execute("POST", path: path, bodyData: try encoder.encode(body))
    }

    private func postNoBody<T: Decodable>(path: String) async throws -> T {
        let data = try await execute("POST", path: path)
        return try loggedDecode(T.self, from: data, path: path)
    }

    private func postNoBodyVoid(path: String) async throws {
        _ = try await execute("POST", path: path)
    }

    private func patch<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        let data = try await execute("PATCH", path: path, bodyData: try encoder.encode(body))
        return try loggedDecode(T.self, from: data, path: path)
    }

    private func delete(path: String) async throws {
        _ = try await execute("DELETE", path: path)
    }

    // MARK: - Auth

    func loginWithGoogle(idToken: String?) async throws -> LoginResponse {
        if useMock { return try await MockAPIService.shared.loginWithGoogle(idToken: idToken) }
        guard let token = idToken else { throw APIError.serverError(0, "Google ID token kosong") }
        return try await post(path: "/auth/google", body: GoogleLoginRequest(idToken: token))
    }

    // MARK: - Materials

    func getMaterials(search: String? = nil) async throws -> [Material] {
        if useMock { return try await MockAPIService.shared.getMaterials(search: search) }
        let q = search.flatMap { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) }.map { "?search=\($0)" } ?? ""
        return try await get(path: "/materials\(q)")
    }

    func getMaterial(id: UUID) async throws -> Material {
        if useMock { return try await MockAPIService.shared.getMaterial(id: id) }
        return try await get(path: "/materials/\(id)")
    }

    func createMaterial(_ req: CreateMaterialRequest) async throws -> Material {
        if useMock { return try await MockAPIService.shared.createMaterial(req) }
        return try await post(path: "/materials", body: req)
    }

    func patchMaterial(id: UUID, _ req: PatchMaterialRequest) async throws -> Material {
        if useMock { return try await MockAPIService.shared.patchMaterial(id: id, req) }
        return try await patch(path: "/materials/\(id)", body: req)
    }

    func getPurchases(materialId: UUID) async throws -> [MaterialPurchase] {
        if useMock { return try await MockAPIService.shared.getPurchases(materialId: materialId) }
        return try await get(path: "/materials/\(materialId)/purchases")
    }

    func createPurchase(materialId: UUID, _ req: CreatePurchaseRequest) async throws -> MaterialPurchase {
        if useMock { return try await MockAPIService.shared.createPurchase(materialId: materialId, req) }
        return try await post(path: "/materials/\(materialId)/purchases", body: req)
    }

    func patchPurchase(materialId: UUID, purchaseId: UUID, _ req: PatchPurchaseRequest) async throws -> MaterialPurchase {
        if useMock { return try await MockAPIService.shared.patchPurchase(materialId: materialId, purchaseId: purchaseId, req) }
        return try await patch(path: "/materials/\(materialId)/purchases/\(purchaseId)", body: req)
    }

    func deletePurchase(materialId: UUID, purchaseId: UUID) async throws {
        if useMock { return try await MockAPIService.shared.deletePurchase(materialId: materialId, purchaseId: purchaseId) }
        try await delete(path: "/materials/\(materialId)/purchases/\(purchaseId)")
    }

    // MARK: - Suppliers

    func getSuppliers(search: String? = nil) async throws -> [Supplier] {
        if useMock { return try await MockAPIService.shared.getSuppliers(search: search) }
        let q = search.flatMap { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) }.map { "?search=\($0)" } ?? ""
        return try await get(path: "/suppliers\(q)")
    }

    func createSupplier(name: String) async throws -> Supplier {
        if useMock { return try await MockAPIService.shared.createSupplier(name: name) }
        return try await post(path: "/suppliers", body: CreateSupplierRequest(name: name))
    }

    // MARK: - Products

    func getProducts() async throws -> [Product] {
        if useMock { return try await MockAPIService.shared.getProducts() }
        return try await get(path: "/products")
    }

    func createProduct(name: String, sku: String? = nil) async throws -> Product {
        if useMock { return try await MockAPIService.shared.createProduct(name: name, sku: sku) }
        return try await post(path: "/products", body: CreateProductRequest(name: name, sku: sku))
    }

    func getProductSizes(sku: String) async throws -> [ProductSizeDetail] {
        if useMock { return try await MockAPIService.shared.getProductSizes(sku: sku) }
        let basic: [ProductSizeBasic] = try await get(path: "/products/\(sku)/sizes")
        let name = await resolveProductName(sku: sku)
        return basic.map { sizeDetailFromBasic($0, sku: sku, productName: name) }
    }

    func createProductSize(sku: String, sizeLabel: String, fabricVariantName: String? = nil, reorderMinQty: Double? = nil) async throws -> ProductSizeDetail {
        if useMock { return try await MockAPIService.shared.createProductSize(sku: sku, sizeLabel: sizeLabel, fabricVariantName: fabricVariantName, reorderMinQty: reorderMinQty) }
        let basic: ProductSizeBasic = try await post(path: "/products/\(sku)/sizes", body: CreateProductSizeRequest(sizeLabel: sizeLabel, fabricVariantName: fabricVariantName, reorderMinQty: reorderMinQty))
        let name = await resolveProductName(sku: sku)
        return sizeDetailFromBasic(basic, sku: sku, productName: name)
    }

    func patchProductSize(sku: String, sizeId: UUID, _ req: PatchProductSizeRequest) async throws -> ProductSizeDetail {
        if useMock { return try await MockAPIService.shared.patchProductSize(sku: sku, sizeId: sizeId, req) }
        let basic: ProductSizeBasic = try await patch(path: "/products/\(sku)/sizes/\(sizeId.uuidString)", body: req)
        let name = await resolveProductName(sku: sku)
        return sizeDetailFromBasic(basic, sku: sku, productName: name)
    }

    func getPriceAdvisor(sku: String, sizeId: UUID, _ req: PriceAdvisorRequest) async throws -> PriceAdvisorResponse {
        if useMock { return try await MockAPIService.shared.getPriceAdvisor(sku: sku, sizeId: sizeId, req) }
        return try await post(path: "/products/\(sku)/sizes/\(sizeId.uuidString)/price-advisor", body: req)
    }

    func patchProduct(sku: String, name: String) async throws -> Product {
        if useMock { return try await MockAPIService.shared.patchProduct(sku: sku, name: name) }
        return try await patch(path: "/products/\(sku)", body: PatchProductRequest(name: name))
    }

    // Soft-archives a product via PATCH (backend requires name alongside is_archived).
    // Do NOT use DELETE — it hard-deletes and cascades to sizes and pattern specs.
    func archiveProduct(sku: String, currentName: String) async throws {
        if useMock { return try await MockAPIService.shared.archiveProduct(sku: sku) }
        let _: Product = try await patch(path: "/products/\(sku)",
                                         body: ArchiveProductRequest(name: currentName, isArchived: true))
    }

    func archiveProductSize(sku: String, sizeId: UUID) async throws {
        if useMock { return try await MockAPIService.shared.archiveProductSize(sku: sku, sizeId: sizeId) }
        let _: ProductSizeBasic = try await patch(path: "/products/\(sku)/sizes/\(sizeId.uuidString)",
                                                   body: PatchProductSizeRequest(isArchived: true))
    }

    func adjustStock(sku: String, sizeId: UUID, qty: Int, reason: String, note: String? = nil) async throws -> ProductSizeDetail {
        if useMock { return try await MockAPIService.shared.adjustStock(sku: sku, sizeId: sizeId, qty: qty, reason: reason, note: note) }
        let basic: ProductSizeBasic = try await post(path: "/products/\(sku)/sizes/\(sizeId.uuidString)/stock-adjustments",
                                                     body: StockAdjustmentRequest(qty: qty, reason: reason, note: note))
        let name = await resolveProductName(sku: sku)
        return sizeDetailFromBasic(basic, sku: sku, productName: name)
    }

    func addStockFromBahan(sku: String, sizeId: UUID, qty: Int, specId: UUID) async throws -> ProductSizeDetail {
        if useMock { return try await MockAPIService.shared.addStockFromBahan(sku: sku, sizeId: sizeId, qty: qty, specId: specId) }
        struct Req: Encodable { let qty: Int; let specId: UUID; enum CodingKeys: String, CodingKey { case qty; case specId = "spec_id" } }
        let basic: ProductSizeBasic = try await post(path: "/products/\(sku)/sizes/\(sizeId.uuidString)/stock-from-bahan",
                                                     body: Req(qty: qty, specId: specId))
        let name = await resolveProductName(sku: sku)
        return sizeDetailFromBasic(basic, sku: sku, productName: name)
    }

    func getMaterialUsage(materialId: UUID) async throws -> [MaterialUsageEntry] {
        if useMock { return try await MockAPIService.shared.getMaterialUsage(materialId: materialId) }
        return []
    }

    func addStockManual(sku: String, sizeId: UUID, qty: Int, materialId: UUID, cutWidthCm: Double, cutLengthCm: Double) async throws -> ProductSizeDetail {
        if useMock { return try await MockAPIService.shared.addStockManual(sku: sku, sizeId: sizeId, qty: qty, materialId: materialId, cutWidthCm: cutWidthCm, cutLengthCm: cutLengthCm) }
        struct Req: Encodable {
            let qty: Int; let materialId: UUID; let cutWidthCm: Double; let cutLengthCm: Double
            enum CodingKeys: String, CodingKey { case qty; case materialId = "material_id"; case cutWidthCm = "cut_width_cm"; case cutLengthCm = "cut_length_cm" }
        }
        let basic: ProductSizeBasic = try await post(path: "/products/\(sku)/sizes/\(sizeId.uuidString)/stock-manual",
                                                     body: Req(qty: qty, materialId: materialId, cutWidthCm: cutWidthCm, cutLengthCm: cutLengthCm))
        let name = await resolveProductName(sku: sku)
        return sizeDetailFromBasic(basic, sku: sku, productName: name)
    }

    func getAllProductSizes() async throws -> [ProductSizeDetail] {
        if useMock { return try await MockAPIService.shared.getAllProductSizes() }
        let products = try await getProducts()
        var all: [ProductSizeDetail] = []
        for p in products {
            let basic: [ProductSizeBasic] = (try? await get(path: "/products/\(p.sku)/sizes")) ?? []
            all.append(contentsOf: basic.map { sizeDetailFromBasic($0, sku: p.sku, productName: p.name) })
        }
        return all
    }

    // Converts a flat ProductSizeBasic (list endpoint format) to the enriched ProductSizeDetail
    // the UI expects. stock breakdown fields (production/manual) are not available in list responses.
    private func sizeDetailFromBasic(_ basic: ProductSizeBasic, sku: String, productName: String) -> ProductSizeDetail {
        ProductSizeDetail(
            id: basic.id,
            productId: basic.productId,
            productSku: sku,
            productName: productName,
            sizeLabel: basic.sizeLabel,
            fabricVariantName: basic.fabricVariantName,
            reorderMinQty: basic.reorderMinQty,
            isArchived: basic.isArchived,
            currentStockQty: basic.currentStockQty,
            productionStockQty: basic.productionStockQty ?? 0,
            manualStockQty: basic.manualStockQty ?? 0,
            latestHppBreakdown: basic.latestHppBreakdown,
            sellingPrice: basic.sellingPrice,
            marginPct: basic.marginPct
        )
    }

    // Looks up a product's display name from /products by SKU. Falls back to the SKU if not found.
    private func resolveProductName(sku: String) async -> String {
        let products: [Product] = (try? await get(path: "/products")) ?? []
        return products.first(where: { $0.sku == sku })?.name ?? sku
    }

    // MARK: - Pattern Specs

    func getPatternSpecs(productId: UUID? = nil, size: String? = nil, fabricMaterialId: UUID? = nil) async throws -> [PatternSpec] {
        if useMock { return try await MockAPIService.shared.getPatternSpecs(productId: productId, size: size, fabricMaterialId: fabricMaterialId) }
        var params: [String] = []
        if let p = productId { params.append("product_id=\(p)") }
        if let s = size { params.append("size=\(s)") }
        if let f = fabricMaterialId { params.append("fabric_material_id=\(f)") }
        let q = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        let raw: [BackendPatternSpec] = try await get(path: "/pattern-specs\(q)")
        return try await enrichPatternSpecs(raw)
    }

    func createOrUpdatePatternSpec(_ req: CreatePatternSpecRequest) async throws -> PatternSpec {
        if useMock { return try await MockAPIService.shared.createOrUpdatePatternSpec(req) }

        guard !req.fabrics.isEmpty else {
            throw APIError.serverError(400, "Pilih setidaknya satu kain untuk resep ini")
        }

        let backendReq = BackendCreatePatternSpecRequest(
            productSizeId: req.productSizeId,
            fabrics: req.fabrics.map { f in
                BackendCreatePatternSpecRequest.FabricLayerRequest(
                    materialId: f.materialId,
                    cutWidthCm: f.cutWidthCm,
                    cutHeightCm: f.cutLengthCm,  // UI "panjang" = backend "height"
                    rotationAllowed: f.rotationAllowed,
                    fabricLabel: nil
                )
            },
            estLaborMinutes: req.estLaborMinutes,
            components: req.components
        )

        let raw: BackendPatternSpec = try await post(path: "/pattern-specs", body: backendReq)
        let enriched = try await enrichPatternSpecs([raw])
        guard let spec = enriched.first else { throw APIError.serverError(0, "Gagal memuat resep baru") }
        return spec
    }

    func deletePatternSpec(id: UUID) async throws {
        if useMock { return try await MockAPIService.shared.deletePatternSpec(id: id) }
        try await delete(path: "/pattern-specs/\(id)")
    }

    func getPatternSpecsForSize(productSku: String, sizeLabel: String) async throws -> [PatternSpec] {
        if useMock { return try await MockAPIService.shared.getPatternSpecsForSize(productSku: productSku, sizeLabel: sizeLabel) }
        let skuEnc  = productSku.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? productSku
        let sizeEnc = sizeLabel.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sizeLabel
        let raw: [BackendPatternSpec] = try await get(path: "/pattern-specs?product_sku=\(skuEnc)&size_label=\(sizeEnc)")
        return try await enrichPatternSpecs(raw)
    }

    // Fetches all products and their sizes, returning a lookup from size UUID to (Product, ProductSizeBasic).
    // Used by enrichPatternSpecs and suggestLayouts to resolve product/size names from IDs.
    private func fetchSizeToProductMap() async throws -> [UUID: (product: Product, size: ProductSizeBasic)] {
        let products: [Product] = try await get(path: "/products")
        var sizeToProduct: [UUID: (product: Product, size: ProductSizeBasic)] = [:]
        await withTaskGroup(of: [(Product, ProductSizeBasic)].self) { group in
            for product in products {
                let sku = product.sku
                let prod = product
                group.addTask {
                    let sizes: [ProductSizeBasic] = (try? await self.get(path: "/products/\(sku)/sizes")) ?? []
                    return sizes.map { (prod, $0) }
                }
            }
            for await pairs in group {
                for (product, size) in pairs {
                    sizeToProduct[size.id] = (product: product, size: size)
                }
            }
        }
        return sizeToProduct
    }

    // Joins raw backend specs with products/sizes to produce fully-enriched PatternSpec objects.
    // Backend /products/{sku}/sizes returns a flat format (ProductSizeBasic), not the full ProductSizeDetail.
    // v2.15+: material names come embedded in each BackendPatternFabric; separate materials fetch only needed for components.
    private func enrichPatternSpecs(_ raw: [BackendPatternSpec]) async throws -> [PatternSpec] {
        guard !raw.isEmpty else { return [] }

        async let sizeMapTask = fetchSizeToProductMap()
        async let materialsTask: [Material] = get(path: "/materials")
        let (sizeToProduct, materials) = try await (sizeMapTask, materialsTask)

        let matNames = Dictionary(uniqueKeysWithValues: materials.map { ($0.id, $0.name) })

        return raw.compactMap { spec in
            guard let entry = sizeToProduct[spec.productSizeId] else { return nil }

            let fabrics = spec.fabrics.map { f in
                PatternFabric(
                    id: f.id,
                    materialId: f.materialId,
                    materialName: f.materialName,
                    cutLengthCm: f.cutHeightCm,  // backend "height" = UI "panjang/length"
                    cutWidthCm: f.cutWidthCm,
                    rotationAllowed: f.rotationAllowed
                )
            }

            let comps = spec.components.map { c in
                PatternComponent(
                    id: c.id,
                    patternSpecId: spec.id,
                    materialId: c.materialId,
                    materialName: matNames[c.materialId] ?? "Hardware",
                    qtyPerUnit: c.qtyPerUnit
                )
            }

            return PatternSpec(
                id: spec.id,
                productSizeId: spec.productSizeId,
                productName: entry.product.name,
                productSku: entry.product.sku,
                sizeLabel: entry.size.sizeLabel,
                fabrics: fabrics,
                estLaborMinutes: spec.estLaborMinutes,
                isActive: spec.isActive,
                effectiveFrom: spec.effectiveFrom,
                effectiveTo: spec.effectiveTo,
                components: comps,
                usedInBatchCount: spec.usedInBatchCount
            )
        }
    }

    // MARK: - Optimizer

    func suggestLayouts(_ req: SuggestOptimizerRequest) async throws -> [OptimizerLayout] {
        if useMock { return try await MockAPIService.shared.suggestLayouts(req) }
        let resp: BackendSuggestOptimizerResponse = try await post(path: "/cutting-optimizer/suggest", body: req)
        let sizeMap = try await fetchSizeToProductMap()
        return resp.layouts.map { raw in
            let items = raw.items.map { item in
                let entry = sizeMap[item.productSizeId]
                return OptimizerLayoutItem(
                    id: UUID(),
                    productSizeId: item.productSizeId,
                    productName: entry?.product.name ?? "Produk",
                    sizeLabel: entry?.size.sizeLabel ?? "-",
                    patternSpecId: item.patternSpecId,
                    orientation: item.orientation,
                    qtySuggested: item.qtySuggested,
                    fabricLengthUsedCm: item.fabricLengthUsedCm,
                    costPerPiece: item.costPerPiece
                )
            }
            return OptimizerLayout(
                id: UUID(),
                strategy: raw.strategy,
                wastePct: raw.wastePct,
                items: items,
                totalQty: items.reduce(0) { $0 + $1.qtySuggested },
                estimatedProfit: nil
            )
        }
    }

    func createLayout(_ req: CreateLayoutRequest) async throws -> CuttingLayout {
        if useMock { return try await MockAPIService.shared.createLayout(req) }
        // Backend returns only {"cutting_layout_id": "..."}, not a full CuttingLayout object.
        // Only the id is used downstream (to create a production batch), so we stub the rest.
        let resp: BackendCreateLayoutResponse = try await post(path: "/cutting-optimizer/layouts", body: req)
        return CuttingLayout(
            id: resp.cuttingLayoutId,
            materialPurchaseId: req.materialPurchaseId,
            materialName: "",
            strategy: req.strategy,
            status: "suggested",
            wastePct: nil,
            totalFabricCost: 0,
            createdAt: Date(),
            items: []
        )
    }

    func discardLayout(id: UUID) async throws {
        if useMock { return try await MockAPIService.shared.discardLayout(id: id) }
        try await postNoBodyVoid(path: "/cutting-optimizer/layouts/\(id)/discard")
    }

    // MARK: - Production

    func createProductionBatch(cuttingLayoutIds: [UUID] = []) async throws -> ProductionBatch {
        if useMock { return try await MockAPIService.shared.createProductionBatch(cuttingLayoutIds: cuttingLayoutIds) }
        let raw: BackendProductionBatch = try await post(path: "/production-batches", body: CreateProductionBatchRequest(cuttingLayoutIds: cuttingLayoutIds))
        return try await enrichProductionBatches([raw])[0]
    }

    func updateBatchItem(batchId: UUID, itemId: UUID, qtyActual: Int) async throws -> ProductionBatchItem {
        if useMock { return try await MockAPIService.shared.updateBatchItem(batchId: batchId, itemId: itemId, qtyActual: qtyActual) }
        let raw: BackendProductionBatchItem = try await patch(path: "/production-batches/\(batchId)/items/\(itemId)", body: UpdateBatchItemRequest(qtyActual: qtyActual))
        let sizeMap = try await fetchSizeToProductMap()
        let entry = raw.productSizeId.flatMap { sizeMap[$0] }
        let hppFabricRaw = raw.hppFabric ?? 0
        let effectiveHppFabric = hppFabricRaw > 0 ? hppFabricRaw : (raw.fabricCostPerPiece ?? 0)
        return ProductionBatchItem(
            id: raw.id,
            productionBatchId: batchId,
            productSizeId: raw.productSizeId,
            productName: entry?.product.name ?? "Produk",
            sizeLabel: entry?.size.sizeLabel ?? "-",
            patternSpecId: raw.patternSpecId,
            qtyActual: raw.qtyActual,
            qtySuggested: raw.qtySuggested,
            hppFabric: effectiveHppFabric,
            hppPooledMaterial: raw.hppPooledMaterial ?? 0,
            hppHardware: raw.hppHardware ?? 0,
            hppLabor: raw.hppLabor ?? 0,
            hppOverhead: raw.hppOverhead ?? 0,
            hppTotal: raw.hppTotal ?? 0,
            latestHppBreakdown: entry?.size.latestHppBreakdown
        )
    }

    func confirmBatch(id: UUID) async throws {
        if useMock { return try await MockAPIService.shared.confirmBatch(id: id) }
        try await postNoBodyVoid(path: "/production-batches/\(id)/confirm")
    }

    func getProductionBatch(id: UUID) async throws -> ProductionBatch {
        if useMock { return try await MockAPIService.shared.getProductionBatch(id: id) }
        let raw: BackendProductionBatch = try await get(path: "/production-batches/\(id)")
        return try await enrichProductionBatches([raw])[0]
    }

    func getProductionBatches(status: String? = nil) async throws -> [ProductionBatch] {
        if useMock { return try await MockAPIService.shared.getProductionBatches(status: status) }
        let q = status.map { "?status=\($0)" } ?? ""
        let raw: [BackendProductionBatch] = try await get(path: "/production-batches\(q)")
        return try await enrichProductionBatches(raw)
    }

    // Maps raw backend batch items to enriched ProductionBatch objects with product/size names.
    private func enrichProductionBatches(_ raw: [BackendProductionBatch]) async throws -> [ProductionBatch] {
        guard !raw.isEmpty else { return [] }
        let sizeMap = raw.flatMap { $0.items }.isEmpty ? [:] : try await fetchSizeToProductMap()
        return raw.map { batch in
            let items = batch.items.map { item in
                let entry = item.productSizeId.flatMap { sizeMap[$0] }
                // hpp_* fields are 0 in draft — use fabric_cost_per_piece as hppFabric estimate
                let hppFabricRaw = item.hppFabric ?? 0
                let fabricCost   = item.fabricCostPerPiece ?? 0
                let effectiveHppFabric = hppFabricRaw > 0 ? hppFabricRaw : fabricCost
                return ProductionBatchItem(
                    id: item.id,
                    productionBatchId: batch.id,
                    productSizeId: item.productSizeId,
                    productName: entry?.product.name ?? "Produk",
                    sizeLabel: entry?.size.sizeLabel ?? "-",
                    patternSpecId: item.patternSpecId,
                    qtyActual: item.qtyActual,
                    qtySuggested: item.qtySuggested,
                    hppFabric: effectiveHppFabric,
                    hppPooledMaterial: item.hppPooledMaterial ?? 0,
                    hppHardware: item.hppHardware ?? 0,
                    hppLabor: item.hppLabor ?? 0,
                    hppOverhead: item.hppOverhead ?? 0,
                    hppTotal: item.hppTotal ?? 0,
                    latestHppBreakdown: entry?.size.latestHppBreakdown
                )
            }
            return ProductionBatch(
                id: batch.id,
                cuttingLayoutIds: batch.cuttingLayoutIds,
                cuttingLayoutStrategy: batch.cuttingLayoutStrategy,
                materialName: batch.materialName,
                producedAt: batch.producedAt,
                status: batch.status,
                notes: batch.notes,
                items: items
            )
        }
    }

    func deleteProductionBatch(id: UUID) async throws {
        if useMock { return try await MockAPIService.shared.deleteProductionBatch(id: id) }
        try await delete(path: "/production-batches/\(id)")
    }

    // MARK: - Sales

    func getSalesOrders() async throws -> [SalesOrder] {
        if useMock { return try await MockAPIService.shared.getSalesOrders() }
        return try await get(path: "/sales-orders")
    }

    func getSalesOrder(id: UUID) async throws -> SalesOrder {
        if useMock { return try await MockAPIService.shared.getSalesOrder(id: id) }
        return try await get(path: "/sales-orders/\(id)")
    }

    func createSalesOrder(_ req: CreateSalesOrderRequest) async throws -> SalesOrder {
        if useMock { return try await MockAPIService.shared.createSalesOrder(req) }
        return try await post(path: "/sales-orders", body: req)
    }

    func markSalesOrderPaid(id: UUID) async throws -> SalesOrder {
        if useMock { return try await MockAPIService.shared.markSalesOrderPaid(id: id) }
        struct StatusBody: Codable { let status: String }
        return try await patch(path: "/sales-orders/\(id)", body: StatusBody(status: "paid"))
    }

    func cancelSalesOrder(id: UUID, reason: String? = nil) async throws -> SalesOrder {
        if useMock { return try await MockAPIService.shared.cancelSalesOrder(id: id, reason: reason) }
        return try await post(path: "/sales-orders/\(id)/cancel", body: CancelSalesOrderRequest(reason: reason))
    }

    func updateSalesOrder(id: UUID, customerName: String?, paymentMethod: String) async throws -> SalesOrder {
        if useMock { return try await MockAPIService.shared.updateSalesOrder(id: id, customerName: customerName, paymentMethod: paymentMethod) }
        struct Body: Codable {
            let customerName: String?
            let paymentMethod: String
            enum CodingKeys: String, CodingKey {
                case customerName = "customer_name"
                case paymentMethod = "payment_method"
            }
        }
        return try await patch(path: "/sales-orders/\(id)", body: Body(customerName: customerName, paymentMethod: paymentMethod))
    }

    func deleteSalesOrder(id: UUID) async throws {
        if useMock { return try await MockAPIService.shared.deleteSalesOrder(id: id) }
        try await delete(path: "/sales-orders/\(id)")
    }

    // MARK: - Reports

    func getDashboard() async throws -> DashboardSummary {
        if useMock { return try await MockAPIService.shared.getDashboard() }
        return try await get(path: "/reports/dashboard")
    }

    func getSalesReport(from: Date, to: Date, groupBy: String = "day") async throws -> SalesReport {
        if useMock { return try await MockAPIService.shared.getSalesReport(from: from, to: to, groupBy: groupBy) }
        let q = "?from=\(dateFmt.string(from: from))&to=\(dateFmt.string(from: to))&group_by=\(groupBy)"
        return try await get(path: "/reports/sales\(q)")
    }

    func getMarginRanking() async throws -> [MarginRankingItem] {
        if useMock { return try await MockAPIService.shared.getMarginRanking() }
        return try await get(path: "/reports/margin-ranking?sort=margin_pct")
    }

    func getStockCard(productSizeId: UUID) async throws -> StockCard {
        if useMock { return try await MockAPIService.shared.getStockCard(productSizeId: productSizeId) }
        return try await get(path: "/reports/stock-card/\(productSizeId)")
    }

    func getWasteByMaterial(from: Date, to: Date) async throws -> [WasteByMaterial] {
        if useMock { return try await MockAPIService.shared.getWasteByMaterial(from: from, to: to) }
        let q = "?from=\(dateFmt.string(from: from))&to=\(dateFmt.string(from: to))"
        return try await get(path: "/reports/waste-by-material\(q)")
    }

    func getLowStock() async throws -> [LowStockAlert] {
        if useMock { return try await MockAPIService.shared.getLowStock() }
        return try await get(path: "/reports/low-stock")
    }

    // MARK: - Settings

    func getSettings() async throws -> [SettingItem] {
        if useMock { return try await MockAPIService.shared.getSettings() }
        return try await get(path: "/settings")
    }

    func patchSetting(key: String, value: Double) async throws -> SettingItem {
        if useMock { return try await MockAPIService.shared.patchSetting(key: key, value: value) }
        return try await patch(path: "/settings", body: PatchSettingRequest(key: key, value: value))
    }
}
