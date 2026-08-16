import Foundation
import XCTest
@testable import Pettale

@MainActor
final class RecordingControllerTests: XCTestCase {
    func testInitialStateAndPetAssociation() {
        let id = UUID()
        let controller = makeController(petID: id, service: FakeAudioRecordingService())
        XCTAssertEqual(controller.phase, .idle)
        XCTAssertEqual(controller.petID, id)
        XCTAssertEqual(controller.petName, "Oreo")
        XCTAssertNil(controller.temporaryAudioURL)
    }

    func testDeniedPermissionDoesNotStartRecording() async {
        let service = FakeAudioRecordingService(permissionState: .denied)
        let controller = makeController(service: service)
        await controller.beginRecording()
        XCTAssertEqual(controller.phase, .permissionDenied)
        XCTAssertFalse(service.didStartRecording)
    }

    func testUndeterminedPermissionRequestsAndStartsWhenGranted() async {
        let service = FakeAudioRecordingService(permissionState: .notDetermined, permissionRequestResult: true)
        let controller = makeController(service: service)
        await controller.beginRecording()
        XCTAssertTrue(service.didRequestPermission)
        XCTAssertEqual(controller.permissionState, .granted)
        XCTAssertEqual(controller.phase, .recording)
    }

    func testStartAndStopTransitionsToReview() async {
        let service = FakeAudioRecordingService()
        service.stopDuration = 12.4
        let controller = makeController(service: service)
        await controller.beginRecording()
        XCTAssertEqual(controller.phase, .recording)
        controller.finishRecording()
        XCTAssertEqual(controller.phase, .review)
        XCTAssertEqual(controller.duration, 12.4)
        controller.cleanup()
    }

    func testRecordAgainDeletesPreviousTemporaryFile() async throws {
        let service = FakeAudioRecordingService()
        let controller = makeController(service: service)
        await controller.beginRecording()
        let firstURL = try XCTUnwrap(controller.temporaryAudioURL)
        controller.finishRecording()
        await controller.recordAgain()
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertNotEqual(controller.temporaryAudioURL, firstURL)
        XCTAssertEqual(controller.phase, .recording)
        controller.cleanup()
    }

    func testDiscardDeletesTemporaryAudio() async throws {
        let controller = makeController(service: FakeAudioRecordingService())
        await controller.beginRecording()
        let url = try XCTUnwrap(controller.temporaryAudioURL)
        controller.finishRecording()
        controller.discard()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNil(controller.temporaryAudioURL)
        XCTAssertEqual(controller.phase, .idle)
    }

    func testCleanupStopsActiveRecordingAndDeletesFile() async throws {
        let service = FakeAudioRecordingService()
        let controller = makeController(service: service)
        await controller.beginRecording()
        let url = try XCTUnwrap(controller.temporaryAudioURL)
        controller.cleanup()
        XCTAssertTrue(service.didStopRecording)
        XCTAssertTrue(service.didDeactivate)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(controller.phase, .idle)
    }

    func testInvalidTransitionsAreIgnored() {
        let service = FakeAudioRecordingService()
        let controller = makeController(service: service)
        controller.finishRecording()
        controller.togglePlayback()
        XCTAssertEqual(controller.phase, .idle)
        XCTAssertFalse(service.didStopRecording)
        XCTAssertFalse(service.didStartPlayback)
    }

    func testReviewPlaybackCanPlayPauseAndFinish() async {
        let service = FakeAudioRecordingService()
        let controller = makeController(service: service)
        await controller.beginRecording()
        controller.finishRecording()
        controller.togglePlayback()
        XCTAssertTrue(controller.isPlaying)
        XCTAssertTrue(service.didStartPlayback)
        controller.togglePlayback()
        XCTAssertFalse(controller.isPlaying)
        XCTAssertTrue(service.didPausePlayback)
        controller.togglePlayback()
        service.finishPlayback()
        XCTAssertFalse(controller.isPlaying)
        controller.cleanup()
    }

    func testInactiveRecordingStopsSafelyForReview() async {
        let controller = makeController(service: FakeAudioRecordingService())
        await controller.beginRecording()
        controller.handleInactive()
        XCTAssertEqual(controller.phase, .review)
        XCTAssertNotNil(controller.temporaryAudioURL)
        controller.cleanup()
    }

    func testCancelRecordingDeletesTemporaryFileWithoutReview() async throws {
        let service = FakeAudioRecordingService()
        let controller = makeController(service: service)
        await controller.beginRecording()
        let url = try XCTUnwrap(controller.temporaryAudioURL)
        controller.cancelRecording()
        XCTAssertTrue(service.didStopRecording)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNil(controller.temporaryAudioURL)
        XCTAssertEqual(controller.phase, .idle)
    }

    func testDoneEntersReviewAndPreservesTemporaryFile() async throws {
        let controller = makeController(service: FakeAudioRecordingService())
        await controller.beginRecording()
        let url = try XCTUnwrap(controller.temporaryAudioURL)
        controller.finishRecording()
        XCTAssertEqual(controller.phase, .review)
        XCTAssertEqual(controller.temporaryAudioURL, url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        controller.cleanup()
    }

    func testDurationFormatting() {
        XCTAssertEqual(RecordingController.formattedDuration(0), "00:00")
        XCTAssertEqual(RecordingController.formattedDuration(14.9), "00:14")
        XCTAssertEqual(RecordingController.formattedDuration(65), "01:05")
    }

    private func makeController(
        petID: UUID = UUID(),
        service: FakeAudioRecordingService
    ) -> RecordingController {
        RecordingController(
            petID: petID,
            petName: "Oreo",
            audioService: service
        )
    }
}

@MainActor
private final class FakeAudioRecordingService: AudioRecordingService {
    var permissionState: MicrophonePermissionState
    var permissionRequestResult: Bool
    var stopDuration: TimeInterval = 3
    var didRequestPermission = false
    var didStartRecording = false
    var didStopRecording = false
    var didStartPlayback = false
    var didPausePlayback = false
    var didDeactivate = false
    private var interruptionHandler: (() -> Void)?
    private var playbackCompletion: (() -> Void)?

    init(
        permissionState: MicrophonePermissionState = .granted,
        permissionRequestResult: Bool = true
    ) {
        self.permissionState = permissionState
        self.permissionRequestResult = permissionRequestResult
    }

    func requestPermission() async -> Bool {
        didRequestPermission = true
        permissionState = permissionRequestResult ? .granted : .denied
        return permissionRequestResult
    }

    func startRecording(to url: URL) throws {
        didStartRecording = true
        try Data([0x01]).write(to: url)
    }

    func stopRecording() -> TimeInterval {
        didStopRecording = true
        return stopDuration
    }

    func startPlayback(from url: URL, completion: @escaping () -> Void) throws {
        didStartPlayback = true
        playbackCompletion = completion
    }

    func pausePlayback() {
        didPausePlayback = true
    }
    func stopPlayback() {}

    func deactivateSession() {
        didDeactivate = true
    }

    func setInterruptionHandler(_ handler: @escaping () -> Void) {
        interruptionHandler = handler
    }

    func finishPlayback() {
        playbackCompletion?()
        playbackCompletion = nil
    }
}
