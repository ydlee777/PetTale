import Foundation

struct PetPhotoDraft: Equatable {
    private let originalData: Data?
    private(set) var change: Change = .unchanged

    enum Change: Equatable {
        case unchanged
        case replacement(Data)
        case removal
    }

    init(originalData: Data?) {
        self.originalData = originalData
    }

    var previewData: Data? {
        switch change {
        case .unchanged: originalData
        case .replacement(let data): data
        case .removal: nil
        }
    }

    var hasChanges: Bool { change != .unchanged }

    mutating func select(_ data: Data) {
        change = .replacement(data)
    }

    mutating func remove() {
        change = .removal
    }
}

struct PetFormState {
    var name = ""
    var species: PetSpecies = .cat
    var sex: PetSex = .unknown
    var hasBirthDate = false
    var birthDate = Date()
    var hasAdoptionDate = false
    var adoptionDate = Date()
    var breed = ""
    private(set) var photoDraft = PetPhotoDraft(originalData: nil)

    var profilePhotoData: Data? { photoDraft.previewData }

    init(pet: Pet? = nil) {
        guard let pet else { return }
        name = pet.name
        species = pet.species
        sex = pet.sex
        hasBirthDate = pet.birthDate != nil
        birthDate = pet.birthDate ?? Date()
        hasAdoptionDate = pet.adoptionDate != nil
        adoptionDate = pet.adoptionDate ?? Date()
        breed = pet.breed ?? ""
        photoDraft = PetPhotoDraft(originalData: pet.profilePhotoData)
    }

    mutating func selectProfilePhoto(_ data: Data) {
        photoDraft.select(data)
    }

    mutating func removeProfilePhoto() {
        photoDraft.remove()
    }

    func makePet(now: Date = Date()) throws -> Pet {
        try Pet(
            name: name,
            species: species,
            sex: sex,
            birthDate: hasBirthDate ? birthDate : nil,
            adoptionDate: hasAdoptionDate ? adoptionDate : nil,
            breed: breed,
            profilePhotoData: profilePhotoData,
            now: now
        )
    }

    func apply(to pet: Pet, at date: Date = Date()) throws {
        try pet.update(
            name: name,
            species: species,
            sex: sex,
            birthDate: hasBirthDate ? birthDate : nil,
            adoptionDate: hasAdoptionDate ? adoptionDate : nil,
            breed: breed,
            at: date
        )
        if photoDraft.hasChanges {
            pet.setProfilePhotoData(profilePhotoData, at: date)
        }
    }
}
