import Foundation

struct HealthHistoryTimeline: Equatable, Sendable {
    let sections: [HealthHistoryDaySection]
    var isEmpty: Bool { sections.isEmpty }
}

struct HealthHistoryDaySection: Identifiable, Equatable, Sendable {
    let day: Date
    let title: String
    let entries: [HealthHistoryEntry]
    var id: Date { day }
}

struct HealthHistoryEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let recordID: UUID
    let category: EventCategory
    let title: String
    let occurredAt: Date
    let description: String?
    let countText: String?
    let diaryContext: String
    let originalTranscript: String
    let symbolName: String
}

enum HealthHistoryPresentation {
    private static let includedCategories: Set<EventCategory> = [.health, .medication, .vet]

    static func timeline(
        for pet: Pet,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        now: Date = Date(),
        bundle: Bundle = .main
    ) -> HealthHistoryTimeline {
        let entries = entries(for: pet, locale: locale, bundle: bundle)
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.occurredAt) }
        let sections = grouped.keys.sorted(by: >).map { day in
            HealthHistoryDaySection(
                day: day,
                title: DiaryPresentation.dayTitle(day, calendar: calendar, locale: locale, now: now, bundle: bundle),
                entries: grouped[day, default: []]
            )
        }
        return HealthHistoryTimeline(sections: sections)
    }

    static func entries(
        for pet: Pet,
        locale: Locale = .autoupdatingCurrent,
        bundle: Bundle = .main
    ) -> [HealthHistoryEntry] {
        var events: [PetEvent] = []
        for record in pet.records ?? [] {
            events.append(contentsOf: (record.events ?? []).filter { includedCategories.contains($0.category) })
        }
        return events.sorted(by: isOrderedBefore).compactMap {
            entry(for: $0, locale: locale, bundle: bundle)
        }
    }

    static func friendlyTitle(
        category: EventCategory,
        eventType: String?,
        locale: Locale,
        bundle: Bundle = .main
    ) -> String {
        switch (category, eventType) {
        case (.health, "VOMITING"):
            localized("Vomiting", locale: locale, bundle: bundle)
        case (.health, "EYE_REDNESS"), (.health, "EYE_OBSERVATION"), (.health, "RED_WATERY_EYE"):
            localized("Eye Condition", locale: locale, bundle: bundle)
        case (_, let eventType?):
            normalizedTypeLabel(eventType, locale: locale)
        case (.health, nil):
            localized("Health", locale: locale, bundle: bundle)
        case (.medication, nil):
            localized("Medication", locale: locale, bundle: bundle)
        case (.vet, nil):
            localized("Vet Visit", locale: locale, bundle: bundle)
        default:
            localized("Health", locale: locale, bundle: bundle)
        }
    }

    static func formattedCount(_ count: Int?, locale: Locale) -> String? {
        guard let count else { return nil }
        if locale.language.languageCode?.identifier == "ko" { return "\(count)회" }
        return count == 1 ? "1 time" : "\(count) times"
    }

    static func diaryContext(for record: PetRecord) -> String {
        let diary = record.diaryText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return diary?.isEmpty == false ? diary! : record.originalTranscript
    }

    private static func entry(
        for event: PetEvent,
        locale: Locale,
        bundle: Bundle
    ) -> HealthHistoryEntry? {
        guard let record = event.record else { return nil }
        return HealthHistoryEntry(
            id: event.id,
            recordID: record.id,
            category: event.category,
            title: friendlyTitle(category: event.category, eventType: event.eventType, locale: locale, bundle: bundle),
            occurredAt: event.occurredAt,
            description: event.eventDescription,
            countText: formattedCount(event.count, locale: locale),
            diaryContext: diaryContext(for: record),
            originalTranscript: record.originalTranscript,
            symbolName: event.category.symbolName
        )
    }

    private static func isOrderedBefore(_ lhs: PetEvent, _ rhs: PetEvent) -> Bool {
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func normalizedTypeLabel(_ value: String, locale: Locale) -> String {
        value.lowercased()
            .split(separator: "_")
            .map { String($0).capitalized(with: locale) }
            .joined(separator: " ")
    }

    private static func localized(_ key: String, locale: Locale, bundle: Bundle) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        let localizedBundle = bundle.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? bundle
        return NSLocalizedString(key, bundle: localizedBundle, value: key, comment: "")
    }
}
