import Foundation
import Observation
import SwiftData

enum MicrophonePermissionState: Equatable {
    case notDetermined
    case granted
    case denied
}

enum RecordingPhase: Equatable {
    case idle
    case requestingPermission
    case recording
    case review
    case preparingTranscription
    case transcribing
    case transcriptReview
    case authenticationRequired
    case extracting
    case eventDraftReview
    case extractionFailed
    case transcriptionFailed
    case permissionDenied
    case failed
}

enum TranscriptionLanguage: String, CaseIterable, Identifiable {
    case english
    case korean

    var id: Self { self }
    var locale: Locale { Locale(identifier: self == .english ? "en-US" : "ko-KR") }
    var localizedName: String { String(localized: self == .english ? "English" : "Korean") }
}

@MainActor
protocol AudioRecordingService: AnyObject {
    var permissionState: MicrophonePermissionState { get }
    func requestPermission() async -> Bool
    func startRecording(to url: URL) throws
    func stopRecording() -> TimeInterval
    func startPlayback(from url: URL, completion: @escaping () -> Void) throws
    func pausePlayback()
    func stopPlayback()
    func deactivateSession()
    func setInterruptionHandler(_ handler: @escaping () -> Void)
}

@MainActor
@Observable
final class RecordingController {
    private(set) var phase: RecordingPhase = .idle
    private(set) var permissionState: MicrophonePermissionState
    private(set) var petID: UUID
    private(set) var petName: String
    private(set) var temporaryAudioURL: URL?
    private(set) var duration: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var userMessage: String?
    private(set) var recordedAt = Date()
    private(set) var recordingTimeZoneIdentifier = TimeZone.current.identifier
    private(set) var recordingTranscriptionLanguage: TranscriptionLanguage = .english
    private(set) var extractedEvents: [ExtractedEventDraft] = []
    private(set) var editableEventDrafts: [EditableEventDraft] = []
    private(set) var extractionError: EventExtractionError?
    var transcriptDraft = ""
    var transcriptionLanguage: TranscriptionLanguage = .english

    private let audioService: AudioRecordingService
    private let temporaryDirectory: URL
    private let fileManager: FileManager
    private let transcriptionService: SpeechTranscriptionService
    private let extractionService: EventExtractionService
    private let currentTimeZoneIdentifier: () -> String
    private var durationTask: Task<Void, Never>?
    private var recordingStartedAt: Date?
    private var transcriptionSessionID = UUID()

    init(
        petID: UUID,
        petName: String,
        audioService: AudioRecordingService,
        transcriptionService: SpeechTranscriptionService,
        extractionService: EventExtractionService = BackendEventExtractionService(),
        currentTimeZoneIdentifier: @escaping () -> String = { TimeZone.current.identifier },
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default
    ) {
        self.petID = petID
        self.petName = petName
        self.audioService = audioService
        self.transcriptionService = transcriptionService
        self.extractionService = extractionService
        self.currentTimeZoneIdentifier = currentTimeZoneIdentifier
        self.temporaryDirectory = temporaryDirectory
        self.fileManager = fileManager
        permissionState = audioService.permissionState
        audioService.setInterruptionHandler { [weak self] in
            self?.handleInterruption()
        }
    }

    convenience init(petID: UUID, petName: String) {
        self.init(
            petID: petID,
            petName: petName,
            audioService: AVAudioRecordingService(),
            transcriptionService: AppleSpeechTranscriptionService()
        )
    }

    func beginRecording() async {
        guard phase == .idle || phase == .review else { return }
        userMessage = nil

        if phase == .review {
            discardTemporaryFile()
        }

        permissionState = audioService.permissionState
        if permissionState == .notDetermined {
            phase = .requestingPermission
            permissionState = await audioService.requestPermission() ? .granted : .denied
        }

        guard permissionState == .granted else {
            phase = .permissionDenied
            return
        }

        let url = temporaryDirectory
            .appending(path: "pettale-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        do {
            try audioService.startRecording(to: url)
            recordedAt = Date()
            recordingTimeZoneIdentifier = currentTimeZoneIdentifier()
            recordingTranscriptionLanguage = transcriptionLanguage
            temporaryAudioURL = url
            duration = 0
            recordingStartedAt = Date()
            phase = .recording
            startDurationUpdates()
        } catch {
            discardTemporaryFile()
            phase = .failed
            userMessage = String(localized: "Recording could not start. Please try again.")
        }
    }

