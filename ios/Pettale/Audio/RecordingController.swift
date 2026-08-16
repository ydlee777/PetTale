import Foundation
import Observation

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
    case permissionDenied
    case failed
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

    private let audioService: AudioRecordingService
    private let temporaryDirectory: URL
    private let fileManager: FileManager
    private var durationTask: Task<Void, Never>?
    private var recordingStartedAt: Date?

    init(
        petID: UUID,
        petName: String,
        audioService: AudioRecordingService,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default
    ) {
        self.petID = petID
        self.petName = petName
        self.audioService = audioService
        self.temporaryDirectory = temporaryDirectory
        self.fileManager = fileManager
        permissionState = audioService.permissionState
        audioService.setInterruptionHandler { [weak self] in
            self?.handleInterruption()
        }
    }

    convenience init(petID: UUID, petName: String) {
        self.init(petID: petID, petName: petName, audioService: AVAudioRecordingService())
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

    func recordAgain() async {
        guard phase == .review else { return }
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

    func clearUserMessage() {
        userMessage = nil
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
