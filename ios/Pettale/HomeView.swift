import SwiftUI
import SwiftData

struct HomeView: View {
    let pets: [Pet]
    @State private var selectedPetID: UUID?
    @State private var presentedForm: PresentedPetForm?
    @State private var recordingPet: RecordingPet?
    @State private var authentication = AuthenticationController()
    @State private var isAccountPresented = false
    @State private var selectedTab: HomeTab = .today

    init(pets: [Pet]) {
        self.pets = pets
        let requestedName = ProcessInfo.processInfo.environment["PETTALE_SELECTED_PET"]
            ?? ProcessInfo.processInfo.arguments.value(after: "-pettaleSelectedPet")
        _selectedPetID = State(initialValue: pets.first(where: { $0.name == requestedName })?.id ?? pets.first?.id)
#if DEBUG
        let opensDiary = ProcessInfo.processInfo.environment["PETTALE_OPEN_DIARY"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-pettaleDiary")
        _selectedTab = State(initialValue: opensDiary ? .diary : .today)
#endif
    }

    private var selectedPet: Pet? {
        pets.first(where: { $0.id == selectedPetID }) ?? pets.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selectedPet {
                    TabView(selection: $selectedTab) {
                        PetProfileView(
                            pet: selectedPet,
                            recordAction: { startRecording(for: selectedPet) },
                            editAction: { presentedForm = .edit(selectedPet) }
                        )
                        .tabItem { Label("Today", systemImage: "house") }
                        .tag(HomeTab.today)

                        DiaryView(pet: selectedPet) { startRecording(for: selectedPet) }
                            .tabItem { Label("Diary", systemImage: "book.closed") }
                            .tag(HomeTab.diary)
                    }
                }
            }
            .navigationTitle(selectedTab == .today ? "Pettale" : "Diary")
            .navigationBarTitleDisplayMode(selectedTab == .today ? .large : .inline)
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
                RecordingFlowView(
                    petID: pet.id,
                    petName: pet.name,
                    knownPetNames: pets.map(\.name),
                    authentication: authentication
                ) {
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

    private func startRecording(for pet: Pet) {
        recordingPet = RecordingPet(id: pet.id, name: pet.name)
    }
}

private enum HomeTab: Hashable {
    case today
    case diary
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

private extension [String] {
    func value(after argument: String) -> String? {
        guard let index = firstIndex(of: argument), indices.contains(index + 1) else { return nil }
        return self[index + 1]
    }
}
