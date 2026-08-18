import Foundation

enum OreamyLaunchDestination: Equatable {
    case intro
    case welcome
    case firstPetCreation
    case home
}

struct OreamyLaunchFlow: Equatable {
    private(set) var destination: OreamyLaunchDestination = .intro

    init(destination: OreamyLaunchDestination = .intro) {
        self.destination = destination
    }

    mutating func completeIntro(petCount: Int) {
        guard destination == .intro else { return }
        destination = petCount == 0 ? .welcome : .home
    }

    mutating func getStarted() {
        guard destination == .welcome else { return }
        destination = .firstPetCreation
    }

    mutating func cancelFirstPetCreation() {
        guard destination == .firstPetCreation else { return }
        destination = .welcome
    }

    mutating func petsDidChange(count: Int) {
        guard count > 0, destination != .intro else { return }
        destination = .home
    }
}

struct OreamyIntroAnimationPlan: Equatable {
    let usesScale: Bool
    let usesMotion: Bool
    let duration: Duration

    static func resolve(reduceMotion: Bool) -> Self {
        Self(usesScale: !reduceMotion, usesMotion: !reduceMotion, duration: .milliseconds(1_150))
    }
}
