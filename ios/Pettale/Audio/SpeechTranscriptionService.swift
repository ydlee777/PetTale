import AVFoundation
import Foundation
import Speech

enum SpeechTranscriptionProgress: Equatable {
    case preparing
    case transcribing
}

enum SpeechTranscriptionError: Error, Equatable {
    case unavailable
    case unsupportedLanguage
    case assetUnavailable
    case assetPreparationFailed
    case audioDecodeFailed
    case transcriptionFailed
    case emptyTranscript
}

@MainActor
protocol SpeechTranscriptionService: AnyObject {
    func transcribe(
        audioURL: URL,
        locale: Locale,
        progress: @escaping (SpeechTranscriptionProgress) -> Void
    ) async throws -> String
}

@MainActor
final class AppleSpeechTranscriptionService: SpeechTranscriptionService {
    func transcribe(
        audioURL: URL,
        locale requestedLocale: Locale,
        progress: @escaping (SpeechTranscriptionProgress) -> Void
    ) async throws -> String {
        guard SpeechTranscriber.isAvailable else {
            throw SpeechTranscriptionError.unavailable
        }

        progress(.preparing)
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            throw SpeechTranscriptionError.unsupportedLanguage
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        try await prepareAssets(for: transcriber)
        try Task.checkCancellation()

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: audioURL)
        } catch {
            throw SpeechTranscriptionError.audioDecodeFailed
        }

        progress(.transcribing)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        let resultTask = Task<String, Error> {
            var finalizedText = ""
            for try await result in transcriber.results {
                guard result.isFinal else { continue }
                let nextText = String(result.text.characters)
                if let previous = finalizedText.last,
                   let next = nextText.first,
                   !previous.isWhitespace,
                   !next.isWhitespace {
                    finalizedText.append(" ")
                }
                finalizedText += nextText
            }
            return finalizedText
        }

        do {
            if let lastSampleTime = try await analyzer.analyzeSequence(from: audioFile) {
                try await analyzer.finalizeAndFinish(through: lastSampleTime)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            let transcript = try await resultTask.value
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcript.isEmpty else {
                throw SpeechTranscriptionError.emptyTranscript
            }
            return transcript
        } catch is CancellationError {
            resultTask.cancel()
            await analyzer.cancelAndFinishNow()
            throw CancellationError()
        } catch let error as SpeechTranscriptionError {
            resultTask.cancel()
            throw error
        } catch {
            resultTask.cancel()
            throw SpeechTranscriptionError.transcriptionFailed
        }
    }

    private func prepareAssets(for transcriber: SpeechTranscriber) async throws {
        switch await AssetInventory.status(forModules: [transcriber]) {
        case .installed:
            return
        case .unsupported:
            throw SpeechTranscriptionError.assetUnavailable
        case .supported, .downloading:
            do {
                guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
                    throw SpeechTranscriptionError.assetUnavailable
                }
                try await request.downloadAndInstall()
                guard await AssetInventory.status(forModules: [transcriber]) == .installed else {
                    throw SpeechTranscriptionError.assetPreparationFailed
                }
            } catch let error as SpeechTranscriptionError {
                throw error
            } catch {
                throw SpeechTranscriptionError.assetPreparationFailed
            }
        @unknown default:
            throw SpeechTranscriptionError.assetUnavailable
        }
    }
}
