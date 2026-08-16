import AVFoundation
import Foundation

@MainActor
final class AVAudioRecordingService: NSObject, AudioRecordingService, @preconcurrency AVAudioPlayerDelegate {
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var playbackCompletion: (() -> Void)?
    private var interruptionHandler: (() -> Void)?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionInterrupted(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var permissionState: MicrophonePermissionState {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: .granted
        case .denied: .denied
        default: .notDetermined
        }
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording(to url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 64_000
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw CocoaError(.fileWriteUnknown)
        }
        self.recorder = recorder
    }

    func stopRecording() -> TimeInterval {
        guard let recorder else { return 0 }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        deactivateSession()
        return duration
    }

    func startPlayback(from url: URL, completion: @escaping () -> Void) throws {
        if let player, player.url == url, !player.isPlaying {
            playbackCompletion = completion
            guard player.play() else {
                throw CocoaError(.fileReadUnknown)
            }
            return
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        playbackCompletion = completion
        self.player = player
        guard player.play() else {
            self.player = nil
            throw CocoaError(.fileReadUnknown)
        }
    }

    func pausePlayback() {
        player?.pause()
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        playbackCompletion = nil
        deactivateSession()
    }

    func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func setInterruptionHandler(_ handler: @escaping () -> Void) {
        interruptionHandler = handler
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        let completion = playbackCompletion
        playbackCompletion = nil
        deactivateSession()
        completion?()
    }

    @objc private func audioSessionInterrupted(_ notification: Notification) {
        guard let rawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: rawValue) == .began else { return }
        recorder?.stop()
        recorder = nil
        player?.stop()
        player = nil
        interruptionHandler?()
    }
}
