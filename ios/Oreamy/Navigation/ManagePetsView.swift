import SwiftData
import SwiftUI

struct ManagePetsView: View {
    @Environment(\.modelContext) private var modelContext
    let pets: [Pet]
    let addAction: () -> Void
    let editAction: (Pet) -> Void
    let deleteAction: (Pet) -> Void
    @State private var pendingDeletion: Pet?
    @State private var deletionError: String?

    init(
        pets: [Pet],
        addAction: @escaping () -> Void,
        editAction: @escaping (Pet) -> Void,
        deleteAction: @escaping (Pet) -> Void = { _ in }
    ) {
        self.pets = pets
        self.addAction = addAction
        self.editAction = editAction
        self.deleteAction = deleteAction
    }

    var body: some View {
        List {
            Section {
                ForEach(pets, id: \.id) { pet in
                    Button {
                        editAction(pet)
                    } label: {
                        HStack(spacing: 14) {
                            PetAvatar(photoData: pet.profilePhotoData, size: 44)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pet.name).foregroundStyle(.primary)
                                Text(pet.species.localizedName)
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold()).foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityLabel(Text("Edit \(pet.name)'s profile"))
                    .swipeActions(edge: .trailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            pendingDeletion = pet
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Pets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Pet", systemImage: "plus", action: addAction)
                    .accessibilityLabel("Add Pet")
            }
        }
        .alert(
            pendingDeletion.map { String(localized: "Delete \($0.name)?") } ?? String(localized: "Delete Pet?"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { pet in
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) { delete(pet) }
        } message: { pet in
            Text("Deleting \(pet.name) also deletes their diary and records from this device and iCloud.")
        }
        .alert("Couldn't Delete Pet", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionError ?? "Please try again.")
        }
    }

    private func delete(_ pet: Pet) {
        do {
            try PetDeletionService.delete(pet, from: modelContext)
            pendingDeletion = nil
            deleteAction(pet)
        } catch {
            modelContext.rollback()
            deletionError = String(localized: "Your pet couldn't be deleted. Please try again.")
        }
    }
}

enum PetDeletionService {
    @MainActor
    static func delete(_ pet: Pet, from context: ModelContext) throws {
        context.delete(pet)
        try context.save()
    }
}
