//
//  oura_studio_frontendTests.swift
//  oura studio frontendTests
//
//  Created by handika on 29/07/26.
//

import Testing
import Foundation
@testable import oura_studio_frontend

struct oura_studio_frontendTests {

    private func ago(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    @Test func testStockLedgerSeedingAndDateFiltering() async throws {
        let api = MockAPIService.shared
        
        // 1. Test fetching today's entries only (should return 1 entry for sizeScrunS)
        let today = Date()
        let todayEntries = try await api.getStockLedger(from: today, to: today)
        #expect(todayEntries.count == 1)
        #expect(todayEntries.first?.changeQty == 8)
        #expect(todayEntries.first?.reason == "production")
        
        // 2. Test fetching last 3 days of entries (should return 4 entries)
        let threeDaysAgo = ago(days: 3)
        let allEntries = try await api.getStockLedger(from: threeDaysAgo, to: today)
        #expect(allEntries.count == 4)
        
        // 3. Test range with no matches (e.g. 10 days ago to 5 days ago)
        let tenDaysAgo = ago(days: 10)
        let fiveDaysAgo = ago(days: 5)
        let emptyEntries = try await api.getStockLedger(from: tenDaysAgo, to: fiveDaysAgo)
        #expect(emptyEntries.isEmpty)
        
        // 4. Test range of days -3 to -2 (should return sizeScrunM and sizeScrunXS)
        let twoDaysAgo = ago(days: 2)
        let midEntries = try await api.getStockLedger(from: threeDaysAgo, to: twoDaysAgo)
        #expect(midEntries.count == 2)
        let changeQtys = midEntries.map { $0.changeQty }.sorted()
        #expect(changeQtys == [5, 10])
    }

    @Test func testStockLedgerRealTimeAdditions() async throws {
        let api = MockAPIService.shared
        let sizeScrunXL = UUID(uuidString: "55555555-0000-0000-0000-000000000007")! // L · Silk Putih
        
        // Perform manual stock adjustment of +15 pcs
        _ = try await api.adjustStock(sku: "SCRUNCHIE", sizeId: sizeScrunXL, qty: 15, reason: "initial", note: nil)
        
        // Fetch today's entries and verify that the new adjustment is appended to the ledger
        let today = Date()
        let todayEntries = try await api.getStockLedger(from: today, to: today)
        
        // We should have sizeScrunS (8 pcs seeded today) + the newly added sizeScrunXL (15 pcs)
        #expect(todayEntries.count == 2)
        let totalTodayQty = todayEntries.reduce(0) { $0 + $1.changeQty }
        #expect(totalTodayQty == 23)
        
        let xlEntry = todayEntries.first { $0.productSizeId == sizeScrunXL }
        #expect(xlEntry != nil)
        #expect(xlEntry?.changeQty == 15)
        #expect(xlEntry?.reason == "initial")
    }

    @Test func testStockLedgerNegativeAdjustment() async throws {
        let api = MockAPIService.shared
        let sizeScrunXL = UUID(uuidString: "55555555-0000-0000-0000-000000000007")! // L · Silk Putih
        
        let initialSize = try await api.getProductSizeById(id: sizeScrunXL)
        let initialStock = initialSize.currentStockQty
        
        // 1. Perform negative adjustment (e.g. reduction of 3 pcs)
        let updatedSize = try await api.adjustStock(sku: "SCRUNCHIE", sizeId: sizeScrunXL, qty: -3, reason: "adjustment", note: nil)
        #expect(updatedSize.currentStockQty == initialStock - 3)
        
        // 2. Fetch today's ledger entries and find our negative entry
        let today = Date()
        let todayEntries = try await api.getStockLedger(from: today, to: today)
        let negEntry = todayEntries.first { $0.productSizeId == sizeScrunXL && $0.changeQty == -3 }
        #expect(negEntry != nil)
        #expect(negEntry?.reason == "adjustment")
        
        // 3. Verify that v3.44 positive addition logic ignores this negative entry
        let additionsMap = Dictionary(grouping: todayEntries.filter { $0.changeQty > 0 }, by: { $0.productSizeId })
            .mapValues { entries in entries.reduce(0) { $0 + $1.changeQty } }
        
        #expect(additionsMap[sizeScrunXL] == nil)
    }

    @Test func testGoogleClientIDConfiguration() async throws {
        // 1. Verify GoogleClientID is in Info.plist
        let clientID = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String
        #expect(clientID != nil)
        #expect(clientID == "763614853578-khhhap8llgs7a4obnuj2riebn5ci4t9v.apps.googleusercontent.com")
        
        // 2. Verify Reversed Client ID computation logic
        guard let unwrappedClientID = clientID else { return }
        let components = unwrappedClientID.components(separatedBy: ".")
        let reversedClientID = components.reversed().joined(separator: ".")
        
        #expect(reversedClientID == "com.googleusercontent.apps.763614853578-khhhap8llgs7a4obnuj2riebn5ci4t9v")
        
        // 3. Verify URL Scheme matches
        let redirectURI = "\(reversedClientID):/oauth2callback"
        #expect(redirectURI == "com.googleusercontent.apps.763614853578-khhhap8llgs7a4obnuj2riebn5ci4t9v:/oauth2callback")
    }
}
