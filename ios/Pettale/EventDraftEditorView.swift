import SwiftUI

struct EventDraftEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: EditableEventDraft
    let save: (EditableEventDraft) -> Void
    let remove: (() -> Void)?

    init(draft: EditableEventDraft, save: @escaping (EditableEventDraft) -> Void, remove: (() -> Void)? = nil) {
        _draft = State(initialValue: draft)
        self.save = save
        self.remove = remove
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $draft.category) {
                    ForEach(EventCategory.allCases, id: \.self) { category in
                        Text(category.localizedName).tag(category)
                    }
                }
                .onChange(of: draft.category) { _, _ in draft.normalize() }

                if draft.category == .weight {
                    LabeledContent("Type", value: WorkflowPresentation.eventType("BODY_WEIGHT"))
                } else {
                    TextField("Event Type", text: $draft.eventType)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .accessibilityHint("Enter the event kind")
                }

                DatePicker("Date & Time", selection: $draft.occurredAt)

                if draft.category == .weight || draft.numericValue != nil {
                    TextField("Value", value: $draft.numericValue, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Unit", text: $draft.unit)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                if draft.category == .health || draft.count != nil {
                    Stepper("Count: \(draft.count ?? 0)", value: optionalInteger(\.count), in: 0...10_000)
                }

                if draft.category == .activity || draft.durationMinutes != nil {
                    Stepper("Duration: \(draft.durationMinutes ?? 0) min", value: optionalInteger(\.durationMinutes), in: 0...100_000)
                }

                Section("Description") {
                    TextField("Optional description", text: $draft.description, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let remove {
                    Button("Remove Event", role: .destructive) {
                        remove()
                        dismiss()
                    }
                    .accessibilityHint("Removes this draft without changing saved history")
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        draft.normalize()
                        save(draft)
                        dismiss()
                    }
                }
            }
        }
    }

    private func optionalInteger(_ keyPath: WritableKeyPath<EditableEventDraft, Int?>) -> Binding<Int> {
        Binding(
            get: { draft[keyPath: keyPath] ?? 0 },
            set: { draft[keyPath: keyPath] = $0 }
        )
    }
}
