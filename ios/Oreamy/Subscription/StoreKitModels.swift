import Foundation

enum OreamySubscriptionProduct {
    static let monthlyID = "com.oreamy.app.premium.monthly"
    static let annualID = "com.oreamy.app.premium.annual"
    static let approvedIDs: Set<String> = [monthlyID, annualID]
}

enum SubscriptionPeriod: Int, Sendable, Comparable {
    case monthly
    case annual

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct StoreProduct: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String
    let period: SubscriptionPeriod

    var savingsLabel: String? {
        period == .annual ? String(localized: "Save 20%") : nil
    }
}

enum StorePurchaseOutcome: Equatable, Sendable {
    case success(VerifiedStoreTransaction)
    case cancelled
    case pending
    case unverified
}

struct VerifiedStoreTransaction: Equatable, Sendable {
    let transactionID: UInt64
    let signedTransaction: String
    let isBackendAuthority: Bool
}

enum StoreEntitlementState: Equatable, Sendable {
    case notPurchased
    case premium(productID: String, expirationDate: Date?, willAutoRenew: Bool?)
    case unavailable

    var isPremium: Bool {
        if case .premium = self { return true }
        return false
    }
}

enum ServiceAccessState: Equatable, Sendable {
    case free
    case freeTrial(expiresAt: Date)
    case unavailable
}

enum PaidSubscriptionProduct: Equatable, Sendable {
    case monthly
    case yearly
}

enum SubscriptionPresentationState: Equatable {
    case freeTrial(expiresAt: Date)
    case free
    case premiumMonthly(expirationDate: Date?)
    case premiumYearly(expirationDate: Date?)
    case premiumExpiring(product: PaidSubscriptionProduct, expirationDate: Date)

    static func resolve(store: StoreEntitlementState, service: ServiceAccessState, now: Date = Date()) -> Self {
        if case let .premium(productID, expirationDate, willAutoRenew) = store,
           expirationDate.map({ $0 > now }) ?? true {
            let product: PaidSubscriptionProduct?
            switch productID {
            case OreamySubscriptionProduct.monthlyID: product = .monthly
            case OreamySubscriptionProduct.annualID: product = .yearly
            default: product = nil
            }
            if let product, willAutoRenew == false, let expirationDate {
                return .premiumExpiring(product: product, expirationDate: expirationDate)
            }
            if product == .monthly, willAutoRenew == true { return .premiumMonthly(expirationDate: expirationDate) }
            if product == .yearly, willAutoRenew == true { return .premiumYearly(expirationDate: expirationDate) }
        }
        if case let .freeTrial(expiresAt) = service, expiresAt > now { return .freeTrial(expiresAt: expiresAt) }
        return .free
    }

    var showsProductSelector: Bool {
        switch self {
        case .freeTrial, .free: true
        case .premiumMonthly, .premiumYearly, .premiumExpiring: false
        }
    }

    var showsPurchaseCTA: Bool { showsProductSelector }

    var isPaidPremium: Bool {
        switch self {
        case .premiumMonthly, .premiumYearly, .premiumExpiring: true
        case .freeTrial, .free: false
        }
    }

    var monthlyAiAllowance: Int {
        switch self {
        case .free: 3
        case .freeTrial, .premiumMonthly, .premiumYearly, .premiumExpiring: 300
        }
    }

    var paidProduct: PaidSubscriptionProduct? {
        switch self {
        case .premiumMonthly: .monthly
        case .premiumYearly: .yearly
        case .premiumExpiring(let product, _): product
        case .freeTrial, .free: nil
        }
    }
}

struct AccountPlanPresentation: Equatable {
    let title: String
    let detail: String?

    static func make(state: SubscriptionPresentationState, now: Date = Date(), locale: Locale = .current) -> Self {
        let dateStyle = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        switch state {
        case .premiumMonthly(let expirationDate), .premiumYearly(let expirationDate):
            return Self(
                title: localized("Premium Active", locale: locale),
                detail: expirationDate.map {
                    String(format: localized("Renews on %@", locale: locale), locale: locale, $0.formatted(dateStyle))
                }
            )
        case .premiumExpiring(_, let expirationDate):
            return Self(
                title: localized("Premium Active · Auto-Renewal Off", locale: locale),
                detail: String(
                    format: localized("Available until %@.\nAfter this date you'll switch to the Free plan.", locale: locale),
                    locale: locale,
                    expirationDate.formatted(dateStyle)
                )
            )
        case .freeTrial(let expiresAt):
            let remaining = max(1, Int(ceil(expiresAt.timeIntervalSince(now) / 86_400)))
            return Self(
                title: localized("Free Trial", locale: locale),
                detail: String(format: localized("%lld days remaining.", locale: locale), locale: locale, remaining)
            )
        case .free:
            return Self(title: localized("Free Plan", locale: locale), detail: nil)
        }
    }

    private static func localized(_ key: String, locale: Locale, bundle: Bundle = .main) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        let localizedBundle = bundle.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? bundle
        return localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }
}

enum StoreProductLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case unavailable
    case failed
}

enum StorePurchaseState: Equatable, Sendable {
    case idle
    case purchasing
    case pending
    case cancelled
    case failed
    case verificationFailed
}
