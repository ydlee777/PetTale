import SwiftUI
import SwiftData
import UIKit

struct RecordingFlowView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var controller: RecordingController
    @State private var isAuthenticationPresented = false
    @State private var editingDraft: EditableEventDraft?
    @State private var saveErrorMessage: String?
    @AppStorage(TranscriptionLanguagePreference.key) private var preferredLanguageRawValue =
        TranscriptionLanguagePreference.initialLanguage().rawValue
    let knownPetNames: [String]
    let authentication: AuthenticationController
    let close: () -> Void

    init(
        petID: UUID,
        petName: String,
        knownPetNames: [String],
        authentication: AuthenticationController,
        close: @escaping () -> Void
    ) {
        _controller = State(initialValue: RecordingController(petID: petID, petName: petName))
        self.knownPetNames = knownPetNames
        self.authentication = authentication
        self.close = close
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(controller.petName)
                    .font(.largeTitle.bold())
                content
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Voice Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if controller.phase == .review || controller.phase == .transcriptReview || controller.phase == .transcriptionFailed || controller.phase == .eventDraftReview || controller.phase == .extractionFailed || controller.phase == .authenticationRequired {
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
            .sheet(isPresented: $isAuthenticationPresented) {
                NavigationStack { AuthenticationView(controller: authentication) }
            }
            .sheet(item: $editingDraft) { draft in
                EventDraftEditorView(
                    draft: draft,
                    save: controller.replaceDraft,
                    remove: { controller.removeDraft(id: draft.id) }
                )
            }
            .onChange(of: authentication.state) { _, state in
                if case .signedIn(let session) = state, controller.phase == .authenticationRequired {
                    isAuthenticationPresented = false
                    Task { await controller.continueToExtraction(session: session, knownPetNames: knownPetNames) }
                }
            }
            .task {
                if controller.phase == .idle {
                    controller.setPreferredTranscriptionLanguage(preferredLanguage)
                    await controller.beginRecording()
                }
            }
            .alert("Recording Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(controller.userMessage ?? "Please try again.")
            }
            .alert("Couldn't Save", isPresented: saveErrorBinding) {
                Button("Try Again", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Your events couldn't be saved. Try again.")
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
        case .authenticationRequired:
            authenticationRequiredContent
        case .extracting:
            extractionProgressContent
        case .eventDraftReview:
            eventDraftReviewContent
        case .extractionFailed:
            extractionFailureContent
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
        VStack(spacing: 18) {
            Text("Your recording is ready")
                .font(.title2.bold())
            Text(RecordingController.formattedDuration(controller.duration))
                .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
            Button(controller.isPlaying ? WorkflowPresentation.audioPause() : WorkflowPresentation.audioPlay(), systemImage: controller.isPlaying ? "pause.fill" : "play.fill") {
                controller.togglePlayback()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel(controller.isPlaying ? "Pause recording" : "Play recording")

            Menu {
                ForEach(TranscriptionLanguage.allCases) { language in
                    Button(language.localizedName) {
                        preferredLanguageRawValue = language.rawValue
                        TranscriptionLanguagePreference.save(language)
                    }
                }
            } label: {
                Label("Transcription Language: \(preferredLanguage.localizedName)", systemImage: "character.bubble")
                    .font(.footnote)
            }
            .accessibilityHint("Changes the language used for the next recording")

            HStack {
                Button("Record Again", systemImage: "arrow.counterclockwise") {
                    Task {
                        controller.setPreferredTranscriptionLanguage(preferredLanguage)
                        await controller.recordAgain()
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Discard and record again")
                Spacer()
                Button("Continue") {
                    Task { await controller.beginTranscription() }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Transcribe this recording")
            }
        }
        .padding(.top, 28)
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
                .frame(minHeight: 110, maxHeight: 220)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.2)))
                .accessibilityLabel("Edit Transcript")
                .accessibilityHint("Review and correct the generated transcript")
            Text("Correct anything that doesn't look right.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Button("Record Again", systemImage: "arrow.counterclockwise") {
                    Task { await controller.recordAgain() }
                }
                .accessibilityHint("Deletes this transcript and recording")
                Spacer()
                Button("Continue") {
                    Task { await continueToExtraction() }
                }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Extract event drafts using the Pettale service")
            }
            Text("Your transcript is a draft and has not been saved.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var authenticationRequiredContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            Text("Sign in to Extract Events")
                .font(.title2.bold())
            Text("Your transcript remains here while you sign in to the Pettale service.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Sign in with Apple") { isAuthenticationPresented = true }
                .buttonStyle(.borderedProminent)
            Button("Back") { controller.returnToTranscriptReview() }
        }
    }

    private var extractionProgressContent: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text("Organizing your pet's story...").font(.title2.bold())
            Text("Your recording has not been saved yet.")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 56)
    }

    private var eventDraftReviewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Today's Tale")
                    .font(.title2.bold())
                TextEditor(text: $controller.diaryDraft)
                    .frame(minHeight: 140, maxHeight: 260)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.2)))
                    .accessibilityLabel("Edit Today's Tale")
                    .accessibilityHint("Review and edit the diary text before saving")
                Text("Edit the story so it says exactly what you want to remember.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("I found \(controller.editableEventDrafts.count) events")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Transcript").font(.headline)
                    Text(controller.transcriptDraft)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Transcript: \(controller.transcriptDraft)")

                ForEach(controller.editableEventDrafts) { event in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: event.category.symbolName)
                            .font(.title2)
                            .foregroundStyle(.tint)
                            .frame(width: 30)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.category.localizedName).font(.headline)
                            if !event.eventType.isEmpty,
                               !(event.category == .weight && event.eventType == "BODY_WEIGHT") {
                                Text(event.localizedEventType)
                            }
                        if let value = event.numericValue {
                            Text("\(value.formatted()) \(event.unit.lowercased())")
                        }
                        if let count = event.count { Text("Count: \(count)") }
                        if let minutes = event.durationMinutes { Text("\(minutes) min") }
                        if !event.description.isEmpty { Text(event.description).foregroundStyle(.secondary) }
                        Text(event.occurredAt, format: .dateTime.year().month().day().hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Edit Event") { editingDraft = event }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Edit \(event.category.localizedName) event")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .contain)
                }
                Button("Add Event", systemImage: "plus") {
                    editingDraft = controller.addDraft()
                }
                .accessibilityHint("Adds a local event draft without contacting AI")
                HStack {
                    Button("Cancel", role: .cancel, action: discardAndClose)
                    Spacer()
                    Button("Save") { saveReviewedEvents() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("Saves this transcript, diary, and reviewed events to private pet history")
                }
                Text("These are temporary drafts and have not been saved.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var extractionFailureContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 52)).foregroundStyle(.secondary)
            Text(controller.extractionError == .quotaExceeded ? "AI usage limit reached" : "Couldn't Organize Recording")
                .font(.title2.bold())
            Text(controller.userMessage ?? "Please try again.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            if controller.extractionError != .quotaExceeded {
                Button("Try Again") { Task { await continueToExtraction() } }
                    .buttonStyle(.borderedProminent)
            }
            Button("Back") { controller.returnToTranscriptReview() }
        }
    }

    private func continueToExtraction() async {
        let session: PettaleSession?
        if case .signedIn(let value) = authentication.state { session = value } else { session = nil }
        await controller.continueToExtraction(session: session, knownPetNames: knownPetNames)
        if controller.phase == .authenticationRequired { isAuthenticationPresented = true }
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

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func saveReviewedEvents() {
        do {
            try controller.saveReviewedEvents(in: modelContext)
            close()
        } catch {
            saveErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Your events couldn't be saved. Try again.")
        }
    }

    private var preferredLanguage: TranscriptionLanguage {
        TranscriptionLanguage(rawValue: preferredLanguageRawValue)
            ?? TranscriptionLanguagePreference.initialLanguage()
    }
}
