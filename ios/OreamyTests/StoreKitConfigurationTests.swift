import Foundation
import XCTest
@testable import Oreamy

final class StoreKitConfigurationTests: XCTestCase {
    func testApprovedProductsAndPeriodsMatchConfiguration() throws {
        let subscriptions = try configuredSubscriptions()
        XCTAssertEqual(subscriptions.compactMap { $0["productID"] as? String }, [
            OreamySubscriptionProduct.monthlyID,
            OreamySubscriptionProduct.annualID
        ])
        XCTAssertEqual(subscriptions.compactMap { $0["recurringSubscriptionPeriod"] as? String }, ["P1M", "P1Y"])
        XCTAssertTrue(subscriptions.allSatisfy { ($0["displayPrice"] as? String)?.isEmpty == false })
    }

    func testProductsHaveEnglishAndKoreanLocalizedMetadata() throws {
        for subscription in try configuredSubscriptions() {
            let localizations = try XCTUnwrap(subscription["localizations"] as? [[String: Any]])
            let locales = Set(localizations.compactMap { $0["locale"] as? String })
            XCTAssertTrue(locales.contains("en_US"))
            XCTAssertTrue(locales.contains("ko"))
            XCTAssertTrue(localizations.allSatisfy { ($0["displayName"] as? String)?.isEmpty == false })
        }
    }

    private func configuredSubscriptions() throws -> [[String: Any]] {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Oreamy", withExtension: "storekit"))
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let groups = try XCTUnwrap(root["subscriptionGroups"] as? [[String: Any]])
        return try XCTUnwrap(groups.first?["subscriptions"] as? [[String: Any]])
    }
}
