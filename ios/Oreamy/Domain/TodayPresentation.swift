import Foundation

enum TodayFeatureDestination: String, CaseIterable, Equatable, Sendable {
    case weight
    case healthHistory
    case recordSummary
}

struct TodayPresentationSnapshot: Equatable {
    let recentStory: DiaryEntry?
    let latestWeight: WeightObservation?
    let destinations: [TodayFeatureDestination]
}

enum TodayPresentation {
    static func snapshot(for pet: Pet) -> TodayPresentationSnapshot {
        let recentStory = DiaryPresentation.timeline(for: pet)
            .sections
            .first?
            .entries
            .first
        let latestWeight = WeightTrendPresentation.observations(for: pet).last
        return TodayPresentationSnapshot(
            recentStory: recentStory,
            latestWeight: latestWeight,
            destinations: TodayFeatureDestination.allCases
        )
    }
}
