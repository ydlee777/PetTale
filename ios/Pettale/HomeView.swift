import SwiftUI
import SwiftData

struct HomeView: View {
    let pets: [Pet]
    @State private var selectedPetID: UUID?
    @State private var presentedForm: PresentedPetForm?
    @State private var recordingPet: RecordingPet?
    @State private var authentication = AuthenticationController()
    @State private var isAccountPresented = false

    init(pets: [Pet]) {
        self.pets = pets
        _selectedPetID = State(initialValue: pets.first?.id)
    }

    private var selectedPet: Pet? {
        pets.first(where: { $0.id == selectedPetID }) ?? pets.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selectedPet {
                    PetProfileView(
                        pet: selectedPet,
                        recordAction: {
                            recordingPet = RecordingPet(id: selectedPet.id, name: selectedPet.name)
                        },
                        editAction: { presentedForm = .edit(selectedPet) }
                    )
                }
            }
            .navigationTitle("Pettale")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if pets.count > 1 {
                        Picker("Pet", selection: selectedPetBinding) {
                            ForEach(pets, id: \.id) { pet in
                                Text(pet.name).tag(pet.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Pet", systemImage: "plus") {
                        presentedForm = .create
                    }
                    .accessibilityLabel("Add Pet")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Account", systemImage: "person.crop.circle") { isAccountPresented = true }
                        .accessibilityLabel("Pettale Account")
                }
            }
            .sheet(item: $presentedForm) { form in
                NavigationStack {
                    switch form {
                    case .create:
                        PetFormView(mode: .create)
                    case .edit(let pet):
                        PetFormView(mode: .edit(pet))
                    }
                }
            }
            .fullScreenCover(item: $recordingPet) { pet in
                RecordingFlowView(petID: pet.id, petName: pet.name) {
                    recordingPet = nil
                }
            }
            .sheet(isPresented: $isAccountPresented) {
                NavigationStack { AuthenticationView(controller: authentication) }
            }
        }
    }

    private var selectedPetBinding: Binding<UUID> {
        Binding(
            get: { selectedPet?.id ?? pets[0].id },
            set: { selectedPetID = $0 }
        )
    }
}

private struct RecordingPet: Identifiable {
    let id: UUID
    let name: String
}

private enum PresentedPetForm: Identifiable {
    case create
    case edit(Pet)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let pet): "edit-\(pet.id.uuidString)"
        }
    }
}
