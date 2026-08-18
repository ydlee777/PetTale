import Foundation
import XCTest
@testable import Oreamy

@MainActor
final class SubscriptionControllerTests: XCTestCase {
    func testInitialAndProductLoadingStates() async {
        let service = FakeStoreKitService(products: products)
        let controller = SubscriptionController(service: service)
        XCTAssertEqual(controller.loadState, .idle)
        await controller.loadProducts()
        XCTAssertEqual(controller.loadState, .loaded)
        XCTAssertEqual(controller.products.map(\.id), [OreamySubscriptionProduct.monthlyID, OreamySubscriptionProduct.annualID])
        XCTAssertEqual(controller.selectedProductID, OreamySubscriptionProduct.monthlyID)
    }

    func testEmptyAndFailedProductLoadingDoNotFabricatePrices() async {
        let empty = SubscriptionController(service: FakeStoreKitService(products: []))
        await empty.loadProducts()
        XCTAssertEqual(empty.loadState, .unavailable)
        XCTAssertTrue(empty.products.isEmpty)

        let service = FakeStoreKitService(products: products)
        service.loadError = TestError.expected
        let failed = SubscriptionController(service: service)
        await failed.loadProducts()
        XCTAssertEqual(failed.loadState, .failed)
        XCTAssertTrue(failed.products.isEmpty)
    }

    func testProductOrderingSelectionAndStoreProvidedPresentation() async {
        let service = FakeStoreKitService(products: products.reversed())
        let controller = SubscriptionController(service: service)
        await controller.loadProducts()
        XCTAssertEqual(controller.products.map(\.displayPrice), ["₩6,600", "₩64,000"])
        controller.select(controller.products[1])
        XCTAssertEqual(controller.selectedProductID, OreamySubscriptionProduct.annualID)
        XCTAssertNil(controller.products[0].savingsLabel)
        XCTAssertEqual(controller.products[1].savingsLabel, String(localized: "Save 20%"))
    }

    func testAccountPlanSeparatesVerifiedPremiumTrialAndFreeAccess() async {
        let store = FakeStoreKitService(products: products)
        let access = FakeServiceAccessService(state: .freeTrial(expiresAt: .distantFuture))
        let controller = SubscriptionController(service: store, accessService: access)
        await controller.refreshServiceAccess(session: validSession())
        XCTAssertEqual(controller.presentationState, .freeTrial(expiresAt: .distantFuture))

        access.state = .free
        await controller.refreshServiceAccess(session: validSession())
        XCTAssertEqual(controller.presentationState, .free)

        store.entitlement = .premium(productID: OreamySubscriptionProduct.monthlyID, expirationDate: .distantFuture, willAutoRenew: true)
        await controller.refreshEntitlement()
        access.state = .freeTrial(expiresAt: .distantFuture)
        await controller.refreshServiceAccess(session: validSession())
        XCTAssertEqual(controller.presentationState, .premiumMonthly(expirationDate: .distantFuture))
    }

    func testMissingExpiredSessionCannotDisplayTrialOrPremium() async {
        let access = FakeServiceAccessService(state: .freeTrial(expiresAt: .distantFuture))
        let controller = SubscriptionController(service: FakeStoreKitService(products: products), accessService: access)
        await controller.refreshServiceAccess(session: nil)
        XCTAssertEqual(controller.presentationState, .free)
        await controller.refreshServiceAccess(session: OreamySession(userID: UUID(), accessToken: "expired", expiresAt: .distantPast))
        XCTAssertEqual(controller.presentationState, .free)
        XCTAssertEqual(access.callCount, 0)
    }

    func testPurchaseRequiresAuthenticatedServiceUserUUID() async {
        let service = FakeStoreKitService(products: products)
        let controller = SubscriptionController(service: service, syncService: FakePaidEntitlementSyncService())
        await controller.loadProducts()
        await controller.purchaseSelectedProduct()
        XCTAssertTrue(service.purchasedIDs.isEmpty)
        XCTAssertEqual(controller.purchaseState, .failed)
        XCTAssertNotNil(controller.errorMessage)
    }

