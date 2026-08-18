import Foundation

struct FilteredEventTimeline: Equatable {
    let period: StatisticsPeriod
    let sections: [FilteredEventDaySection]
    var eventCount: Int { sections.reduce(0) { $0 + $1.entries.count } }
    var isEmpty: Bool { eventCount == 0 }
}

struct FilteredEventDaySection: Identifiable, Equatable {
    let day: Date
    let title: String
    let entries: [FilteredEventEntry]
    var id: Date { day }
}

struct FilteredEventEntry: Identifiable, Equatable {
    let id: UUID
    let occurredAt: Date
    let title: String
    let description: String?
    let count: Int?
    let durationMinutes: Int?
    let numericValue: Double?
    let unit: String?
    let diaryContext: String?
}

enum FilteredEventPresentation {
    static let supportedCategories: [EventCategory] = [.food, .activity, .health, .vet]

    static func timeline(
        for pet: Pet,
        category: EventCategory,
        period: StatisticsPeriod,
        periodStart: Date,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        bundle: Bundle = .main
    ) -> FilteredEventTimeline {
        let entries = PeriodStatisticsPresentation.visibleEvents(for: pet, periodStart: periodStart, now: now)
            .filter { $0.category == category }
            .map { entry(for: $0, locale: locale, bundle: bundle) }
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.occurredAt) }
        let sections = grouped.keys.sorted(by: >).map { day in
            FilteredEventDaySection(
                day: day,
                title: DiaryPresentation.dayTitle(day, calendar: calendar, locale: locale, now: now, bundle: bundle),
                entries: grouped[day, default: []]
            )
        }
        return FilteredEventTimeline(period: period, sections: sections)
    }

    static func title(for category: EventCategory) -> String {
        switch category {
        case .food: String(localized: "Food Records")
        case .activity: String(localized: "Activity Records")
        case .health: String(localized: "Health Records")
        case .vet: String(localized: "Vet Records")
        default: category.localizedName
        }
    }

    private static func entry(for event: PetEvent, locale: Locale, bundle: Bundle) -> FilteredEventEntry {
        let title: String
        if event.category == .health || event.category == .vet {
            title = HealthHistoryPresentation.friendlyTitle(
                category: event.category,
                eventType: event.eventType,
                locale: locale,
                bundle: bundle
            )
        } else {
            title = DiaryPresentation.friendlyEventName(event, locale: locale, bundle: bundle)
        }
        let context = event.record.map { HealthHistoryPresentation.diaryContext(for: $0) }
        return FilteredEventEntry(
            id: event.id,
            occurredAt: event.occurredAt,
            title: title,
            description: event.eventDescription,
            count: event.count,
            durationMinutes: event.durationMinutes,
            numericValue: event.numericValue,
            unit: event.unit,
            diaryContext: context
        )
    }
}
