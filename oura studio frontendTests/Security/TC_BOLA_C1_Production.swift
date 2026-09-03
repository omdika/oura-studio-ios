// Spec: doc/test/api1_bola_test_spec.md
import XCTest
@testable import oura_studio_frontend

final class TC_BOLA_C1_Production: XCTestCase {
    let baseURL = URL(string: "https://ourastudiobackendseoul-763614853578.asia-northeast3.run.app/api/v1")!
    var ownerToken: String = ""
    var attackerToken: String = ""
    
    // Sample authoritative resource UUID stored for testing
    var sampleBatchID = "b5555-uuid-batch-draft"

    override func setUpWithError() throws {
        super.setUp()
        
        guard let ownerEnv = ProcessInfo.processInfo.environment["JWT_OWNER"] ?? KeychainManager.loadToken(), !ownerEnv.isEmpty else {
            XCTFail("PRE-REQUISITE FAILED: JWT_OWNER is missing. Set it in Xcode environment variables or log in first on simulator.")
            throw NSError(domain: "TC_BOLA_C1_Production", code: 1, userInfo: [NSLocalizedDescriptionKey: "JWT_OWNER is missing"])
        }
        guard let attackerEnv = ProcessInfo.processInfo.environment["JWT_ATTACKER"], !attackerEnv.isEmpty else {
            XCTFail("PRE-REQUISITE FAILED: JWT_ATTACKER environment variable is missing. Set it in active scheme.")
            throw NSError(domain: "TC_BOLA_C1_Production", code: 2, userInfo: [NSLocalizedDescriptionKey: "JWT_ATTACKER is missing"])
        }
        
        ownerToken = ownerEnv
        attackerToken = attackerEnv
    }
    
    // Helper untuk mendeteksi ID Batch produksi nyata dari database backend agar tidak memicu 404 Not Found
    private func fetchRealBatchID() async -> String {
        let url = URL(string: "\(baseURL.absoluteString)/production-batches")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(ownerToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let first = json.first,
                   let realID = first["id"] as? String {
                    print("DEBUG BOLA: Found real production batch ID from database -> \(realID)")
                    return realID
                }
            }
        } catch {
            print("DEBUG BOLA: Failed to query production batches, falling back to sample.")
        }
        return sampleBatchID
    }

    // MARK: - Kasus Uji C.1.1: Owner POST Confirm (Positive Case)
    func testProductionConfirm_AsOwner_ReturnsSuccess() async throws {
        let realID = await fetchRealBatchID()
        let url = URL(string: "\(baseURL.absoluteString)/production-batches/\(realID)/confirm")!
        print("DEBUG BOLA: Request URL -> \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(ownerToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertEqual(httpResponse.statusCode, 200, "Owner should successfully confirm their draft production batch! Found: \(httpResponse.statusCode)")
    }

    // MARK: - Kasus Uji C.1.2: Attacker POST Confirm (Negative Case)
    func testProductionConfirm_AsAttacker_ReturnsForbidden() async throws {
        let realID = await fetchRealBatchID()
        let url = URL(string: "\(baseURL.absoluteString)/production-batches/\(realID)/confirm")!
        print("DEBUG BOLA: Request URL -> \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(attackerToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        XCTAssertEqual(httpResponse.statusCode, 403, "CRITICAL BOLA Security: Non-owner attacker must NEVER confirm draft batches! Found: \(httpResponse.statusCode)")
    }
}