    func testPurchaseSuccessRefreshesVerifiedEntitlement() async {
        let service = FakeStoreKitService(products: products)
        service.purchaseOutcome = .success(.init(transactionID: 1, signedTransaction: "signed", isBackendAuthority: true))
        service.entitlement = .premium(productID: OreamySubscriptionProduct.monthlyID, expirationDate: .distantFuture, willAutoRenew: true)
        let sync = FakePaidEntitlementSyncService()
        let controller = SubscriptionController(service: service, syncService: sync)
        await controller.loadProducts()
        await controller.refreshServiceAccess(session: validSession())
        await controller.purchaseSelectedProduct()
        XCTAssertTrue(controller.entitlement.isPremium)
        XCTAssertEqual(service.purchasedIDs, [OreamySubscriptionProduct.monthlyID])
        XCTAssertEqual(service.purchasedTokens, [sync.lastSession?.userID].compactMap { $0 })
        XCTAssertEqual(sync.signedTransactions, ["signed"])
        XCTAssertEqual(service.finishedTransactionIDs, [1])
    }

    func testXcodeLocalPurchaseNeverSynchronizesBackendPremiumAuthority() async {
        let service = FakeStoreKitService(products: products)
        service.purchaseOutcome = .success(.init(
            transactionID: 9,
            signedTransaction: "xcode-local",
            isBackendAuthority: false
        ))
        let sync = FakePaidEntitlementSyncService()
        let controller = SubscriptionController(service: service, syncService: sync)
        await controller.loadProducts()
        await controller.refreshServiceAccess(session: validSession())
        await controller.purchaseSelectedProduct()
        XCTAssertTrue(sync.signedTransactions.isEmpty)
        XCTAssertEqual(service.finishedTransactionIDs, [9])
    }

    func testCancelledAndPendingPurchasesDoNotActivateEntitlement() async {
        let cancelledService = FakeStoreKitService(products: products)
        cancelledService.purchaseOutcome = .cancelled
        let cancelled = SubscriptionController(service: cancelledService)
        await cancelled.loadProducts()
        await cancelled.refreshServiceAccess(session: validSession())
        await cancelled.purchaseSelectedProduct()
        XCTAssertEqual(cancelled.purchaseState, .cancelled)
        XCTAssertFalse(cancelled.entitlement.isPremium)

        let pendingService = FakeStoreKitService(products: products)
        pendingService.purchaseOutcome = .pending
        let pending = SubscriptionController(service: pendingService)
        await pending.loadProducts()
        await pending.refreshServiceAccess(session: validSession())
        await pending.purchaseSelectedProduct()
        XCTAssertEqual(pending.purchaseState, .pending)
        XCTAssertFalse(pending.entitlement.isPremium)
    }

    func testUnverifiedAndStoreErrorsAreSafeFailures() async {
        let unverifiedService = FakeStoreKitService(products: products)
        unverifiedService.purchaseOutcome = .unverified
        let unverified = SubscriptionController(service: unverifiedService)
        await unverified.loadProducts()
        await unverified.refreshServiceAccess(session: validSession())
        await unverified.purchaseSelectedProduct()
        XCTAssertEqual(unverified.purchaseState, .verificationFailed)
        XCTAssertFalse(unverified.entitlement.isPremium)

        let failingService = FakeStoreKitService(products: products)
        failingService.purchaseError = TestError.expected
        let failing = SubscriptionController(service: failingService)
        await failing.loadProducts()
        await failing.refreshServiceAccess(session: validSession())
        await failing.purchaseSelectedProduct()
        XCTAssertEqual(failing.purchaseState, .failed)
    }

    func testExpiredRevokedAndVerifiedEntitlementsAreServiceResolved() async {
        let service = FakeStoreKitService(products: products)
        let controller = SubscriptionController(service: service)
        service.entitlement = .notPurchased
        await controller.refreshEntitlement()
        XCTAssertFalse(controller.entitlement.isPremium)
        service.entitlement = .premium(productID: OreamySubscriptionProduct.annualID, expirationDate: .distantFuture, willAutoRenew: true)
        await controller.refreshEntitlement()
        XCTAssertTrue(controller.entitlement.isPremium)
        service.entitlement = .notPurchased
        await controller.refreshEntitlement()
        XCTAssertFalse(controller.entitlement.isPremium)
    }

