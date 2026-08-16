# Pettale speech transcription

Step 2B uses the iOS 26 `SpeechAnalyzer` and `SpeechTranscriber` APIs. The user explicitly selects English (`en-US`) or Korean (`ko-KR`) for each recording; the UI language is not used as the spoken-language signal.

Before analysis, Pettale checks `SpeechTranscriber.isAvailable`, resolves an Apple-supported equivalent locale, and uses `AssetInventory` to check and, when supported, download/install the required system-managed speech asset. Failures are presented as localized retryable states.

The temporary AAC `.m4a` is opened as an `AVAudioFile`. `SpeechAnalyzer.analyzeSequence(from:)` uses Speech's `AVAudioFile` input helper to decode the compressed file and supply analyzer-compatible PCM input without creating another file. Pettale then calls `finalizeAndFinish(through:)` and collects final `SpeechTranscriber.Result.text` values. No converted audio is persisted.

The resulting transcript is an editable in-memory session draft. Audio and transcript are deleted when the user discards or records again. After the user approves it and taps Continue, only the transcript and minimal extraction context are sent through the authenticated Pettale backend; neither is persisted by the backend. Physical-device English and Korean quality/latency validation remains mandatory before the technology choice can be accepted.
