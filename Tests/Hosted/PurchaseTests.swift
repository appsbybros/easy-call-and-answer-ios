import XCTest
import StoreKitTest
@testable import EasyCall

@MainActor final class PurchaseTests: XCTestCase {
    func testLifetimePurchaseRestoreAndRefund() async throws {
        let session=try SKTestSession(configurationFileNamed:"EasyCall")
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
