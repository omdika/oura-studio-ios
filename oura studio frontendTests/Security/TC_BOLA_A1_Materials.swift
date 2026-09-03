// Spec: doc/test/api1_bola_test_spec.md
import XCTest
@testable import oura_studio_frontend

final class TC_BOLA_A1_Materials: XCTestCase {
    let baseURL = URL(string: "https://ourastudiobackendseoul-763614853578.asia-northeast3.run.app/api/v1")!
    var ownerToken: String = ""
    var attackerToken: String = ""
    
    // Sample authoritative resource UUID stored for testing (Satin Pelangi)
    var sampleMaterialID = "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d"
    var samplePurchaseID = "p9999-uuid-pembelian"

    override func setUpWithError() throws {
        super.setUp()
        
        // Coba ambil token dari Environment Variable, fallback ke Keychain simulator (jika user pernah login di simulator)
        guard let ownerEnv = ProcessInfo.processInfo.environment["JWT_OWNER"] ?? KeychainManager.loadToken(), !ownerEnv.isEmpty else {
            XCTFail("PRE-REQUISITE FAILED: JWT_OWNER is missing. Set it in the Xcode environment variables or log in first on the simulator.")
            throw NSError(domain: "TC_BOLA_A1_Materials", code: 1, userInfo: [NSLocalizedDescriptionKey: "JWT_OWNER is missing"])
        }
        
        // JWT_ATTACKER tetap wajib di-set via env vars untuk simulasi serangan
        guard let attackerEnv = ProcessInfo.processInfo.environment["JWT_ATTACKER"], !attackerEnv.isEmpty else {
            XCTFail("PRE-REQUISITE FAILED: JWT_ATTACKER environment variable is missing. Set it in active scheme to run BOLA negative tests.")
            throw NSError(domain: "TC_BOLA_A1_Materials", code: 2, userInfo: [NSLocalizedDescriptionKey: "JWT_ATTACKER is missing"])
        }
        
        ownerToken = ownerEnv
        attackerToken = attackerEnv
        
        print("DEBUG BOLA: JWT Owner Token loaded -> \(ownerToken.prefix(15))...")
        print("DEBUG BOLA: JWT Attacker Token loaded -> \(attackerToken.prefix(15))...")
    }
    
    // Helper untuk mendeteksi ID material nyata dari database backend agar tidak memicu 404 Not Found
    private func fetchRealMaterialID() async -> String {
        let url = URL(string: "\(baseURL.absoluteString)/materials")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(ownerToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let first = json.first,
                   let realID = first["id"] as? String {
                    print("DEBUG BOLA: Found real material ID from database -> \(realID)")
                    return realID
                }
            }
        } catch {
            print("DEBUG BOLA: Failed to query materials endpoint, falling back to sample UUID.")
        }
        return sampleMaterialID
    }

    // MARK: - Kasus Uji A.1.1: Owner GET (Positive Case)
    func testMaterialsGet_AsOwner_ReturnsSuccess() async throws {
        let realID = await fetchRealMaterialID()
        let url = URL(string: "\(baseURL.absoluteString)/materials/\(realID)")!
        print("DEBUG BOLA: Request URL -> \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(ownerToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertEqual(httpResponse.statusCode, 200, "Owner should easily fetch their own material!")
    }

    // MARK: - Kasus Uji A.1.2: Attacker GET (Negative Case)
    func testMaterialsGet_AsAttacker_ReturnsForbidden() async throws {
        let realID = await fetchRealMaterialID()
        let url = URL(string: "\(baseURL.absoluteString)/materials/\(realID)")!
        print("DEBUG BOLA: Request URL -> \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(attackerToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertTrue(httpResponse.statusCode == 403 || httpResponse.statusCode == 404, 
                      "BOLA Security: Attacker must be forbidden (403) or not find (404) owner's material! Found: \(httpResponse.statusCode)")
    }

    // MARK: - Kasus Uji A.1.3: No Token GET (Negative Case)
    func testMaterialsGet_NoToken_ReturnsUnauthorized() async throws {
        let realID = await fetchRealMaterialID()
        let url = URL(string: "\(baseURL.absoluteString)/materials/\(realID)")!
        print("DEBUG BOLA: Request URL -> \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertEqual(httpResponse.statusCode, 401, "No token should return 401 Unauthorized")
    }

    // MARK: - Kasus Uji A.2.1: Owner PATCH (Positive Case)
    func testMaterialsPatch_AsOwner_ReturnsSuccess() async throws {
        let realID = await fetchRealMaterialID()
        let url = URL(string: "\(baseURL.absoluteString)/materials/\(realID)")!
        print("DEBUG BOLA: Request URL -> \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(ownerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = ["name": "Satin Pelangi Premium"]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertTrue(httpResponse.statusCode == 200 || httpResponse.statusCode == 204, 
                      "Owner should successfully edit material. Found: \(httpResponse.statusCode)")
    }

    // MARK: - Kasus Uji A.2.2: Attacker PATCH (Negative Case)
    func testMaterialsPatch_AsAttacker_ReturnsForbidden() async throws {
        let realID = await fetchRealMaterialID()
        let url = URL(string: "\(baseURL.absoluteString)/materials/\(realID)")!
        print("DEBUG BOLA: Request URL -> \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(attackerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = ["name": "Satin Di-hack"]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertEqual(httpResponse.statusCode, 403, "Attacker should be forbidden from patching material. Found: \(httpResponse.statusCode)")
    }

    // MARK: - Kasus Uji A.3.1: Owner PATCH Purchase (Positive Case)
    func testPurchasePatch_AsOwner_ReturnsSuccess() async throws {
        let realID = await fetchRealMaterialID()
        let url = URL(string: "\(baseURL.absoluteString)/materials/\(realID)/purchases/\(samplePurchaseID)")!
        print("DEBUG BOLA: Request URL -> \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(ownerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = ["total_cost": 50000]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertEqual(httpResponse.statusCode, 200, "Owner should successfully edit purchase. Found: \(httpResponse.statusCode)")
    }

    // MARK: - Kasus Uji A.3.2: Attacker PATCH Purchase (Negative Case)
    func testPurchasePatch_AsAttacker_ReturnsForbidden() async throws {
        let realID = await fetchRealMaterialID()
        let url = URL(string: "\(baseURL.absoluteString)/materials/\(realID)/purchases/\(samplePurchaseID)")!
        print("DEBUG BOLA: Request URL -> \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(attackerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = ["total_cost": 100]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertEqual(httpResponse.statusCode, 403, "Attacker should be forbidden from patching purchase. Found: \(httpResponse.statusCode)")
    }
}
