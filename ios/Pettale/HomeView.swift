import SwiftUI
import SwiftData

struct HomeView: View {
    let pets: [Pet]
    @State private var selectedPetID: UUID?
    @State private var presentedForm: PresentedPetForm?

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
                    PetProfileView(pet: selectedPet) {
                        presentedForm = .edit(selectedPet)
                    }
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
        }
    }

    private var selectedPetBinding: Binding<UUID> {
        Binding(
            get: { selectedPet?.id ?? pets[0].id },
            set: { selectedPetID = $0 }
        )
    }
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
