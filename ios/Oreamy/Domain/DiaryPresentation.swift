import Foundation

struct DiaryTimeline: Equatable {
    let sections: [DiaryDaySection]

    var isEmpty: Bool { sections.isEmpty }
}

struct DiaryDaySection: Identifiable, Equatable {
    let day: Date
    let title: String
    let entries: [DiaryEntry]

    var id: Date { day }
}

struct DiaryEntry: Identifiable, Hashable {
    let id: UUID
    let recordedAt: Date
    let displayText: String
    let originalTranscript: String
    let summaries: [DiaryEventSummary]
    let eventDetails: [DiaryEventDetail]
}

struct DiaryEventSummary: Identifiable, Hashable {
    let id: String
    let symbolName: String
    let text: String
    let accessibilityText: String
}

struct DiaryEventDetail: Identifiable, Hashable {
    let id: UUID
    let symbolName: String
    let categoryName: String
    let value: String
    let occurredAtText: String
}

enum DiaryPresentation {
    static func timeline(
        for pet: Pet,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        now: Date = Date(),
        bundle: Bundle = .main
    ) -> DiaryTimeline {
        let records = (pet.records ?? []).sorted {
            if $0.recordedAt == $1.recordedAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.recordedAt > $1.recordedAt
        }
        let entries = records.map { entry(for: $0, locale: locale, bundle: bundle) }
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.recordedAt) }
        let sections = grouped.keys.sorted(by: >).map { day in
            DiaryDaySection(
                day: day,
                title: dayTitle(day, calendar: calendar, locale: locale, now: now, bundle: bundle),
                entries: grouped[day, default: []]
            )
        }
        return DiaryTimeline(sections: sections)
    }

    static func entry(
        for record: PetRecord,
        locale: Locale = .autoupdatingCurrent,
        bundle: Bundle = .main
    ) -> DiaryEntry {
        let events = (record.events ?? []).sorted {
            if $0.occurredAt == $1.occurredAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.occurredAt < $1.occurredAt
        }
        return DiaryEntry(
            id: record.id,
            recordedAt: record.recordedAt,
            displayText: displayText(for: record),
            originalTranscript: record.originalTranscript,
            summaries: summaries(for: events, locale: locale, bundle: bundle),
            eventDetails: events.map { detail(for: $0, locale: locale, bundle: bundle) }
        )
    }

    static func displayText(for record: PetRecord) -> String {
        let diaryText = record.diaryText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return diaryText?.isEmpty == false ? diaryText! : record.originalTranscript
    }

    static func dayTitle(
        _ day: Date,
        calendar: Calendar,
        locale: Locale,
        now: Date,
        bundle: Bundle = .main
    ) -> String {
        let today = calendar.startOfDay(for: now)
        if calendar.isDate(day, inSameDayAs: today) {
            return localized("Today", locale: locale, bundle: bundle)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return localized("Yesterday", locale: locale, bundle: bundle)
        }
        return day.formatted(.dateTime.locale(locale).month(.wide).day())
    }

    private static func summaries(
        for events: [PetEvent],
        locale: Locale,
        bundle: Bundle
    ) -> [DiaryEventSummary] {
        var result: [DiaryEventSummary] = []

        let foodEvents = events.filter { $0.category == .food }
        if !foodEvents.isEmpty {
            let count = foodEvents.reduce(0) { $0 + ($1.count ?? 1) }
            let text = formattedCount(count, label: localized("Meals", locale: locale, bundle: bundle), locale: locale)
            result.append(.init(id: "FOOD", symbolName: EventCategory.food.symbolName, text: text, accessibilityText: text))
        }

        if let weight = events.last(where: { $0.category == .weight }),
           let value = weight.numericValue {
            let text = measurement(value: value, unit: weight.unit, locale: locale)
            let accessible = "\(localized("Weight", locale: locale, bundle: bundle)), \(text)"
            result.append(.init(id: "WEIGHT", symbolName: EventCategory.weight.symbolName, text: text, accessibilityText: accessible))
        }

        if let activity = events.last(where: { $0.category == .activity }) {
            let name = friendlyEventName(activity, locale: locale, bundle: bundle)
            let text = activity.durationMinutes.map { "\(name) · \(formattedMinutes($0, locale: locale, bundle: bundle))" } ?? name
            result.append(.init(id: "ACTIVITY", symbolName: EventCategory.activity.symbolName, text: text, accessibilityText: "\(localized("Activity", locale: locale, bundle: bundle)), \(text)"))
        }

        let vomiting = events.filter { $0.category == .health && $0.eventType == "VOMITING" }
        if !vomiting.isEmpty {
            let count = vomiting.reduce(0) { $0 + ($1.count ?? 1) }
            let name = localized("Vomiting", locale: locale, bundle: bundle)
            let text = formattedCount(count, label: name, locale: locale)
            result.append(.init(id: "HEALTH_VOMITING", symbolName: EventCategory.health.symbolName, text: text, accessibilityText: "\(localized("Health", locale: locale, bundle: bundle)), \(text)"))
        } else if let health = events.last(where: { $0.category == .health }) {
            let text = health.eventDescription ?? friendlyEventName(health, locale: locale, bundle: bundle)
            result.append(.init(id: "HEALTH", symbolName: EventCategory.health.symbolName, text: text, accessibilityText: "\(localized("Health", locale: locale, bundle: bundle)), \(text)"))
        }

        let represented: Set<EventCategory> = [.food, .weight, .activity, .health]
        for event in events where !represented.contains(event.category) {
            let text = event.eventDescription ?? friendlyEventName(event, locale: locale, bundle: bundle)
            let id = "\(event.category.rawValue)-\(event.id.uuidString)"
            result.append(.init(id: id, symbolName: event.category.symbolName, text: text, accessibilityText: "\(event.category.localizedName), \(text)"))
        }
        return result
    }

    private static func detail(for event: PetEvent, locale: Locale, bundle: Bundle) -> DiaryEventDetail {
        var parts: [String] = []
        if let description = event.eventDescription { parts.append(description) }
        else if event.eventType != nil && !(event.category == .weight && event.numericValue != nil) {
            parts.append(friendlyEventName(event, locale: locale, bundle: bundle))
        }
        if let value = event.numericValue { parts.append(measurement(value: value, unit: event.unit, locale: locale)) }
        if let count = event.count { parts.append(formattedCount(count, label: nil, locale: locale)) }
        if let minutes = event.durationMinutes { parts.append(formattedMinutes(minutes, locale: locale, bundle: bundle)) }
        if parts.isEmpty { parts.append(event.category.localizedName) }
        return DiaryEventDetail(
            id: event.id,
            symbolName: event.category.symbolName,
            categoryName: event.category.localizedName,
            value: parts.joined(separator: " · "),
            occurredAtText: event.occurredAt.formatted(.dateTime.locale(locale).hour().minute())
        )
    }

    static func friendlyEventName(_ event: PetEvent, locale: Locale, bundle: Bundle) -> String {
        switch event.eventType {
        case "BODY_WEIGHT": localized("Weight", locale: locale, bundle: bundle)
        case "VOMITING": localized("Vomiting", locale: locale, bundle: bundle)
        case "PLAY": localized("Play", locale: locale, bundle: bundle)
        case "EYE_REDNESS": localized("Eye redness", locale: locale, bundle: bundle)
        case .some(let value): value.lowercased().split(separator: "_").map { String($0).capitalized(with: locale) }.joined(separator: " ")
        case nil: event.category.localizedName
        }
    }

    private static func measurement(value: Double, unit: String?, locale: Locale) -> String {
        let number = value.formatted(.number.locale(locale).precision(.fractionLength(0...2)))
        guard let unit, !unit.isEmpty else { return number }
        return "\(number) \(unit.lowercased())"
    }

    private static func formattedCount(_ count: Int, label: String?, locale: Locale) -> String {
        let language = locale.language.languageCode?.identifier
        if language == "ko" { return [label, "\(count)회"].compactMap { $0 }.joined(separator: " ") }
        let countText = count == 1 ? "1 time" : "\(count) times"
        return [label, countText].compactMap { $0 }.joined(separator: " · ")
    }

    private static func formattedMinutes(_ minutes: Int, locale: Locale, bundle: Bundle) -> String {
        if locale.language.languageCode?.identifier == "ko" { return "\(minutes)분" }
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    private static func localized(_ key: String, locale: Locale, bundle: Bundle) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        let localizedBundle = bundle.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? bundle
        return NSLocalizedString(key, bundle: localizedBundle, value: key, comment: "")
    }
}
