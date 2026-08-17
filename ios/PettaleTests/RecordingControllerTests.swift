import Foundation
import SwiftData
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

    func testAudioReviewStartsTranscription() async {
        let speech = FakeSpeechTranscriptionService()
        let controller = makeController(service: FakeAudioRecordingService(), transcriptionService: speech)
        await controller.beginRecording()
        controller.finishRecording()
        await controller.beginTranscription()
        XCTAssertEqual(speech.callCount, 1)
    }

    func testPreparingTranscriptionState() async {
        let speech = FakeSpeechTranscriptionService()
        speech.progressStates = [.preparing]
        speech.suspends = true
        let controller = makeController(service: FakeAudioRecordingService(), transcriptionService: speech)
        await controller.beginRecording()
        controller.finishRecording()
        let task = Task { await controller.beginTranscription() }
        await Task.yield()
        XCTAssertEqual(controller.phase, .preparingTranscription)
        speech.resume(at: 0, with: .success("Oreo ate."))
        await task.value
    }

    func testTranscribingState() async {
        let speech = FakeSpeechTranscriptionService()
        speech.progressStates = [.preparing, .transcribing]
        speech.suspends = true
        let controller = makeController(service: FakeAudioRecordingService(), transcriptionService: speech)
        await controller.beginRecording()
        controller.finishRecording()
        let task = Task { await controller.beginTranscription() }
        await Task.yield()
        XCTAssertEqual(controller.phase, .transcribing)
        speech.resume(at: 0, with: .success("Oreo ate."))
        await task.value
    }

    func testSuccessfulTranscriptBecomesEditableDraft() async {
        let speech = FakeSpeechTranscriptionService()
        speech.result = .success("오늘 오레오가 잘 먹었어.")
        let controller = makeController(service: FakeAudioRecordingService(), transcriptionService: speech)
        await controller.beginRecording()
        controller.finishRecording()
        await controller.beginTranscription()
        XCTAssertEqual(controller.phase, .transcriptReview)
        XCTAssertEqual(controller.transcriptDraft, "오늘 오레오가 잘 먹었어.")
        controller.transcriptDraft = "오늘 오레오가 밥을 잘 먹었어."
        XCTAssertEqual(controller.transcriptDraft, "오늘 오레오가 밥을 잘 먹었어.")
        controller.cleanup()
    }

    func testRecordingCapturesPreferredLanguageForItsSession() async {
        let speech = FakeSpeechTranscriptionService()
        let controller = makeController(service: FakeAudioRecordingService(), transcriptionService: speech)
        controller.setPreferredTranscriptionLanguage(.korean)
        await controller.beginRecording()
        controller.setPreferredTranscriptionLanguage(.english)
        controller.finishRecording()
        await controller.beginTranscription()

        XCTAssertEqual(controller.recordingTranscriptionLanguage, .korean)
        XCTAssertEqual(speech.receivedLocale?.identifier, "ko-KR")
        XCTAssertEqual(controller.transcriptionLanguage, .english)
        controller.cleanup()
    }

    func testEmptyTranscriptShowsNoSpeechFailure() async {
        let speech = FakeSpeechTranscriptionService()
        speech.result = .failure(SpeechTranscriptionError.emptyTranscript)
        let controller = makeController(service: FakeAudioRecordingService(), transcriptionService: speech)
        await controller.beginRecording()
        controller.finishRecording()
        await controller.beginTranscription()
        XCTAssertEqual(controller.phase, .transcriptionFailed)
        XCTAssertEqual(controller.userMessage, String(localized: "No speech was detected. Please try again."))
        controller.cleanup()
    }

    func testTranscriptionFailureAndRetry() async {
        let speech = FakeSpeechTranscriptionService()
        speech.result = .failure(SpeechTranscriptionError.transcriptionFailed)
        let controller = makeController(service: FakeAudioRecordingService(), transcriptionService: speech)
        await controller.beginRecording()
        controller.finishRecording()
        await controller.beginTranscription()
        XCTAssertEqual(controller.phase, .transcriptionFailed)
        speech.result = .success("Oreo played.")
        await controller.retryTranscription()
        XCTAssertEqual(speech.callCount, 2)
        XCTAssertEqual(controller.phase, .transcriptReview)
        XCTAssertEqual(controller.transcriptDraft, "Oreo played.")
        controller.cleanup()
    }

    func testRecordAgainFromTranscriptClearsDraftAndAudio() async throws {
        let controller = makeController(service: FakeAudioRecordingService())
        await controller.beginRecording()
        let oldURL = try XCTUnwrap(controller.temporaryAudioURL)
        controller.finishRecording()
        await controller.beginTranscription()
        await controller.recordAgain()
        XCTAssertEqual(controller.transcriptDraft, "")
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path))
        XCTAssertEqual(controller.phase, .recording)
        controller.cleanup()
    }

    func testDiscardFromTranscriptClearsDraftAndAudio() async throws {
        let controller = makeController(service: FakeAudioRecordingService())
        await controller.beginRecording()
        let url = try XCTUnwrap(controller.temporaryAudioURL)
        controller.finishRecording()
        await controller.beginTranscription()
        controller.discard()
        XCTAssertEqual(controller.transcriptDraft, "")
        XCTAssertNil(controller.temporaryAudioURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testPetAssociationSurvivesTranscription() async {
        let petID = UUID()
        let controller = makeController(petID: petID, service: FakeAudioRecordingService())
        await controller.beginRecording()
        controller.finishRecording()
        await controller.beginTranscription()
        XCTAssertEqual(controller.petID, petID)
        XCTAssertEqual(controller.petName, "Oreo")
        controller.cleanup()
    }

    func testCancelledStaleTranscriptionCannotOverwriteNewSession() async {
        let speech = FakeSpeechTranscriptionService()
        speech.suspends = true
        let controller = makeController(service: FakeAudioRecordingService(), transcriptionService: speech)
        await controller.beginRecording()
        controller.finishRecording()
        let oldTask = Task { await controller.beginTranscription() }
        await Task.yield()
        controller.cleanup()
        await controller.beginRecording()
        controller.finishRecording()
        let newTask = Task { await controller.beginTranscription() }
        await Task.yield()
        speech.resume(at: 1, with: .success("New transcript"))
        await newTask.value
        speech.resume(at: 0, with: .success("Stale transcript"))
        await oldTask.value
        XCTAssertEqual(controller.transcriptDraft, "New transcript")
        XCTAssertEqual(controller.phase, .transcriptReview)
        controller.cleanup()
    }

    func testValidSessionStartsExtractionAndMapsMultipleDrafts() async {
        let extraction = FakeEventExtractionService()
        extraction.result = .success(.init(
            schemaVersion: "2",
            clientPetId: extraction.petID,
            diaryText: "A faithful diary.",
            events: [
                .init(category: .weight, eventType: "BODY_WEIGHT", occurredAt: Date(), numericValue: 6.2, unit: "KG", count: nil, durationMinutes: nil, description: nil),
                .init(category: .activity, eventType: "PLAY", occurredAt: Date(), numericValue: nil, unit: nil, count: nil, durationMinutes: 20, description: nil)
            ]
        ))
        let controller = makeController(petID: extraction.petID, service: FakeAudioRecordingService(), extractionService: extraction)
        await reachTranscriptReview(controller)
        await controller.continueToExtraction(session: validSession(), knownPetNames: ["Oreo", "Creamy"])
        XCTAssertEqual(controller.phase, .eventDraftReview)
        XCTAssertEqual(controller.extractedEvents.count, 2)
        XCTAssertEqual(controller.diaryDraft, "A faithful diary.")
        XCTAssertEqual(extraction.callCount, 1)
        XCTAssertEqual(extraction.receivedTranscript, "Oreo ate well.")
        XCTAssertEqual(extraction.receivedPetNames, ["Oreo", "Creamy"])
        XCTAssertEqual(extraction.receivedTimeZone, "Asia/Seoul")
        controller.cleanup()
    }

    func testDiaryDraftEditingDoesNotModifyApprovedTranscriptOrEventDrafts() async {
        let extraction = FakeEventExtractionService()
        extraction.result = .success(.init(schemaVersion: "2", clientPetId: extraction.petID, diaryText: "Original diary.", events: [
            .init(category: .activity, eventType: "PLAY", occurredAt: Date(), numericValue: nil, unit: nil, count: nil, durationMinutes: 20, description: nil)
        ]))
        let controller = makeController(petID: extraction.petID, service: FakeAudioRecordingService(), extractionService: extraction)
        await reachTranscriptReview(controller)
        let transcript = controller.transcriptDraft
        await controller.continueToExtraction(session: validSession(), knownPetNames: ["Oreo"])

        controller.diaryDraft = "User-approved diary."

        XCTAssertEqual(controller.transcriptDraft, transcript)
        XCTAssertEqual(controller.diaryDraft, "User-approved diary.")
        XCTAssertEqual(controller.editableEventDrafts.first?.durationMinutes, 20)
        XCTAssertEqual(extraction.callCount, 1)
        controller.cleanup()
    }

    func testMissingOrExpiredSessionRequestsAuthenticationWithoutDiscardingTranscript() async {
        let extraction = FakeEventExtractionService()
        let controller = makeController(service: FakeAudioRecordingService(), extractionService: extraction)
        await reachTranscriptReview(controller)
        await controller.continueToExtraction(session: nil, knownPetNames: ["Oreo"])
        XCTAssertEqual(controller.phase, .authenticationRequired)
        XCTAssertEqual(controller.transcriptDraft, "Oreo ate well.")
        await controller.continueToExtraction(
            session: PettaleSession(userID: UUID(), accessToken: "expired", expiresAt: .distantPast),
            knownPetNames: ["Oreo"]
        )
        XCTAssertEqual(controller.phase, .authenticationRequired)
        XCTAssertEqual(extraction.callCount, 0)
        controller.cleanup()
    }

    func testTranscriptSurvivesAuthenticationThenContinues() async {
        let extraction = FakeEventExtractionService()
        extraction.result = .success(.init(schemaVersion: "2", clientPetId: extraction.petID, diaryText: "A faithful diary.", events: [
            .init(category: .food, eventType: "ATE_WELL", occurredAt: Date(), numericValue: nil, unit: nil, count: nil, durationMinutes: nil, description: nil)
        ]))
        let controller = makeController(petID: extraction.petID, service: FakeAudioRecordingService(), extractionService: extraction)
        await reachTranscriptReview(controller)
        await controller.continueToExtraction(session: nil, knownPetNames: ["Oreo"])
        await controller.continueToExtraction(session: validSession(), knownPetNames: ["Oreo"])
        XCTAssertEqual(controller.phase, .eventDraftReview)
        XCTAssertEqual(extraction.receivedTranscript, "Oreo ate well.")
        controller.cleanup()
    }

    func testExtractionFailureIsRetryableAndQuotaIsDistinct() async {
        let extraction = FakeEventExtractionService()
        extraction.result = .failure(EventExtractionError.temporarilyUnavailable)
        let controller = makeController(service: FakeAudioRecordingService(), extractionService: extraction)
        await reachTranscriptReview(controller)
        await controller.continueToExtraction(session: validSession(), knownPetNames: ["Oreo"])
        XCTAssertEqual(controller.phase, .extractionFailed)
        XCTAssertEqual(controller.extractionError, .temporarilyUnavailable)
        extraction.result = .failure(EventExtractionError.quotaExceeded)
        await controller.continueToExtraction(session: validSession(), knownPetNames: ["Oreo"])
        XCTAssertEqual(controller.extractionError, .quotaExceeded)
        XCTAssertFalse(controller.transcriptDraft.isEmpty)
        controller.cleanup()
    }

    func testDiscardClearsTransientExtractionWithoutPersistence() async {
        let extraction = FakeEventExtractionService()
        extraction.result = .success(.init(schemaVersion: "2", clientPetId: extraction.petID, diaryText: "A faithful diary.", events: [
            .init(category: .health, eventType: "VOMITING", occurredAt: Date(), numericValue: nil, unit: nil, count: 1, durationMinutes: nil, description: nil)
        ]))
        let controller = makeController(petID: extraction.petID, service: FakeAudioRecordingService(), extractionService: extraction)
        await reachTranscriptReview(controller)
        await controller.continueToExtraction(session: validSession(), knownPetNames: ["Oreo"])
        controller.discard()
        XCTAssertEqual(controller.phase, .idle)
        XCTAssertTrue(controller.extractedEvents.isEmpty)
        XCTAssertTrue(controller.transcriptDraft.isEmpty)
        XCTAssertTrue(controller.diaryDraft.isEmpty)
    }

    func testDraftAddEditRemoveDoesNotPersistBeforeSave() async throws {
        let extraction = FakeEventExtractionService()
        extraction.result = .success(.init(schemaVersion: "2", clientPetId: extraction.petID, diaryText: "A faithful diary.", events: [
            .init(category: .weight, eventType: "BODY_WEIGHT", occurredAt: Date(), numericValue: 6.2, unit: "KG", count: nil, durationMinutes: nil, description: nil)
        ]))
        let controller = makeController(petID: extraction.petID, service: FakeAudioRecordingService(), extractionService: extraction)
        await reachTranscriptReview(controller)
        await controller.continueToExtraction(session: validSession(), knownPetNames: ["Oreo"])
        let container = try PettalePersistence.makeModelContainer(inMemory: true, cloudKitEnabled: false)

        var edited = try XCTUnwrap(controller.editableEventDrafts.first)
        edited.numericValue = 6.4
        controller.replaceDraft(edited)
        let added = controller.addDraft()
        controller.removeDraft(id: added.id)

        XCTAssertEqual(controller.editableEventDrafts.first?.numericValue, 6.4)
        XCTAssertEqual(controller.editableEventDrafts.count, 1)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PetRecord>()).isEmpty)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PetEvent>()).isEmpty)
        controller.cleanup()
    }

    func testSuccessfulSaveClearsTemporarySessionState() async throws {
        let extraction = FakeEventExtractionService()
        extraction.result = .success(.init(schemaVersion: "2", clientPetId: extraction.petID, diaryText: "A faithful diary.", events: [
            .init(category: .activity, eventType: "PLAY", occurredAt: Date(), numericValue: nil, unit: nil, count: nil, durationMinutes: 20, description: nil)
        ]))
        let controller = makeController(petID: extraction.petID, service: FakeAudioRecordingService(), extractionService: extraction)
        await reachTranscriptReview(controller)
        await controller.continueToExtraction(session: validSession(), knownPetNames: ["Oreo"])
        let container = try PettalePersistence.makeModelContainer(inMemory: true, cloudKitEnabled: false)
        container.mainContext.insert(try Pet(id: extraction.petID, name: "Oreo", species: .cat))
        try container.mainContext.save()

        try controller.saveReviewedEvents(in: container.mainContext)

        XCTAssertEqual(controller.phase, .idle)
        XCTAssertTrue(controller.transcriptDraft.isEmpty)
        XCTAssertTrue(controller.diaryDraft.isEmpty)
        XCTAssertTrue(controller.extractedEvents.isEmpty)
        XCTAssertTrue(controller.editableEventDrafts.isEmpty)
        XCTAssertNil(controller.temporaryAudioURL)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<PetRecord>()).count, 1)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<PetRecord>()).first?.diaryText, "A faithful diary.")
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<PetEvent>()).count, 1)
    }

    private func reachTranscriptReview(_ controller: RecordingController) async {
        await controller.beginRecording()
        controller.finishRecording()
        await controller.beginTranscription()
        XCTAssertEqual(controller.phase, .transcriptReview)
    }

    private func validSession() -> PettaleSession {
        PettaleSession(userID: UUID(), accessToken: "token", expiresAt: .distantFuture)
    }

    private func makeController(
        petID: UUID = UUID(),
        service: FakeAudioRecordingService,
        transcriptionService: FakeSpeechTranscriptionService = FakeSpeechTranscriptionService(),
        extractionService: FakeEventExtractionService = FakeEventExtractionService()
    ) -> RecordingController {
        RecordingController(
            petID: petID,
            petName: "Oreo",
            audioService: service,
            transcriptionService: transcriptionService,
            extractionService: extractionService,
            currentTimeZoneIdentifier: { "Asia/Seoul" }
        )
    }
}