    func finishRecording() {
        guard phase == .recording else { return }
        durationTask?.cancel()
        durationTask = nil
        let measuredDuration = audioService.stopRecording()
        if measuredDuration > 0 {
            duration = measuredDuration
        } else if let recordingStartedAt {
            duration = Date().timeIntervalSince(recordingStartedAt)
        }
        self.recordingStartedAt = nil
        phase = .review
    }

    func cancelRecording() {
        guard phase == .recording else { return }
        cleanup()
    }

    func togglePlayback() {
        guard phase == .review, let temporaryAudioURL else { return }
        if isPlaying {
            audioService.pausePlayback()
            isPlaying = false
            return
        }
        do {
            try audioService.startPlayback(from: temporaryAudioURL) { [weak self] in
                self?.isPlaying = false
            }
            isPlaying = true
        } catch {
            isPlaying = false
            userMessage = String(localized: "Recording could not be played. Please try again.")
        }
    }

    func beginTranscription() async {
        guard phase == .review || phase == .transcriptionFailed,
              let temporaryAudioURL else { return }
        stopPlaybackForTransition()
        userMessage = nil
        transcriptDraft = ""
        let sessionID = UUID()
        transcriptionSessionID = sessionID

        phase = .preparingTranscription
        do {
            let transcript = try await transcriptionService.transcribe(
                audioURL: temporaryAudioURL,
                locale: recordingTranscriptionLanguage.locale
            ) { [weak self] progress in
                guard let self, self.transcriptionSessionID == sessionID else { return }
                self.phase = progress == .preparing ? .preparingTranscription : .transcribing
            }
            guard transcriptionSessionID == sessionID, !Task.isCancelled else { return }
            transcriptDraft = transcript
            phase = .transcriptReview
        } catch is CancellationError {
            return
        } catch let error as SpeechTranscriptionError {
            guard transcriptionSessionID == sessionID else { return }
            phase = .transcriptionFailed
            userMessage = localizedMessage(for: error)
        } catch {
            guard transcriptionSessionID == sessionID else { return }
            phase = .transcriptionFailed
            userMessage = String(localized: "Transcription failed. Please try again.")
        }
    }

    func retryTranscription() async {
        guard phase == .transcriptionFailed else { return }
        await beginTranscription()
    }

