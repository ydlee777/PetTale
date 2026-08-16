import XCTest
@testable import Pettale

final class PettaleTests: XCTestCase {
    func testAppFoundationLoads() {
        XCTAssertNotNil(HomeView())
    }
}

