import SwiftUI
import UIKit

struct RecordingFlowView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller: RecordingController
    let close: () -> Void

    init(petID: UUID, petName: String, close: @escaping () -> Void) {
        _controller = State(initialValue: RecordingController(petID: petID, petName: petName))
        self.close = close
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()
                Text(controller.petName)
                    .font(.largeTitle.bold())
                content
                Spacer()
            }
            .padding()
            .navigationTitle("Voice Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if controller.phase == .review || controller.phase == .transcriptReview || controller.phase == .transcriptionFailed {
                        Button("Discard", role: .destructive, action: discardAndClose)
                            .accessibilityLabel("Discard recording")
                    } else if controller.phase != .recording {
                        Button("Cancel", role: .cancel, action: cancelAndClose)
                    }
                }
            }
            .interactiveDismissDisabled(controller.phase == .recording)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    controller.handleInactive()
                }
            }
            .onDisappear {
                controller.cleanup()
            }
            .task {
                if controller.phase == .idle {
                    await controller.beginRecording()
                }
            }
            .alert("Recording Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(controller.userMessage ?? "Please try again.")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch controller.phase {
        case .idle, .requestingPermission:
            ProgressView("Preparing Microphone")
        case .recording:
            recordingContent
        case .review:
            reviewContent
        case .preparingTranscription:
            transcriptionProgressContent(title: "Preparing transcription")
        case .transcribing:
            transcriptionProgressContent(title: "Transcribing")
        case .transcriptReview:
            transcriptReviewContent
        case .transcriptionFailed:
            transcriptionFailureContent
        case .permissionDenied:
            permissionDeniedContent
        case .failed:
            failedContent
        }
    }

    private var recordingContent: some View {
        VStack(spacing: 22) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            Text("Recording today's tale")
                .font(.title2)
            Text(RecordingController.formattedDuration(controller.duration))
                .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
            HStack(spacing: 20) {
                Button("Cancel", role: .destructive, action: cancelAndClose)
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.large)
                    .accessibilityLabel("Cancel recording")
                Button("Done", systemImage: "checkmark") {
                    controller.finishRecording()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("Finish recording")
            }
        }
    }

    private var reviewContent: some View {
        VStack(spacing: 22) {
            Image(systemName: "speaker.wave.2.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Recording Review")
                .font(.title2.bold())
            Text(RecordingController.formattedDuration(controller.duration))
                .font(.system(.title, design: .monospaced))
            Button(controller.isPlaying ? "Pause" : "Play", systemImage: controller.isPlaying ? "pause.fill" : "play.fill") {
                controller.togglePlayback()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel(controller.isPlaying ? "Pause recording" : "Play recording")
            Button("Record Again", systemImage: "arrow.counterclockwise") {
                Task { await controller.recordAgain() }
            }
            .accessibilityLabel("Discard and record again")
            Picker("Spoken Language", selection: $controller.transcriptionLanguage) {
                ForEach(TranscriptionLanguage.allCases) { language in
                    Text(language.localizedName).tag(language)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("Select the language spoken in this recording")
            Button("Continue") {
                Task { await controller.beginTranscription() }
            }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Transcribe this recording")
        }
    }

    private func transcriptionProgressContent(title: LocalizedStringKey) -> some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.title2.bold())
                .accessibilityAddTraits(.updatesFrequently)
            Text("This may take a moment while speech resources are prepared.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var transcriptReviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Here's what I heard")
                .font(.title2.bold())
            TextEditor(text: $controller.transcriptDraft)
                .frame(minHeight: 180)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Edit Transcript")
                .accessibilityHint("Review and correct the generated transcript")
            HStack {
                Button("Record Again", systemImage: "arrow.counterclockwise") {
                    Task { await controller.recordAgain() }
                }
                .accessibilityHint("Deletes this transcript and recording")
                Spacer()
                Button("Continue") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                    .accessibilityHint("Event extraction will be added in the next development step")
            }
            Text("Your transcript is a draft and has not been saved.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var transcriptionFailureContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Transcription failed")
                .font(.title2.bold())
            Text(controller.userMessage ?? String(localized: "Transcription failed. Please try again."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try Again") {
                Task { await controller.retryTranscription() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Retry transcription using the selected language")
            Button("Record Again") {
                Task { await controller.recordAgain() }
            }
        }
    }

    private var permissionDeniedContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Microphone Access Required")
                .font(.title2.bold())
            Text("Allow microphone access in Settings to record your pet's tale.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings", systemImage: "gear") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var failedContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Recording Unavailable")
                .font(.title2.bold())
            Button("Try Again") {
                controller.discard()
                Task { await controller.beginRecording() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func discardAndClose() {
        controller.discard()
        close()
    }

    private func cancelAndClose() {
        controller.cancelRecording()
        close()
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { controller.userMessage != nil },
            set: { if !$0 { controller.clearUserMessage() } }
        )
    }
}
