import XCTest
import StoreKitTest
@testable import EasyCall

@MainActor final class PurchaseTests: XCTestCase {
    func testFreeTrialUsesVerifiedOriginalPurchaseAndCanBeRevoked() async throws {
        let configuration=try XCTUnwrap(Bundle(for:Self.self).url(forResource:"EasyCall",withExtension:"storekit"))
        let session=try SKTestSession(contentsOf:configuration)
        session.resetToDefaultState();session.disableDialogs=true;session.clearTransactions()
        defer {session.clearTransactions()}
        let store=Purchases()
        await store.refresh()
        let trialProduct=try XCTUnwrap(store.trialProduct)
        XCTAssertEqual(trialProduct.price,Decimal.zero)
        XCTAssertNil(store.trialStart)
        await store.buy(trial:true)
        let start=try XCTUnwrap(store.trialStart)
        XCTAssertFalse(store.unlocked,"The free trial is not a lifetime purchase")
        XCTAssertTrue(Snapshot().trialActive(start:start,now:start.addingTimeInterval(13*86400)))
        XCTAssertFalse(Snapshot().trialActive(start:start,now:start.addingTimeInterval(14*86400)))
        let restored=Purchases()
        await restored.refresh()
        XCTAssertEqual(restored.trialStart,start,"A fresh instance must retain the original trial date")
        let transaction=try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier:transaction.identifier)
        for _ in 0..<30 {
            await store.refresh()
            if store.trialStart == nil {break}
            try await Task.sleep(nanoseconds:100_000_000)
        }
        XCTAssertNil(store.trialStart)
    }
    func testLifetimePurchaseRestoreAndRefund() async throws {
        let configuration=try XCTUnwrap(Bundle(for:Self.self).url(forResource:"EasyCall",withExtension:"storekit"))
        let session=try SKTestSession(contentsOf:configuration)
        session.resetToDefaultState();session.disableDialogs=true;session.clearTransactions()
        defer {session.clearTransactions()}
        let store=Purchases()
        await store.refresh()
        XCTAssertNotNil(store.product)
        XCTAssertFalse(store.unlocked)
        await store.buy()
        XCTAssertTrue(store.unlocked)
        let restored=Purchases()
        await restored.refresh()
        XCTAssertTrue(restored.unlocked,"Verified current entitlements survive a fresh store instance")
        let transaction=try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier:transaction.identifier)
        for _ in 0..<30 {
            await store.refresh()
            if !store.unlocked {break}
            try await Task.sleep(nanoseconds:100_000_000)
        }
        XCTAssertFalse(store.unlocked)
    }
}
