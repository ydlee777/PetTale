import Foundation
import StoreKit

@MainActor
protocol StoreKitService {
    func loadProducts() async throws -> [StoreProduct]
    func purchase(productID: String, appAccountToken: UUID) async throws -> StorePurchaseOutcome
    func finish(transactionID: UInt64) async
    func currentEntitlement() async throws -> StoreEntitlementState
    func currentTransactions() async -> [VerifiedStoreTransaction]
    func restorePurchases() async throws
    func transactionUpdates() -> AsyncStream<VerifiedStoreTransaction>
}

@MainActor
protocol PaidEntitlementSyncService {
    func synchronize(signedTransaction: String, session: OreamySession) async throws
}

struct BackendPaidEntitlementSyncService: PaidEntitlementSyncService {
    let baseURL: URL
    var urlSession: URLSession = .shared

    init(baseURL: URL = BackendAuthenticationService.configuredBaseURL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func synchronize(signedTransaction: String, session: OreamySession) async throws {
        var request = URLRequest(url: baseURL.appending(path: "api/v1/subscriptions/apple/sync"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SyncRequest(signedTransaction: signedTransaction))
        let (_, response) = try await urlSession.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw StoreKitBoundaryError.entitlementSyncFailed
        }
    }

    private struct SyncRequest: Encodable { let signedTransaction: String }
}

@MainActor
protocol ServiceAccessService {
    func currentAccess(session: OreamySession) async throws -> ServiceAccessState
}

struct BackendServiceAccessService: ServiceAccessService {
    let baseURL: URL
    var urlSession: URLSession = .shared

    init(baseURL: URL = BackendAuthenticationService.configuredBaseURL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func currentAccess(session: OreamySession) async throws -> ServiceAccessState {
        var request = URLRequest(url: baseURL.appending(path: "api/v1/service-access"))
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await urlSession.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw StoreKitBoundaryError.serviceAccessUnavailable
        }
        let decoded = try JSONDecoder.oreamyServiceAccess.decode(ServiceAccessResponse.self, from: data)
        guard decoded.plan == "PREMIUM_TRIAL",
              decoded.trialStartedAt != nil,
              let expiresAt = decoded.trialExpiresAt,
              expiresAt > Date() else { return .free }
        return .freeTrial(expiresAt: expiresAt)
    }

    private struct ServiceAccessResponse: Decodable {
        let plan: String
        let trialStartedAt: Date?
        let trialExpiresAt: Date?
    }
}

@MainActor
struct AppleStoreKitService: StoreKitService {
    func loadProducts() async throws -> [StoreProduct] {
        let products = try await Product.products(for: OreamySubscriptionProduct.approvedIDs)
        return products.compactMap { product in
            guard let subscription = product.subscription else { return nil }
            let period: SubscriptionPeriod
            switch subscription.subscriptionPeriod.unit {
            case .month: period = .monthly
            case .year: period = .annual
            default: return nil
            }
            return StoreProduct(
                id: product.id,
                displayName: product.displayName,
                displayPrice: product.displayPrice,
                period: period
            )
        }
        .filter { OreamySubscriptionProduct.approvedIDs.contains($0.id) }
        .sorted { $0.period < $1.period }
    }

    func purchase(productID: String, appAccountToken: UUID) async throws -> StorePurchaseOutcome {
        guard OreamySubscriptionProduct.approvedIDs.contains(productID),
              let product = try await Product.products(for: [productID]).first else {
            throw StoreKitBoundaryError.productUnavailable
        }
        switch try await product.purchase(options: [.appAccountToken(appAccountToken)]) {
        case .success(let result):
            switch result {
            case .verified(let transaction):
                return .success(VerifiedStoreTransaction(
                    transactionID: transaction.id,
                    signedTransaction: result.jwsRepresentation,
                    isBackendAuthority: transaction.environment == .production || transaction.environment == .sandbox
                ))
            case .unverified:
                return .unverified
            }
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            throw StoreKitBoundaryError.unknownPurchaseResult
        }
    }

    func finish(transactionID: UInt64) async {
        for await result in Transaction.all {
            guard case .verified(let transaction) = result, transaction.id == transactionID else { continue }
            await transaction.finish()
            return
        }
    }

