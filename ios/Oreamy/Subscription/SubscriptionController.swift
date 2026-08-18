import Foundation
import Observation

@MainActor
@Observable
final class SubscriptionController {
    private(set) var loadState: StoreProductLoadState = .idle
    private(set) var products: [StoreProduct] = []
    private(set) var entitlement: StoreEntitlementState = .notPurchased
    private(set) var serviceAccess: ServiceAccessState = .free
    private(set) var purchaseState: StorePurchaseState = .idle
    private(set) var isRestoring = false
    private(set) var errorMessage: String?
    var selectedProductID: String?

    private let service: any StoreKitService
    private let accessService: any ServiceAccessService
    private let syncService: any PaidEntitlementSyncService
    private let preferredProductID: String?
    private var listener: Task<Void, Never>?
    private var currentSession: OreamySession?

    init(
        service: any StoreKitService = AppleStoreKitService(),
        accessService: any ServiceAccessService = BackendServiceAccessService(),
        syncService: any PaidEntitlementSyncService = BackendPaidEntitlementSyncService(),
        preferredProductID: String? = nil
    ) {
        self.service = service
        self.accessService = accessService
        self.syncService = syncService
        self.preferredProductID = preferredProductID
    }

    var presentationState: SubscriptionPresentationState {
        SubscriptionPresentationState.resolve(store: entitlement, service: serviceAccess)
    }

    func refreshServiceAccess(session: OreamySession?) async {
        currentSession = session?.isExpired == false ? session : nil
        guard let session, !session.isExpired else {
            serviceAccess = .free
            return
        }
        do {
            try await synchronizeCurrentTransactions(session: session)
            serviceAccess = try await accessService.currentAccess(session: session)
        } catch {
            serviceAccess = .unavailable
        }
    }

    func start() async {
        startTransactionListener()
        await loadProducts()
        await refreshEntitlement()
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    func loadProducts() async {
        loadState = .loading
        errorMessage = nil
        do {
            products = try await service.loadProducts().sorted { $0.period < $1.period }
            guard !products.isEmpty else {
                loadState = .unavailable
                selectedProductID = nil
                return
            }
            loadState = .loaded
            if selectedProductID.flatMap({ id in products.first { $0.id == id } }) == nil {
                selectedProductID = products.first(where: { $0.id == preferredProductID })?.id ?? products.first?.id
            }
        } catch {
            products = []
            selectedProductID = nil
            loadState = .failed
            errorMessage = String(localized: "We couldn't load subscription options. Please try again.")
        }
    }

    func select(_ product: StoreProduct) {
        selectedProductID = product.id
    }

    func purchaseSelectedProduct() async {
        guard let selectedProductID else { return }
        guard let session = currentSession else {
            purchaseState = .failed
            errorMessage = String(localized: "Sign in to start Premium.")
            return
        }
        purchaseState = .purchasing
        errorMessage = nil
        do {
            switch try await service.purchase(productID: selectedProductID, appAccountToken: session.userID) {
            case .success(let evidence):
                if evidence.isBackendAuthority {
                    try await syncService.synchronize(signedTransaction: evidence.signedTransaction, session: session)
                }
                await service.finish(transactionID: evidence.transactionID)
                purchaseState = .idle
                await refreshEntitlement()
                await refreshServiceAccess(session: session)
            case .cancelled:
                purchaseState = .cancelled
            case .pending:
                purchaseState = .pending
            case .unverified:
                purchaseState = .verificationFailed
                errorMessage = String(localized: "We couldn't verify the purchase.")
            }
        } catch {
            purchaseState = .failed
            errorMessage = String(localized: "We couldn't complete the purchase. Please try again.")
        }
    }

    func restorePurchases() async {
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }
        do {
            try await service.restorePurchases()
            await refreshEntitlement()
            if let currentSession { try await synchronizeCurrentTransactions(session: currentSession) }
        } catch {
            errorMessage = String(localized: "We couldn't restore purchases. Please try again.")
        }
    }

    func refreshEntitlement() async {
        do {
            entitlement = try await service.currentEntitlement()
        } catch {
            entitlement = .unavailable
        }
    }

    func refreshAfterSubscriptionManagement() async {
        await refreshEntitlement()
        if let currentSession {
            await refreshServiceAccess(session: currentSession)
        }
    }

    private func synchronizeCurrentTransactions(session: OreamySession) async throws {
        for evidence in await service.currentTransactions() where evidence.isBackendAuthority {
            try await syncService.synchronize(signedTransaction: evidence.signedTransaction, session: session)
        }
    }

    func startTransactionListener() {
        guard listener == nil else { return }
        listener = Task { [weak self, service] in
            for await evidence in service.transactionUpdates() {
                guard !Task.isCancelled else { break }
                guard let self, let session = self.currentSession else { continue }
                do {
                    if evidence.isBackendAuthority {
                        try await self.syncService.synchronize(signedTransaction: evidence.signedTransaction, session: session)
                    }
                    await service.finish(transactionID: evidence.transactionID)
                    await self.refreshEntitlement()
                    await self.refreshServiceAccess(session: session)
                } catch {
                    self.errorMessage = String(localized: "We couldn't synchronize Premium access. Please try again.")
                }
            }
        }
    }
}