    func testEntitlementResolverRejectsExpiredRevokedUpgradedAndUnknownTransactions() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let inactive = [
            StoreEntitlementCandidate(productID: OreamySubscriptionProduct.monthlyID, expirationDate: now.addingTimeInterval(-1), revocationDate: nil, isUpgraded: false, willAutoRenew: false),
            StoreEntitlementCandidate(productID: OreamySubscriptionProduct.annualID, expirationDate: now.addingTimeInterval(100), revocationDate: now, isUpgraded: false, willAutoRenew: false),
            StoreEntitlementCandidate(productID: OreamySubscriptionProduct.monthlyID, expirationDate: now.addingTimeInterval(100), revocationDate: nil, isUpgraded: true, willAutoRenew: true),
            StoreEntitlementCandidate(productID: "unknown.product", expirationDate: now.addingTimeInterval(100), revocationDate: nil, isUpgraded: false, willAutoRenew: true)
        ]
        XCTAssertEqual(StoreEntitlementResolver.resolve(inactive, now: now), .notPurchased)
    }

    func testEntitlementResolverAcceptsVerifiedCurrentApprovedProduct() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let expiration = now.addingTimeInterval(100)
        let candidate = StoreEntitlementCandidate(
            productID: OreamySubscriptionProduct.annualID,
            expirationDate: expiration,
            revocationDate: nil,
            isUpgraded: false,
            willAutoRenew: false
        )
        XCTAssertEqual(
            StoreEntitlementResolver.resolve([candidate], now: now),
            .premium(productID: OreamySubscriptionProduct.annualID, expirationDate: expiration, willAutoRenew: false)
        )
    }

    func testFiveStateContractAndScreenVisibility() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let expiration = now.addingTimeInterval(5 * 86_400)
        let trial = SubscriptionPresentationState.resolve(store: .notPurchased, service: .freeTrial(expiresAt: expiration), now: now)
        let free = SubscriptionPresentationState.resolve(store: .notPurchased, service: .free, now: now)
        let monthly = SubscriptionPresentationState.resolve(store: .premium(productID: OreamySubscriptionProduct.monthlyID, expirationDate: expiration, willAutoRenew: true), service: .free, now: now)
        let yearly = SubscriptionPresentationState.resolve(store: .premium(productID: OreamySubscriptionProduct.annualID, expirationDate: expiration, willAutoRenew: true), service: .free, now: now)
        let expiring = SubscriptionPresentationState.resolve(store: .premium(productID: OreamySubscriptionProduct.monthlyID, expirationDate: expiration, willAutoRenew: false), service: .free, now: now)

        XCTAssertEqual(trial, .freeTrial(expiresAt: expiration))
        XCTAssertEqual(free, .free)
        XCTAssertEqual(monthly, .premiumMonthly(expirationDate: expiration))
        XCTAssertEqual(yearly, .premiumYearly(expirationDate: expiration))
        XCTAssertEqual(expiring, .premiumExpiring(product: .monthly, expirationDate: expiration))
        XCTAssertTrue(trial.showsProductSelector)
        XCTAssertTrue(free.showsProductSelector)
        XCTAssertFalse(monthly.showsProductSelector)
        XCTAssertFalse(yearly.showsProductSelector)
        XCTAssertFalse(expiring.showsProductSelector)
        XCTAssertFalse(expiring.showsPurchaseCTA)
        XCTAssertEqual([trial.monthlyAiAllowance, free.monthlyAiAllowance, monthly.monthlyAiAllowance], [300, 3, 300])
    }

    func testExpirationBoundaryExpiredRevokedAndNoEntitlementAreFree() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for store: StoreEntitlementState in [
            .premium(productID: OreamySubscriptionProduct.monthlyID, expirationDate: now, willAutoRenew: true),
            .notPurchased
        ] {
            XCTAssertEqual(SubscriptionPresentationState.resolve(store: store, service: .free, now: now), .free)
        }
        let revoked = StoreEntitlementCandidate(
            productID: OreamySubscriptionProduct.monthlyID,
            expirationDate: now.addingTimeInterval(100),
            revocationDate: now,
            isUpgraded: false,
            willAutoRenew: true
        )
        XCTAssertEqual(StoreEntitlementResolver.resolve([revoked], now: now), .notPurchased)
        XCTAssertEqual(AccountPlanPresentation.make(state: .free, now: now, locale: Locale(identifier: "ko_KR")).title, "무료 플랜 이용 중")
    }

    func testBackendTrialOnlyUsesExpirationForRemainingDays() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let expires = now.addingTimeInterval(2.2 * 86_400)
        let plan = SubscriptionPresentationState.resolve(store: .notPurchased, service: .freeTrial(expiresAt: expires), now: now)
        XCTAssertEqual(plan, .freeTrial(expiresAt: expires))
        XCTAssertEqual(
            AccountPlanPresentation.make(state: plan, now: now, locale: Locale(identifier: "en_US")).detail,
            "3 days remaining."
        )
        XCTAssertEqual(SubscriptionPresentationState.resolve(store: .notPurchased, service: .freeTrial(expiresAt: now), now: now), .free)
    }

    func testExpiringPresentationPreservesProductAndExplainsFreeTransition() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let expiration = now.addingTimeInterval(86_400)
        let state = SubscriptionPresentationState.resolve(
            store: .premium(
                productID: OreamySubscriptionProduct.monthlyID,
                expirationDate: expiration,
                willAutoRenew: false
            ),
            service: .free,
            now: now
        )

        let presentation = AccountPlanPresentation.make(
            state: state,
            now: now,
            locale: Locale(identifier: "en_US")
        )
        XCTAssertEqual(state, .premiumExpiring(product: .monthly, expirationDate: expiration))
        XCTAssertEqual(presentation.title, "Premium Active · Auto-Renewal Off")
        XCTAssertTrue(presentation.detail?.contains("Available until") == true)
        XCTAssertTrue(presentation.detail?.contains("switch to the Free plan") == true)
        XCTAssertEqual(products.first(where: { $0.period == .monthly })?.displayPrice, "₩6,600")
        XCTAssertEqual(products.first(where: { $0.period == .annual })?.displayPrice, "₩64,000")
        XCTAssertEqual(products.first(where: { $0.period == .annual })?.savingsLabel, String(localized: "Save 20%"))
    }

    func testInvalidPaidStateFallsBackToBackendTrialOrFree() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let trialExpiration = now.addingTimeInterval(86_400)
        XCTAssertEqual(
            SubscriptionPresentationState.resolve(
                store: .premium(productID: OreamySubscriptionProduct.monthlyID, expirationDate: now, willAutoRenew: false),
                service: .freeTrial(expiresAt: trialExpiration), now: now
            ), .freeTrial(expiresAt: trialExpiration)
        )
        XCTAssertEqual(
            SubscriptionPresentationState.resolve(
                store: .premium(productID: OreamySubscriptionProduct.monthlyID, expirationDate: trialExpiration, willAutoRenew: nil),
                service: .free, now: now
            ), .free
        )
    }

    func testManagementReturnRefreshRecomputesMonthlyExpiringYearlyAndFree() async {
        let expiration = Date.distantFuture
        let service = FakeStoreKitService(products: products)
        let controller = SubscriptionController(service: service)

        service.entitlement = .premium(productID: OreamySubscriptionProduct.monthlyID, expirationDate: expiration, willAutoRenew: true)
        await controller.refreshAfterSubscriptionManagement()
        XCTAssertEqual(controller.presentationState, .premiumMonthly(expirationDate: expiration))

        service.entitlement = .premium(productID: OreamySubscriptionProduct.monthlyID, expirationDate: expiration, willAutoRenew: false)
        await controller.refreshAfterSubscriptionManagement()
        XCTAssertEqual(controller.presentationState, .premiumExpiring(product: .monthly, expirationDate: expiration))

        service.entitlement = .premium(productID: OreamySubscriptionProduct.annualID, expirationDate: expiration, willAutoRenew: true)
        await controller.refreshAfterSubscriptionManagement()
        XCTAssertEqual(controller.presentationState, .premiumYearly(expirationDate: expiration))

        service.entitlement = .notPurchased
        await controller.refreshAfterSubscriptionManagement()
        XCTAssertEqual(controller.presentationState, .free)
        XCTAssertEqual(service.entitlementCalls, 4)
    }

    func testRestoreSuccessAndFailure() async {
        let service = FakeStoreKitService(products: products)
        service.entitlement = .premium(productID: OreamySubscriptionProduct.annualID, expirationDate: nil, willAutoRenew: true)
        let controller = SubscriptionController(service: service)
        await controller.restorePurchases()
        XCTAssertEqual(service.restoreCalls, 1)
        XCTAssertTrue(controller.entitlement.isPremium)

        service.restoreError = TestError.expected
        await controller.restorePurchases()
        XCTAssertNotNil(controller.errorMessage)
        XCTAssertFalse(controller.isRestoring)
    }

    func testTransactionUpdateRefreshesAndListenerDoesNotDuplicate() async {
        let service = FakeStoreKitService(products: products)
        let controller = SubscriptionController(service: service, syncService: FakePaidEntitlementSyncService())
        await controller.refreshServiceAccess(session: validSession())
        controller.startTransactionListener()
        controller.startTransactionListener()
        await Task.yield()
        XCTAssertEqual(service.listenerCount, 1)
        service.entitlement = .premium(productID: OreamySubscriptionProduct.monthlyID, expirationDate: nil, willAutoRenew: true)
        service.sendUpdate()
        await waitUntil { controller.entitlement.isPremium }
        XCTAssertTrue(controller.entitlement.isPremium)
        controller.stop()
        await waitUntil { service.listenerTerminated }
        XCTAssertTrue(service.listenerTerminated)
    }

    func testAppLaunchListenerPrecedesPurchaseAndSurvivesScreenNavigation() async {
        let service = FakeStoreKitService(products: products)
        let controller = SubscriptionController(service: service, syncService: FakePaidEntitlementSyncService())
        await controller.refreshServiceAccess(session: validSession())

        controller.startTransactionListener()
        await waitUntil { service.listenerCount == 1 }
        await controller.loadProducts()
        await controller.purchaseSelectedProduct()
        XCTAssertEqual(service.listenerCountWhenPurchased, 1)

        // PremiumView navigation does not own or stop the app-scoped controller.
        controller.startTransactionListener()
        await controller.purchaseSelectedProduct()
        XCTAssertEqual(service.listenerCount, 1)
        XCTAssertFalse(service.listenerTerminated)

        service.entitlement = .premium(
            productID: OreamySubscriptionProduct.monthlyID,
            expirationDate: .distantFuture,
            willAutoRenew: true
        )
        service.sendUpdate()
        await waitUntil { controller.presentationState == .premiumMonthly(expirationDate: .distantFuture) }

        controller.stop()
        await waitUntil { service.listenerTerminated }
        XCTAssertTrue(service.listenerTerminated)
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private var products: [StoreProduct] {
        [
            StoreProduct(id: OreamySubscriptionProduct.monthlyID, displayName: "Oreamy Premium Monthly", displayPrice: "₩6,600", period: .monthly),
            StoreProduct(id: OreamySubscriptionProduct.annualID, displayName: "Oreamy Premium Annual", displayPrice: "₩64,000", period: .annual)
        ]
    }

    private func validSession() -> OreamySession {
        OreamySession(userID: UUID(), accessToken: "test-token", expiresAt: .distantFuture)
    }
}

