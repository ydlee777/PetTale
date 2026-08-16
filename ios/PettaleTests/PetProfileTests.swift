import SwiftData
import UIKit
import XCTest
@testable import Pettale

@MainActor
final class PetProfileTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try PettalePersistence.makeModelContainer(inMemory: true, cloudKitEnabled: false)
    }

    func testNoPetsRoutesToFirstPetSetup() {
        XCTAssertEqual(LaunchRoute.resolve(petCount: 0), .firstPetSetup)
    }

    func testAnyPetRoutesToHome() {
        XCTAssertEqual(LaunchRoute.resolve(petCount: 1), .home)
        XCTAssertEqual(LaunchRoute.resolve(petCount: 3), .home)
    }

    func testCreateFormMapsCanonicalSpeciesAndSex() throws {
        var form = PetFormState()
        form.name = "Momo"
        form.species = .dog
        form.sex = .female
        let pet = try form.makePet()
        XCTAssertEqual(pet.species.rawValue, "DOG")
        XCTAssertEqual(pet.sex.rawValue, "FEMALE")
    }

    func testWhitespaceNameIsRejectedByExistingValidation() {
        var form = PetFormState()
        form.name = " \n "
        XCTAssertThrowsError(try form.makePet()) { error in
            XCTAssertEqual(error as? PetValidationError, .emptyName)
        }
    }

    func testUnknownDatesStayNil() throws {
        var form = PetFormState()
        form.name = "Nabi"
        form.hasBirthDate = false
        form.hasAdoptionDate = false
        let pet = try form.makePet()
        XCTAssertNil(pet.birthDate)
        XCTAssertNil(pet.adoptionDate)
    }

    func testExistingDatesCanBeRemovedDuringEdit() throws {
        let pet = try Pet(
            name: "Nabi",
            species: .cat,
            birthDate: Date(timeIntervalSince1970: 100),
            adoptionDate: Date(timeIntervalSince1970: 200)
        )
        var form = PetFormState(pet: pet)
        form.hasBirthDate = false
        form.hasAdoptionDate = false
        try form.apply(to: pet, at: Date(timeIntervalSince1970: 300))
        XCTAssertNil(pet.birthDate)
        XCTAssertNil(pet.adoptionDate)
    }

    func testEditPreservesIdentityAndCreatedAtButChangesUpdatedAt() throws {
        let created = Date(timeIntervalSince1970: 100)
        let updated = Date(timeIntervalSince1970: 200)
        let id = UUID()
        let pet = try Pet(id: id, name: "Momo", species: .cat, now: created)
        var form = PetFormState(pet: pet)
        form.name = "Momo II"
        try form.apply(to: pet, at: updated)
        XCTAssertEqual(pet.id, id)
        XCTAssertEqual(pet.createdAt, created)
        XCTAssertEqual(pet.updatedAt, updated)
        XCTAssertEqual(pet.name, "Momo II")
    }

    func testProfilePhotoProcessingBoundsDimensionsAndCompresses() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 3_000, height: 2_000)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3_000, height: 2_000))
        }
        let sourceData = try XCTUnwrap(source.pngData())
        let outputData = try ProfilePhotoProcessor.process(sourceData)
        let output = try XCTUnwrap(UIImage(data: outputData))
        XCTAssertLessThanOrEqual(max(output.size.width, output.size.height), ProfilePhotoProcessor.maximumDimension)
        XCTAssertLessThan(outputData.count, sourceData.count)
    }

    func testPhotoCanBeRemovedThroughEditForm() throws {
        let pet = try Pet(name: "Momo", species: .cat, profilePhotoData: Data([1, 2, 3]))
        var form = PetFormState(pet: pet)
        form.removeProfilePhoto()
        try form.apply(to: pet, at: Date(timeIntervalSince1970: 300))
        XCTAssertNil(pet.profilePhotoData)
    }

    func testReplacementPhotoChangesDraftPreviewWithoutMutatingPet() throws {
        let original = Data([1, 2, 3])
        let replacement = Data([4, 5, 6])
        let pet = try Pet(name: "Momo", species: .cat, profilePhotoData: original)
        var form = PetFormState(pet: pet)
        form.selectProfilePhoto(replacement)
        XCTAssertEqual(form.profilePhotoData, replacement)
        XCTAssertEqual(pet.profilePhotoData, original)
    }

    func testCancelAfterReplacementPreservesOriginalPhoto() throws {
        let original = Data([1, 2, 3])
        let pet = try Pet(name: "Momo", species: .cat, profilePhotoData: original)
        var form: PetFormState? = PetFormState(pet: pet)
        form?.selectProfilePhoto(Data([4, 5, 6]))
        form = nil
        XCTAssertNil(form)
        XCTAssertEqual(pet.profilePhotoData, original)
    }

    func testSaveAfterReplacementPersistsNewPhoto() throws {
        let replacement = Data([4, 5, 6])
        let pet = try Pet(name: "Momo", species: .cat, profilePhotoData: Data([1, 2, 3]))
        var form = PetFormState(pet: pet)
        form.selectProfilePhoto(replacement)
        try form.apply(to: pet, at: Date(timeIntervalSince1970: 400))
        XCTAssertEqual(pet.profilePhotoData, replacement)
    }

    func testRemovePhotoOnlyChangesDraftUntilSave() throws {
        let original = Data([1, 2, 3])
        let pet = try Pet(name: "Momo", species: .cat, profilePhotoData: original)
        var form = PetFormState(pet: pet)
        form.removeProfilePhoto()
        XCTAssertNil(form.profilePhotoData)
        XCTAssertEqual(pet.profilePhotoData, original)
    }

    func testCancelAfterRemovalPreservesOriginalPhoto() throws {
        let original = Data([1, 2, 3])
        let pet = try Pet(name: "Momo", species: .cat, profilePhotoData: original)
        var form: PetFormState? = PetFormState(pet: pet)
        form?.removeProfilePhoto()
        form = nil
        XCTAssertEqual(pet.profilePhotoData, original)
    }

    func testPhotoRemovalRemainsAfterStoreReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "PhotoRemoval.store")
        let id = UUID()

        do {
            let container = try PettalePersistence.makeModelContainer(cloudKitEnabled: false, storeURL: storeURL)
            let pet = try Pet(id: id, name: "Momo", species: .cat, profilePhotoData: Data([1, 2, 3]))
            container.mainContext.insert(pet)
            try container.mainContext.save()
            var form = PetFormState(pet: pet)
            form.removeProfilePhoto()
            try form.apply(to: pet)
            try container.mainContext.save()
        }

        let reopened = try PettalePersistence.makeModelContainer(cloudKitEnabled: false, storeURL: storeURL)
        let pet = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Pet>()).first(where: { $0.id == id }))
        XCTAssertNil(pet.profilePhotoData)
    }

    func testEditingOneOfMultiplePetsDoesNotOverwriteAnother() throws {
        let container = try makeContainer()
        let first = try Pet(name: "Momo", species: .cat)
        let second = try Pet(name: "Bori", species: .dog)
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        try container.mainContext.save()
        var form = PetFormState(pet: second)
        form.name = "Bori II"
        try form.apply(to: second)
        try container.mainContext.save()
        let fetched = try container.mainContext.fetch(FetchDescriptor<Pet>())
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(fetched.first(where: { $0.id == first.id })?.name, "Momo")
        XCTAssertEqual(fetched.first(where: { $0.id == second.id })?.name, "Bori II")
    }
}
