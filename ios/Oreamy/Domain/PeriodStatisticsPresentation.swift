import Foundation

enum StatisticsPeriod: String, CaseIterable, Identifiable, Sendable {
    case sevenDays
    case thirtyDays
    case threeMonths
    case sixMonths
    case oneYear

    var id: Self { self }

    var shortLabel: String {
        switch self {
        case .sevenDays: String(localized: "7D")
        case .thirtyDays: String(localized: "30D")
        case .threeMonths: String(localized: "3M")
        case .sixMonths: String(localized: "6M")
        case .oneYear: String(localized: "1Y")
        }
    }

    var title: String {
        switch self {
        case .sevenDays: String(localized: "Last 7 Days")
        case .thirtyDays: String(localized: "Last 30 Days")
        case .threeMonths: String(localized: "Last 3 Months")
        case .sixMonths: String(localized: "Last 6 Months")
        case .oneYear: String(localized: "Last Year")
        }
    }

    var accessibilityLabel: String { title }

    fileprivate var calendarComponent: (Calendar.Component, Int) {
        switch self {
        case .sevenDays: (.day, -7)
        case .thirtyDays: (.day, -30)
        case .threeMonths: (.month, -3)
        case .sixMonths: (.month, -6)
        case .oneYear: (.year, -1)
        }
    }
}

struct PeriodWeightSummary: Equatable, Sendable {
    let earliest: WeightObservation
    let latest: WeightObservation

    var changeKilograms: Double? {
        earliest.eventID == latest.eventID ? nil : latest.kilograms - earliest.kilograms
    }
}

struct PeriodStatistics: Equatable, Sendable {
    let period: StatisticsPeriod
    let periodStart: Date
    let now: Date
    let recordedDays: Int
    let storyCount: Int
    let foodCount: Int
    let activityCount: Int
    let healthCount: Int
    let vetCount: Int
    let weight: PeriodWeightSummary?

    var isEmpty: Bool {
        storyCount == 0
            && foodCount == 0
            && activityCount == 0
            && healthCount == 0
            && vetCount == 0
            && weight == nil
    }
}

enum PeriodStatisticsPresentation {
    static let defaultPeriod = StatisticsPeriod.thirtyDays

    static func periodStart(
        for period: StatisticsPeriod,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let (component, value) = period.calendarComponent
        return calendar.date(byAdding: component, value: value, to: now) ?? now
    }

    static func statistics(
        for pet: Pet,
        period: StatisticsPeriod = defaultPeriod,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> PeriodStatistics {
        let start = periodStart(for: period, now: now, calendar: calendar)
        let records = pet.records ?? []
        let visibleRecords = records.filter { $0.recordedAt >= start && $0.recordedAt <= now }
        let recordedDays = Set(visibleRecords.map { calendar.startOfDay(for: $0.recordedAt) }).count

        let visibleEvents = visibleEvents(for: pet, periodStart: start, now: now)
        let categoryCounts = Dictionary(grouping: visibleEvents, by: \PetEvent.category)
            .mapValues(\.count)

        // Reuse the approved Weight Trend contract for validity and duplicate resolution.
        let weightObservations = WeightTrendPresentation.observations(for: pet)
            .filter { $0.occurredAt >= start && $0.occurredAt <= now }
        let weight = weightObservations.first.flatMap { earliest in
            weightObservations.last.map { PeriodWeightSummary(earliest: earliest, latest: $0) }
        }

        return PeriodStatistics(
            period: period,
            periodStart: start,
            now: now,
            recordedDays: recordedDays,
            storyCount: visibleRecords.count,
            foodCount: categoryCounts[.food, default: 0],
            activityCount: categoryCounts[.activity, default: 0],
            healthCount: categoryCounts[.health, default: 0],
            vetCount: categoryCounts[.vet, default: 0],
            weight: weight
        )
    }

    static func visibleEvents(for pet: Pet, periodStart: Date, now: Date) -> [PetEvent] {
        (pet.records ?? [])
            .flatMap { $0.events ?? [] }
            .filter { $0.occurredAt >= periodStart && $0.occurredAt <= now }
            .sorted {
                if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }
}