@MainActor
private final class FakeEventExtractionService: EventExtractionService {
    var petID = UUID()
    var result: Result<EventExtractionResult, Error> = .failure(EventExtractionError.temporarilyUnavailable)
    var callCount = 0
    var receivedTranscript: String?
    var receivedPetNames: [String] = []
    var receivedTimeZone: String?

    func extract(
        transcript: String,
        recordedAt: Date,
        petID: UUID,
        petName: String,
        knownPetNames: [String],
        spokenLanguage: String,
        timeZone: String,
        session: PettaleSession
    ) async throws -> EventExtractionResult {
        callCount += 1
        receivedTranscript = transcript
        receivedPetNames = knownPetNames
        receivedTimeZone = timeZone
        return try result.get()
    }
}

@MainActor
private final class FakeSpeechTranscriptionService: SpeechTranscriptionService {
    var result: Result<String, Error> = .success("Oreo ate well.")
    var progressStates: [SpeechTranscriptionProgress] = [.preparing, .transcribing]
    var callCount = 0
    var receivedLocale: Locale?
    private var continuations: [CheckedContinuation<String, Error>] = []
    var suspends = false

    func transcribe(
        audioURL: URL,
        locale: Locale,
        progress: @escaping (SpeechTranscriptionProgress) -> Void
    ) async throws -> String {
        callCount += 1
        receivedLocale = locale
        progressStates.forEach(progress)
        if suspends {
            return try await withCheckedThrowingContinuation { continuations.append($0) }
        }
        return try result.get()
    }

    func resume(at index: Int, with result: Result<String, Error>) {
        continuations[index].resume(with: result)
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
