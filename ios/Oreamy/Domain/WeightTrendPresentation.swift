import Foundation

struct WeightObservation: Identifiable, Equatable, Sendable {
    let eventID: UUID
    let occurredAt: Date
    let kilograms: Double

    var id: UUID { eventID }
}

enum WeightPeriod: String, CaseIterable, Identifiable, Sendable {
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear
    case all

    var id: Self { self }

    var shortLabel: String {
        switch self {
        case .oneMonth: String(localized: "1M")
        case .threeMonths: String(localized: "3M")
        case .sixMonths: String(localized: "6M")
        case .oneYear: String(localized: "1Y")
        case .all: String(localized: "All")
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .oneMonth: String(localized: "1 Month")
        case .threeMonths: String(localized: "3 Months")
        case .sixMonths: String(localized: "6 Months")
        case .oneYear: String(localized: "1 Year")
        case .all: String(localized: "All")
        }
    }

    fileprivate var calendarComponent: (Calendar.Component, Int)? {
        switch self {
        case .oneMonth: (.month, -1)
        case .threeMonths: (.month, -3)
        case .sixMonths: (.month, -6)
        case .oneYear: (.year, -1)
        case .all: nil
        }
    }
}

struct WeightTrend: Equatable, Sendable {
    let allObservations: [WeightObservation]
    let visibleObservations: [WeightObservation]
    let current: WeightObservation?
    let changeKilograms: Double?
    let yDomain: ClosedRange<Double>?
}

enum WeightTrendPresentation {
    static func observations(for pet: Pet) -> [WeightObservation] {
        var candidates: [PetEvent] = []
        for record in pet.records ?? [] {
            for event in record.events ?? [] {
                guard event.category == .weight,
                      event.eventType == "BODY_WEIGHT",
                      event.unit == "KG",
                      let value = event.numericValue,
                      value.isFinite,
                      value > 0 else { continue }
                candidates.append(event)
            }
        }

        let grouped: [Date: [PetEvent]] = Dictionary(grouping: candidates) { event in
            event.occurredAt
        }
        let winners: [PetEvent] = grouped.compactMap { entry in
            entry.value.max(by: isOlderDuplicate)
        }

        return winners
            .sorted {
                if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
                return $0.id.uuidString < $1.id.uuidString
            }
            .compactMap { event in
                event.numericValue.map {
                    WeightObservation(eventID: event.id, occurredAt: event.occurredAt, kilograms: $0)
                }
            }
    }

    static func trend(
        for pet: Pet,
        period: WeightPeriod,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> WeightTrend {
        trend(observations: observations(for: pet), period: period, now: now, calendar: calendar)
    }

    static func trend(
        observations: [WeightObservation],
        period: WeightPeriod,
        now: Date,
        calendar: Calendar
    ) -> WeightTrend {
        let sorted = observations.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
            return $0.eventID.uuidString < $1.eventID.uuidString
        }
        let visible: [WeightObservation]
        if let (component, value) = period.calendarComponent,
           let boundary = calendar.date(byAdding: component, value: value, to: now) {
            visible = sorted.filter { $0.occurredAt >= boundary && $0.occurredAt <= now }
        } else {
            visible = sorted.filter { $0.occurredAt <= now }
        }

        let change = visible.count > 1
            ? visible[visible.count - 1].kilograms - visible[0].kilograms
            : nil

        return WeightTrend(
            allObservations: sorted,
            visibleObservations: visible,
            current: sorted.last,
            changeKilograms: change,
            yDomain: chartDomain(for: visible.map(\.kilograms))
        )
    }

    static func chartDomain(for values: [Double]) -> ClosedRange<Double>? {
        guard let minimum = values.min(), let maximum = values.max() else { return nil }
        let observedSpan = maximum - minimum
        let padding = max(0.25, observedSpan * 0.2)
        return max(0, minimum - padding)...(maximum + padding)
    }

    static func formattedKilograms(_ value: Double, locale: Locale = .autoupdatingCurrent) -> String {
        let number = value.formatted(
            .number.locale(locale).precision(.fractionLength(0...2))
        )
        return String(localized: "\(number) kg", locale: locale)
    }

    static func formattedChange(_ value: Double, locale: Locale = .autoupdatingCurrent) -> String {
        let sign = value > 0 ? "+" : ""
        return sign + formattedKilograms(value, locale: locale)
    }

    private static func isOlderDuplicate(_ lhs: PetEvent, _ rhs: PetEvent) -> Bool {
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