    func currentEntitlement() async throws -> StoreEntitlementState {
        var renewalByProductID: [String: Bool] = [:]
        for product in try await Product.products(for: OreamySubscriptionProduct.approvedIDs) {
            guard let subscription = product.subscription else { continue }
            for status in try await subscription.status {
                guard case .verified(let transaction) = status.transaction,
                      case .verified(let renewalInfo) = status.renewalInfo else { continue }
                renewalByProductID[transaction.productID] = renewalInfo.willAutoRenew
            }
        }
        var candidates: [StoreEntitlementCandidate] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            candidates.append(StoreEntitlementCandidate(
                productID: transaction.productID,
                expirationDate: transaction.expirationDate,
                revocationDate: transaction.revocationDate,
                isUpgraded: transaction.isUpgraded,
                willAutoRenew: renewalByProductID[transaction.productID]
            ))
        }
        return StoreEntitlementResolver.resolve(candidates, now: Date())
    }

    func currentTransactions() async -> [VerifiedStoreTransaction] {
        var transactions: [VerifiedStoreTransaction] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  OreamySubscriptionProduct.approvedIDs.contains(transaction.productID) else { continue }
            transactions.append(.init(
                transactionID: transaction.id,
                signedTransaction: result.jwsRepresentation,
                isBackendAuthority: transaction.environment == .production || transaction.environment == .sandbox
            ))
        }
        return transactions
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
    }

    func transactionUpdates() -> AsyncStream<VerifiedStoreTransaction> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    if case .verified(let transaction) = result,
                       OreamySubscriptionProduct.approvedIDs.contains(transaction.productID) {
                        continuation.yield(VerifiedStoreTransaction(
                            transactionID: transaction.id,
                            signedTransaction: result.jwsRepresentation,
                            isBackendAuthority: transaction.environment == .production || transaction.environment == .sandbox
                        ))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

struct StoreEntitlementCandidate: Equatable, Sendable {
    let productID: String
    let expirationDate: Date?
    let revocationDate: Date?
    let isUpgraded: Bool
    let willAutoRenew: Bool?
}

enum StoreEntitlementResolver {
    static func resolve(_ candidates: [StoreEntitlementCandidate], now: Date) -> StoreEntitlementState {
        let active = candidates
            .filter {
                OreamySubscriptionProduct.approvedIDs.contains($0.productID)
                    && $0.revocationDate == nil
                    && !$0.isUpgraded
                    && ($0.expirationDate.map { $0 > now } ?? true)
            }
            .max { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }
        guard let active else { return .notPurchased }
        return .premium(
            productID: active.productID,
            expirationDate: active.expirationDate,
            willAutoRenew: active.willAutoRenew
        )
    }
}

enum StoreKitBoundaryError: Error {
    case productUnavailable
    case unknownPurchaseResult
    case serviceAccessUnavailable
    case authenticationRequired
    case entitlementSyncFailed
}

private extension JSONDecoder {
    static var oreamyServiceAccess: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            guard let date = standard.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Invalid ISO-8601 date"
                )
            }
            return date
        }
        return decoder
    }
}

#if DEBUG
@MainActor
final class SubscriptionDevelopmentService: StoreKitService {
    private let fails: Bool
    private let premium: Bool

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        fails = arguments.contains("-oreamyPremiumError")
        premium = arguments.contains("-oreamyPremiumActive")
    }

    func loadProducts() async throws -> [StoreProduct] {
        if fails { throw StoreKitBoundaryError.productUnavailable }
        let usesKRW = Locale.current.currency?.identifier == "KRW"
        return [
            StoreProduct(id: OreamySubscriptionProduct.monthlyID, displayName: "Oreamy Premium Monthly", displayPrice: usesKRW ? "₩6,600" : "$4.99", period: .monthly),
            StoreProduct(id: OreamySubscriptionProduct.annualID, displayName: "Oreamy Premium Annual", displayPrice: usesKRW ? "₩64,000" : "$47.99", period: .annual)
        ]
    }

    func purchase(productID: String, appAccountToken: UUID) async throws -> StorePurchaseOutcome { .cancelled }
    func finish(transactionID: UInt64) async {}
    func currentEntitlement() async throws -> StoreEntitlementState {
        premium ? .premium(productID: OreamySubscriptionProduct.annualID, expirationDate: nil, willAutoRenew: true) : .notPurchased
    }
    func currentTransactions() async -> [VerifiedStoreTransaction] { [] }
    func restorePurchases() async throws {
        if fails { throw StoreKitBoundaryError.productUnavailable }
    }
    func transactionUpdates() -> AsyncStream<VerifiedStoreTransaction> { AsyncStream { $0.finish() } }
}
#endif
