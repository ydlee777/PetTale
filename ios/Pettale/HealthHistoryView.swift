import SwiftUI

struct HealthHistoryView: View {
    let pet: Pet
    let recordAction: () -> Void

    private var timeline: HealthHistoryTimeline {
        HealthHistoryPresentation.timeline(for: pet)
    }

    var body: some View {
#if DEBUG
        if (ProcessInfo.processInfo.arguments.contains("-pettaleHealthDetail")
            || ProcessInfo.processInfo.environment["PETTALE_HEALTH_DETAIL"] == "1"),
           let entry = timeline.sections.first?.entries.first {
            HealthHistoryDetailView(petName: pet.name, entry: entry)
        } else {
            content
        }
#else
        content
#endif
    }

    private var content: some View {
        Group {
            if timeline.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(timeline.sections) { section in
                            Section {
                                ForEach(section.entries) { entry in
                                    NavigationLink(value: HealthHistoryDestination(petName: pet.name, entry: entry)) {
                                        HealthHistoryCard(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                Text(section.title)
                                    .font(.title3.bold())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 8)
                                    .accessibilityAddTraits(.isHeader)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationDestination(for: HealthHistoryDestination.self) { destination in
            HealthHistoryDetailView(petName: destination.petName, entry: destination.entry)
        }
        .navigationTitle("Health History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No health history yet")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Mention health-related moments in your daily recording and Pettale will keep them here.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Record", systemImage: "mic.fill", action: recordAction)
                .buttonStyle(.borderedProminent)
                .accessibilityHint(String(localized: "Starts a new voice record for \(pet.name)"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct HealthHistoryDestination: Hashable {
    let petName: String
    let entry: HealthHistoryEntry
}

private struct HealthHistoryCard: View {
    let entry: HealthHistoryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: entry.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.title).font(.headline)
                    if let count = entry.countText {
                        Text("· \(count)").foregroundStyle(.secondary)
                    }
                }
                if let description = entry.description {
                    Text(description)
                        .foregroundStyle(.primary.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(entry.occurredAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Opens health event details")
    }

    private var accessibilityText: String {
        [
            entry.category.localizedName,
            entry.title,
            entry.countText,
            entry.description,
            entry.occurredAt.formatted(date: .omitted, time: .shortened)
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}

struct HealthHistoryDetailView: View {
    let petName: String
    let entry: HealthHistoryEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(petName).font(.title.bold())
                    Text(entry.occurredAt, format: .dateTime.month(.wide).day().year().hour().minute())
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
                    if let description = entry.description {
                        Text(description).fixedSize(horizontal: false, vertical: true)
                    }
                    if let count = entry.countText {
                        Label(count, systemImage: "number")
                            .foregroundStyle(.secondary)
                    }
                }

                detailSection(title: "That Day's Story") {
                    Text(entry.diaryContext)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if entry.originalTranscript != entry.diaryContext {
                    detailSection(title: "What I Said") {
                        Text(entry.originalTranscript)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .navigationTitle("Health History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailSection<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
            content()
        }
    }
}
