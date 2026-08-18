import SwiftUI

struct FilteredEventListView: View {
    let pet: Pet
    let category: EventCategory
    let period: StatisticsPeriod
    let periodStart: Date
    let now: Date

    private var timeline: FilteredEventTimeline {
        FilteredEventPresentation.timeline(
            for: pet,
            category: category,
            period: period,
            periodStart: periodStart,
            now: now
        )
    }

    var body: some View {
        Group {
            if timeline.isEmpty {
                ContentUnavailableView(
                    "No recorded events in this period",
                    systemImage: category.symbolName,
                    description: Text(period.title)
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        Text(period.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(timeline.sections) { section in
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                                        FilteredEventRow(entry: entry)
                                        if index < section.entries.count - 1 { Divider() }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                            } header: {
                                Text(section.title)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityAddTraits(.isHeader)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle(FilteredEventPresentation.title(for: category))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FilteredEventRow: View {
    let entry: FilteredEventEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(entry.occurredAt, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.title).font(.headline)
            if let description = entry.description, description != entry.title {
                Text(description)
            }
            if let count = entry.count {
                Text("Count: \(count)")
            }
            if let duration = entry.durationMinutes {
                Text("Duration: \(duration) min")
            }
            if let value = entry.numericValue {
                Text(measurement(value: value, unit: entry.unit))
            }
            if let context = entry.diaryContext, !context.isEmpty {
                Text(context)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private func measurement(value: Double, unit: String?) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...2)))
        guard let unit, !unit.isEmpty else { return number }
        return "\(number) \(unit.lowercased())"
    }
}