    func continueToExtraction(session: PettaleSession?, knownPetNames: [String]) async {
        guard phase == .transcriptReview || phase == .authenticationRequired || phase == .extractionFailed else { return }
        guard !transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .extractionFailed
            extractionError = .invalidResponse
            userMessage = String(localized: "Review the transcript before continuing.")
            return
        }
        guard let session, !session.isExpired else {
            phase = .authenticationRequired
            return
        }
        phase = .extracting
        extractionError = nil
        userMessage = nil
        do {
            let result = try await extractionService.extract(
                transcript: transcriptDraft,
                recordedAt: recordedAt,
                petID: petID,
                petName: petName,
                knownPetNames: knownPetNames,
                spokenLanguage: recordingTranscriptionLanguage.locale.identifier,
                timeZone: recordingTimeZoneIdentifier,
                session: session
            )
            extractedEvents = result.events
            editableEventDrafts = result.events.map(EditableEventDraft.init(extracted:))
            phase = .eventDraftReview
        } catch let error as EventExtractionError {
            extractionError = error
            phase = .extractionFailed
            userMessage = error == .quotaExceeded
                ? WorkflowPresentation.quotaMessage()
                : String(localized: "We couldn't organize this recording. Please try again shortly.")
        } catch {
            extractionError = .temporarilyUnavailable
            phase = .extractionFailed
            userMessage = String(localized: "We couldn't organize this recording. Please try again shortly.")
        }
    }

    func returnToTranscriptReview() {
        guard phase == .eventDraftReview || phase == .extractionFailed || phase == .authenticationRequired else { return }
        extractedEvents = []
        editableEventDrafts = []
        extractionError = nil
        userMessage = nil
        phase = .transcriptReview
    }

    func recordAgain() async {
        guard phase == .review || phase == .transcriptReview || phase == .transcriptionFailed || phase == .eventDraftReview || phase == .extractionFailed || phase == .authenticationRequired else { return }
        cleanup()
        phase = .idle
        await beginRecording()
    }

    func discard() {
        cleanup()
        phase = .idle
    }

    func handleInactive() {
        if phase == .recording {
            finishRecording()
        } else if isPlaying {
            audioService.pausePlayback()
            isPlaying = false
        }
    }

    func cleanup() {
        transcriptionSessionID = UUID()
        transcriptDraft = ""
        extractedEvents = []
        editableEventDrafts = []
        extractionError = nil
        durationTask?.cancel()
        durationTask = nil
        audioService.stopPlayback()
        if phase == .recording {
            _ = audioService.stopRecording()
        }
        audioService.deactivateSession()
        isPlaying = false
        recordingStartedAt = nil
        duration = 0
        discardTemporaryFile()
        phase = .idle
    }

    private func stopPlaybackForTransition() {
        audioService.stopPlayback()
        isPlaying = false
    }

    private func localizedMessage(for error: SpeechTranscriptionError) -> String {
        switch error {
        case .unavailable:
            String(localized: "Speech transcription is unavailable on this device.")
        case .unsupportedLanguage:
            String(localized: "The selected language is unavailable.")
        case .assetUnavailable, .assetPreparationFailed:
            String(localized: "Speech resources could not be prepared. Please try again.")
        case .audioDecodeFailed:
            String(localized: "The recording could not be read. Please record again.")
        case .transcriptionFailed:
            String(localized: "Transcription failed. Please try again.")
        case .emptyTranscript:
            String(localized: "No speech was detected. Please try again.")
        }
    }

    func clearUserMessage() {
        userMessage = nil
    }

    func setPreferredTranscriptionLanguage(_ language: TranscriptionLanguage) {
        transcriptionLanguage = language
    }

    func replaceDraft(_ draft: EditableEventDraft) {
        guard let index = editableEventDrafts.firstIndex(where: { $0.id == draft.id }) else { return }
        var normalized = draft
        normalized.normalize()
        editableEventDrafts[index] = normalized
    }

    func addDraft() -> EditableEventDraft {
        let draft = EditableEventDraft(occurredAt: recordedAt)
        editableEventDrafts.append(draft)
        return draft
    }

    func removeDraft(id: UUID) {
        editableEventDrafts.removeAll { $0.id == id }
    }

    func saveReviewedEvents(in context: ModelContext) throws {
        guard phase == .eventDraftReview else { return }
        _ = try EventDraftSaveService.save(
            petID: petID,
            approvedTranscript: transcriptDraft,
            recordedAt: recordedAt,
            drafts: editableEventDrafts,
            in: context
        )
        cleanup()
    }

    static func formattedDuration(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded(.down)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func startDurationUpdates() {
        durationTask?.cancel()
        durationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, let recordingStartedAt = self.recordingStartedAt else { return }
                self.duration = Date().timeIntervalSince(recordingStartedAt)
            }
        }
    }

    private func handleInterruption() {
        if phase == .recording {
            finishRecording()
            userMessage = String(localized: "Recording stopped because audio was interrupted.")
        } else if isPlaying {
            isPlaying = false
        }
    }

    private func discardTemporaryFile() {
        guard let temporaryAudioURL else { return }
        try? fileManager.removeItem(at: temporaryAudioURL)
        self.temporaryAudioURL = nil
    }
}
