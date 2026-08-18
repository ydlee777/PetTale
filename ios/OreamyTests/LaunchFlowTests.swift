import XCTest
@testable import Oreamy

final class LaunchFlowTests: XCTestCase {
    func testZeroPetsRoutesToWelcomeAfterIntro() {
        var flow = OreamyLaunchFlow()
        XCTAssertEqual(flow.destination, .intro)
        flow.completeIntro(petCount: 0)
        XCTAssertEqual(flow.destination, .welcome)
    }

    func testOneOrMultiplePetsRouteToHomeAfterIntro() {
        for count in [1, 3] {
            var flow = OreamyLaunchFlow()
            flow.completeIntro(petCount: count)
            XCTAssertEqual(flow.destination, .home)
        }
    }

    func testGetStartedAndCancelReturnToWelcome() {
        var flow = OreamyLaunchFlow()
        flow.completeIntro(petCount: 0)
        flow.getStarted()
        XCTAssertEqual(flow.destination, .firstPetCreation)
        flow.cancelFirstPetCreation()
        XCTAssertEqual(flow.destination, .welcome)
    }

    func testFirstPetSaveRoutesToHome() {
        var flow = OreamyLaunchFlow()
        flow.completeIntro(petCount: 0)
        flow.getStarted()
        flow.petsDidChange(count: 1)
        XCTAssertEqual(flow.destination, .home)
    }

    func testRelaunchRoutingRemainsPetCountDriven() {
        var emptyRelaunch = OreamyLaunchFlow()
        emptyRelaunch.completeIntro(petCount: 0)
        XCTAssertEqual(emptyRelaunch.destination, .welcome)
        var existingUserRelaunch = OreamyLaunchFlow()
        existingUserRelaunch.completeIntro(petCount: 1)
        XCTAssertEqual(existingUserRelaunch.destination, .home)
    }

    func testOnboardingDoesNotMutateExistingPetIdentity() {
        let ids = [UUID(), UUID()]
        var flow = OreamyLaunchFlow()
        flow.completeIntro(petCount: ids.count)
        XCTAssertEqual(ids.count, 2)
        XCTAssertEqual(flow.destination, .home)
    }

    func testDuplicateIntroCompletionIsHarmless() {
        var flow = OreamyLaunchFlow()
        flow.completeIntro(petCount: 0)
        flow.completeIntro(petCount: 5)
        XCTAssertEqual(flow.destination, .welcome)
    }

    func testReduceMotionRemovesScaleAndMotionButKeepsShortDuration() {
        let normal = OreamyIntroAnimationPlan.resolve(reduceMotion: false)
        let reduced = OreamyIntroAnimationPlan.resolve(reduceMotion: true)
        XCTAssertTrue(normal.usesScale)
        XCTAssertTrue(normal.usesMotion)
        XCTAssertFalse(reduced.usesScale)
        XCTAssertFalse(reduced.usesMotion)
        XCTAssertEqual(reduced.duration, normal.duration)
    }

    func testLaunchFlowRequiresNoAuthenticationSubscriptionOrNetworkInput() {
        var flow = OreamyLaunchFlow()
        flow.completeIntro(petCount: 0)
        flow.getStarted()
        XCTAssertEqual(flow.destination, .firstPetCreation)
    }
}