@MainActor
private final class FakeServiceAccessService: ServiceAccessService {
    var state: ServiceAccessState
    var callCount = 0
    init(state: ServiceAccessState) { self.state = state }
    func currentAccess(session: OreamySession) async throws -> ServiceAccessState {
        callCount += 1
        return state
    }
}

@MainActor
private final class FakeStoreKitService: StoreKitService {
    var products: [StoreProduct]
    var loadError: Error?
    var purchaseOutcome: StorePurchaseOutcome = .success(.init(transactionID: 1, signedTransaction: "signed", isBackendAuthority: true))
    var purchaseError: Error?
    var entitlement: StoreEntitlementState = .notPurchased
    var restoreError: Error?
    var restoreCalls = 0
    var entitlementCalls = 0
    var purchasedIDs: [String] = []
    var purchasedTokens: [UUID] = []
    var finishedTransactionIDs: [UInt64] = []
    var currentTransactionEvidence: [VerifiedStoreTransaction] = []
    var listenerCountWhenPurchased: Int?
    var listenerCount = 0
    var listenerTerminated = false
    private var continuation: AsyncStream<VerifiedStoreTransaction>.Continuation?

    init<S: Sequence>(products: S) where S.Element == StoreProduct { self.products = Array(products) }
    func loadProducts() async throws -> [StoreProduct] { if let loadError { throw loadError }; return products }
    func purchase(productID: String, appAccountToken: UUID) async throws -> StorePurchaseOutcome {
        listenerCountWhenPurchased = listenerCount
        purchasedIDs.append(productID)
        purchasedTokens.append(appAccountToken)
        if let purchaseError { throw purchaseError }
        return purchaseOutcome
    }
    func finish(transactionID: UInt64) async { finishedTransactionIDs.append(transactionID) }
    func currentEntitlement() async throws -> StoreEntitlementState {
        entitlementCalls += 1
        return entitlement
    }
    func currentTransactions() async -> [VerifiedStoreTransaction] { currentTransactionEvidence }
    func restorePurchases() async throws { restoreCalls += 1; if let restoreError { throw restoreError } }
    func transactionUpdates() -> AsyncStream<VerifiedStoreTransaction> {
        listenerCount += 1
        return AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.listenerTerminated = true }
            }
        }
    }
    func sendUpdate() { continuation?.yield(.init(transactionID: 2, signedTransaction: "updated", isBackendAuthority: true)) }
}

@MainActor
private final class FakePaidEntitlementSyncService: PaidEntitlementSyncService {
    var signedTransactions: [String] = []
    var lastSession: OreamySession?
    func synchronize(signedTransaction: String, session: OreamySession) async throws {
        signedTransactions.append(signedTransaction)
        lastSession = session
    }
}

private enum TestError: Error { case expected }
