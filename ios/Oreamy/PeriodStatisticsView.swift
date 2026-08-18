import SwiftUI

struct PeriodStatisticsView: View {
    let pet: Pet
    let recordAction: () -> Void
    @State private var period: StatisticsPeriod
#if DEBUG
    private let developmentCategory: EventCategory?
#endif

    init(pet: Pet, recordAction: @escaping () -> Void) {
        self.pet = pet
        self.recordAction = recordAction
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let requested = arguments.firstIndex(of: "-oreamyStatisticsPeriod").flatMap { index in
            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        }
        let requestedCategory = arguments.firstIndex(of: "-oreamyStatisticsCategory").flatMap { index in
            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        }
        developmentCategory = requestedCategory.flatMap { EventCategory(rawValue: $0.uppercased()) }
        _period = State(initialValue: StatisticsPeriod.developmentPeriod(for: requested) ?? PeriodStatisticsPresentation.defaultPeriod)
#else
        _period = State(initialValue: PeriodStatisticsPresentation.defaultPeriod)
#endif
    }

    private var statistics: PeriodStatistics {
        PeriodStatisticsPresentation.statistics(for: pet, period: period)
    }

    var body: some View {
#if DEBUG
        if let developmentCategory {
            FilteredEventListView(
                pet: pet,
                category: developmentCategory,
                period: period,
                periodStart: statistics.periodStart,
                now: statistics.now
            )
        } else {
            summaryContent
        }
#else
        summaryContent
#endif
    }

    private var summaryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                periodPicker

                VStack(alignment: .leading, spacing: 4) {
                    Text(period.title)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Based on moments you recorded.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if statistics.isEmpty {
                    emptyState
                } else {
                    recordingSummary
                    eventSummary
                    if let weight = statistics.weight {
                        weightSummary(weight)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Record Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var periodPicker: some View {
        Picker("Summary period", selection: $period) {
            ForEach(StatisticsPeriod.allCases) { choice in
                Text(choice.shortLabel)
                    .tag(choice)
                    .accessibilityLabel(choice.accessibilityLabel)
            }
        }
        .pickerStyle(.segmented)
    }

    private var recordingSummary: some View {
        HStack(spacing: 12) {
            metric(value: statistics.recordedDays, label: "Recorded Days", symbol: "calendar")
            metric(value: statistics.storyCount, label: "Stories", symbol: "book.closed")
        }
    }

    @ViewBuilder
    private var eventSummary: some View {
        let snapshot = statistics
        let metrics: [(Int, EventCategory, LocalizedStringKey, String)] = [
            (snapshot.foodCount, .food, "Food Records", "fork.knife"),
            (snapshot.activityCount, .activity, "Activity Records", "figure.run"),
            (snapshot.healthCount, .health, "Health Records", "heart.text.clipboard"),
            (snapshot.vetCount, .vet, "Vet Records", "cross.case")
        ]
        let visibleMetrics = metrics.filter { $0.0 > 0 }
        if !visibleMetrics.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(visibleMetrics.enumerated()), id: \.offset) { index, item in
                    NavigationLink {
                        FilteredEventListView(
                            pet: pet,
                            category: item.1,
                            period: period,
                            periodStart: snapshot.periodStart,
                            now: snapshot.now
                        )
                    } label: {
                        HStack {
                            Label(item.2, systemImage: item.3)
                            Spacer()
                            Text(item.0, format: .number)
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.forward")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 13)
                    if index < visibleMetrics.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func metric(value: Int, label: LocalizedStringKey, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.tint)
            Text(value, format: .number)
                .font(.title.bold().monospacedDigit())
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private func weightSummary(_ weight: PeriodWeightSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Weight", systemImage: "scalemass")
                .font(.headline)
            if let change = weight.changeKilograms {
                HStack(alignment: .firstTextBaseline) {
                    Text(WeightTrendPresentation.formattedKilograms(weight.earliest.kilograms))
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(WeightTrendPresentation.formattedKilograms(weight.latest.kilograms))
                        .font(.title3.bold())
                    Spacer()
                    Text(WeightTrendPresentation.formattedChange(change))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(change == 0 ? .secondary : .primary)
                }
            } else {
                Text(WeightTrendPresentation.formattedKilograms(weight.latest.kilograms))
                    .font(.title3.bold())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No records in this period yet")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Record a little moment from today.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Record", systemImage: "mic.fill", action: recordAction)
                .buttonStyle(.borderedProminent)
                .accessibilityHint(String(localized: "Starts a new voice record for \(pet.name)"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

#if DEBUG
private extension StatisticsPeriod {
    static func developmentPeriod(for value: String?) -> StatisticsPeriod? {
        switch value?.uppercased() {
        case "7D": .sevenDays
        case "30D": .thirtyDays
        case "3M": .threeMonths
        case "6M": .sixMonths
        case "1Y": .oneYear
        default: nil
        }
    }
}
#endif
