import Foundation

enum EventCategory: String, CaseIterable, Codable, Sendable {
    case food = "FOOD"
    case weight = "WEIGHT"
    case health = "HEALTH"
    case medication = "MEDICATION"
    case activity = "ACTIVITY"
    case behavior = "BEHAVIOR"
    case sleep = "SLEEP"
    case grooming = "GROOMING"
    case vet = "VET"
    case event = "EVENT"
    case other = "OTHER"

    var localizedName: String {
        switch self {
        case .food: String(localized: "Food")
        case .weight: String(localized: "Weight")
        case .health: String(localized: "Health")
        case .medication: String(localized: "Medication")
        case .activity: String(localized: "Activity")
        case .behavior: String(localized: "Behavior")
        case .sleep: String(localized: "Sleep")
        case .grooming: String(localized: "Grooming")
        case .vet: String(localized: "Vet")
        case .event: String(localized: "Event")
        case .other: String(localized: "Other")
        }
    }

    var symbolName: String {
        switch self {
        case .food: "fork.knife"
        case .weight: "scalemass"
        case .health: "heart.text.clipboard"
        case .medication: "pill"
        case .activity: "figure.run"
        case .behavior: "pawprint"
        case .sleep: "moon.zzz"
        case .grooming: "sparkles"
        case .vet: "cross.case"
        case .event: "calendar"
        case .other: "square.grid.2x2"
        }
    }
}
