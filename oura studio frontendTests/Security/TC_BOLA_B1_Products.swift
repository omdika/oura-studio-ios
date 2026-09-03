// Spec: doc/test/api1_bola_test_spec.md
import XCTest
@testable import oura_studio_frontend

final class TC_BOLA_B1_Products: XCTestCase {
    let baseURL = URL(string: "https://ourastudiobackendseoul-763614853578.asia-northeast3.run.app/api/v1")!
    var ownerToken: String = ""
    var attackerToken: String = ""
    
    // Sample authoritative resource UUID and SKU stored for testing
    var sampleSKU = "SCRUNCHIE"
    var sampleSizeID = "s1111-uuid-ukuran-m"

    override func setUpWithError() throws {
        super.setUp()
        
        guard let ownerEnv = ProcessInfo.processInfo.environment["JWT_OWNER"] ?? KeychainManager.loadToken(), !ownerEnv.isEmpty else {
            XCTFail("PRE-REQUISITE FAILED: JWT_OWNER is missing. Set it in Xcode environment variables or log in first on simulator.")
            throw NSError(domain: "TC_BOLA_B1_Products", code: 1, userInfo: [NSLocalizedDescriptionKey: "JWT_OWNER is missing"])
        }
        guard let attackerEnv = ProcessInfo.processInfo.environment["JWT_ATTACKER"], !attackerEnv.isEmpty else {
            XCTFail("PRE-REQUISITE FAILED: JWT_ATTACKER environment variable is missing. Set it in active scheme.")
            throw NSError(domain: "TC_BOLA_B1_Products", code: 2, userInfo: [NSLocalizedDescriptionKey: "JWT_ATTACKER is missing"])
        }
        
        ownerToken = ownerEnv
        attackerToken = attackerEnv
    }
    
    // Helper untuk mengambil SKU produk & size ID nyata dari backend agar terhindar dari 404 Not Found
    private func fetchRealProductAndSize() async -> (sku: String, sizeId: String) {
        let url = URL(string: "\(baseURL.absoluteString)/products")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(ownerToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Backend returns list of products. Each has sku and sizes
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let firstProduct = json.first,
                   let realSKU = firstProduct["sku"] as? String {
                    
                    // Fetch sizes for this sku
                    let sizeUrl = URL(string: "\(baseURL.absoluteString)/products/\(realSKU)/sizes")!
                    var sizeReq = URLRequest(url: sizeUrl)
                    sizeReq.setValue("Bearer \(ownerToken)", forHTTPHeaderField: "Authorization")
                    let (sizeData, sizeRes) = try await URLSession.shared.data(for: sizeReq)
                    
                    if let sizeHttp = sizeRes as? HTTPURLResponse, sizeHttp.statusCode == 200 {
                        if let sizesJson = try JSONSerialization.jsonObject(with: sizeData) as? [[String: Any]],
                           let firstSize = sizesJson.first,
                           let realSizeID = firstSize["id"] as? String {
                            print("DEBUG BOLA: Found real SKU -> \(realSKU) and SizeID -> \(realSizeID)")
                            return (realSKU, realSizeID)
                        }
                    }
                }
            }
        } catch {
            print("DEBUG BOLA: Failed to query products/sizes from backend, using sample values.")
        }
        return (sampleSKU, sampleSizeID)
    }

    // MARK: - Kasus Uji B.1.1: Owner GET (Positive Case)
    func testProductSizeGet_AsOwner_ReturnsSuccess() async throws {
        let (realSKU, realSizeID) = await fetchRealProductAndSize()
        let url = URL(string: "\(baseURL.absoluteString)/products/\(realSKU)/sizes/\(realSizeID)")!
        print("DEBUG BOLA: Request URL -> \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(ownerToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertEqual(httpResponse.statusCode, 200, "Owner should easily fetch their own product size detail! Found: \(httpResponse.statusCode)")
    }

    // MARK: - Kasus Uji B.1.2: Attacker GET (Negative Case)
    func testProductSizeGet_AsAttacker_ReturnsForbidden() async throws {
        let (realSKU, realSizeID) = await fetchRealProductAndSize()
        let url = URL(string: "\(baseURL.absoluteString)/products/\(realSKU)/sizes/\(realSizeID)")!
        print("DEBUG BOLA: Request URL -> \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(attackerToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertEqual(httpResponse.statusCode, 403, "Attacker should be forbidden from accessing owner's product size detail! Found: \(httpResponse.statusCode)")
    }

    // MARK: - Kasus Uji B.2.1: Owner PATCH (Positive Case)
    func testProductSizePatch_AsOwner_ReturnsSuccess() async throws {
        let (realSKU, realSizeID) = await fetchRealProductAndSize()
        let url = URL(string: "\(baseURL.absoluteString)/products/\(realSKU)/sizes/\(realSizeID)")!
        print("DEBUG BOLA: Request URL -> \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(ownerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = ["selling_price": 15000]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertTrue(httpResponse.statusCode == 200 || httpResponse.statusCode == 204, 
                      "Owner should successfully update selling price. Found: \(httpResponse.statusCode)")
    }

    // MARK: - Kasus Uji B.2.2: Attacker PATCH (Negative Case)
    func testProductSizePatch_AsAttacker_ReturnsForbidden() async throws {
        let (realSKU, realSizeID) = await fetchRealProductAndSize()
        let url = URL(string: "\(baseURL.absoluteString)/products/\(realSKU)/sizes/\(realSizeID)")!
        print("DEBUG BOLA: Request URL -> \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(attackerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = ["selling_price": 500]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertEqual(httpResponse.statusCode, 403, "Attacker should be forbidden from patching selling price. Found: \(httpResponse.statusCode)")
    }
}
