import Foundation

struct PetFormState {
    var name = ""
    var species: PetSpecies = .cat
    var sex: PetSex = .unknown
    var hasBirthDate = false
    var birthDate = Date()
    var hasAdoptionDate = false
    var adoptionDate = Date()
    var breed = ""
    var profilePhotoData: Data?

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
        profilePhotoData = pet.profilePhotoData
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
        if pet.profilePhotoData != profilePhotoData {
            pet.setProfilePhotoData(profilePhotoData, at: date)
        }
    }
}
