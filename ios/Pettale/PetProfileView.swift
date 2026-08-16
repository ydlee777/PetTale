import SwiftUI
import UIKit

struct PetProfileView: View {
    let pet: Pet
    let recordAction: () -> Void
    let editAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                PetAvatar(photoData: pet.profilePhotoData, size: 150)
                    .accessibilityLabel("Profile photo for \(pet.name)")
                VStack(spacing: 5) {
                    Text(pet.name)
                        .font(.largeTitle.bold())
                    Text(pet.species.localizedName)
                        .foregroundStyle(.secondary)
                }

                Button(action: recordAction) {
                    VStack(spacing: 5) {
                        Label("Record", systemImage: "mic.fill")
                            .font(.title3.bold())
                        Text("Tell today's tale")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Record today's tale")

                VStack(spacing: 0) {
                    if pet.sex != .unknown { profileRow("Sex", value: pet.sex.localizedName) }
                    if let birthDate = pet.birthDate { profileRow("Birthday", value: birthDate.formatted(date: .long, time: .omitted)) }
                    if let adoptionDate = pet.adoptionDate { profileRow("Adoption Date", value: adoptionDate.formatted(date: .long, time: .omitted)) }
                    if let breed = pet.breed { profileRow("Breed", value: breed) }
                }
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))

                Button("Edit Pet", systemImage: "pencil", action: editAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Edit \(pet.name)'s profile")
            }
            .padding()
        }
    }

    private func profileRow(_ label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .padding()
    }
}

struct PetAvatar: View {
    let photoData: Data?
    let size: CGFloat

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.27)
                    .foregroundStyle(.tint)
                    .background(Color.accentColor.opacity(0.12))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

extension PetSpecies {
    var localizedName: String {
        switch self {
        case .cat: String(localized: "Cat")
        case .dog: String(localized: "Dog")
        case .other: String(localized: "Other")
        }
    }
}

extension PetSex {
    var localizedName: String {
        switch self {
        case .male: String(localized: "Male")
        case .female: String(localized: "Female")
        case .unknown: String(localized: "Unknown")
        }
    }
}
