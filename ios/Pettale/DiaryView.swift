import SwiftUI

struct DiaryView: View {
    let pet: Pet
    let recordAction: () -> Void

    private var timeline: DiaryTimeline {
        DiaryPresentation.timeline(for: pet)
    }

    var body: some View {
#if DEBUG
        if (ProcessInfo.processInfo.arguments.contains("-pettaleDiaryDetail")
            || ProcessInfo.processInfo.environment["PETTALE_DIARY_DETAIL"] == "1"),
           let entry = timeline.sections.first?.entries.first {
            DiaryRecordDetailView(petName: pet.name, entry: entry)
        } else {
            diaryContent
        }
#else
        diaryContent
#endif
    }

    private var diaryContent: some View {
        Group {
            if timeline.isEmpty {
                DiaryEmptyView(petName: pet.name, recordAction: recordAction)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(timeline.sections) { section in
                            Section {
                                ForEach(section.entries) { entry in
                                    NavigationLink(value: DiaryDestination(petName: pet.name, entry: entry)) {
                                        DiaryCard(entry: entry)
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
        .navigationDestination(for: DiaryDestination.self) { destination in
            DiaryRecordDetailView(petName: destination.petName, entry: destination.entry)
        }
        .navigationTitle("Diary")
    }
}

private struct DiaryDestination: Hashable {
    let petName: String
    let entry: DiaryEntry
}

private struct DiaryCard: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(entry.displayText)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(5)

            if !entry.summaries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.summaries.prefix(4)) { summary in
                        Label(summary.text, systemImage: summary.symbolName)
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.72))
                            .accessibilityLabel(summary.accessibilityText)
                    }
                }
            }

            Text(entry.recordedAt, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.82))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens diary record details")
    }
}

private struct DiaryEmptyView: View {
    let petName: String
    let recordAction: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No diary yet", systemImage: "book.closed")
        } description: {
            Text("\(petName)'s tale starts here.\n\nRecord a little moment from today.")
        } actions: {
            Button("Record", systemImage: "mic.fill", action: recordAction)
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Starts a new voice record for \(petName)")
        }
    }
}

struct DiaryRecordDetailView: View {
    let petName: String
    let entry: DiaryEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(petName).font(.title.bold())
                    Text(entry.recordedAt, format: .dateTime.month(.wide).day().hour().minute())
                        .foregroundStyle(.secondary)
                }

                detailSection(title: "Today's Story") {
                    Text(entry.displayText)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !entry.eventDetails.isEmpty {
                    detailSection(title: "Events") {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(entry.eventDetails) { event in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: event.symbolName)
                                        .frame(width: 24)
                                        .foregroundStyle(.tint)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(event.categoryName).font(.headline)
                                        Text(event.value)
                                        Text(event.occurredAtText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }

                detailSection(title: "What I Said") {
                    Text(entry.originalTranscript)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .navigationTitle("Diary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailSection<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
            content()
        }
    }
}
