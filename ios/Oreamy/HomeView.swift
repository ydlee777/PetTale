import SwiftUI
import SwiftData

struct HomeView: View {
    let pets: [Pet]
    let authentication: AuthenticationController
    let subscription: SubscriptionController
    @State private var selectedPetID: UUID?
    @State private var presentedForm: PresentedPetForm?
    @State private var recordingPet: RecordingPet?
    @State private var isManagingPets = false
    @State private var isPetSelectorPresented = false
    @State private var isMenuPresented = false
    @State private var isPremiumPresented = false
    @State private var isDevelopmentWeightPresented = false
    @State private var selectedTab: OreamyRootTab = .today
#if DEBUG
    private let opensDevelopmentWeight: Bool
    private let opensDevelopmentHealth: Bool
    private let opensDevelopmentStatistics: Bool
    private let opensDevelopmentPremium: Bool
#endif

    init(pets: [Pet], authentication: AuthenticationController, subscription: SubscriptionController) {
        self.pets = pets
        self.authentication = authentication
        self.subscription = subscription
        let requestedName = ProcessInfo.processInfo.environment["OREAMY_SELECTED_PET"]
            ?? ProcessInfo.processInfo.arguments.value(after: "-oreamySelectedPet")
        _selectedPetID = State(initialValue: pets.first(where: { $0.name == requestedName })?.id ?? pets.first?.id)
#if DEBUG
        let opensDiary = ProcessInfo.processInfo.environment["OREAMY_OPEN_DIARY"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-oreamyDiary")
        _selectedTab = State(initialValue: opensDiary ? .diary : .today)
        opensDevelopmentWeight = ProcessInfo.processInfo.environment["OREAMY_OPEN_WEIGHT"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-oreamyWeight")
        opensDevelopmentHealth = ProcessInfo.processInfo.environment["OREAMY_OPEN_HEALTH"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-oreamyHealth")
        opensDevelopmentStatistics = ProcessInfo.processInfo.environment["OREAMY_OPEN_STATISTICS"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-oreamyStatistics")
        opensDevelopmentPremium = ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-oreamyPremium") }
        _isMenuPresented = State(initialValue: ProcessInfo.processInfo.arguments.contains("-oreamyMenu"))
        _isPremiumPresented = State(initialValue: opensDevelopmentPremium)
        _isDevelopmentWeightPresented = State(initialValue: ProcessInfo.processInfo.arguments.contains("-oreamyNavigationWeight"))
        _isPetSelectorPresented = State(initialValue: ProcessInfo.processInfo.arguments.contains("-oreamyPetSelector"))
#endif
    }

    private var selectedPet: Pet? {
        guard let id = PetSelection.resolvedID(selectedID: selectedPetID, availableIDs: pets.map(\.id)) else { return nil }
        return pets.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selectedPet {
#if DEBUG
                    if opensDevelopmentStatistics {
                        PeriodStatisticsView(pet: selectedPet) { startRecording(for: selectedPet) }
                    } else if opensDevelopmentHealth {
                        HealthHistoryView(pet: selectedPet) { startRecording(for: selectedPet) }
                    } else if opensDevelopmentWeight {
                        WeightTrendView(pet: selectedPet) { startRecording(for: selectedPet) }
                    } else {
                        homeTabs(for: selectedPet)
                    }
#else
                    homeTabs(for: selectedPet)
#endif
                }
            }
            .navigationTitle(selectedTab.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let selectedPet {
                        Button {
                            isPetSelectorPresented = true
                        } label: {
                            HStack(spacing: 5) {
                                Text(selectedPet.name).fontWeight(.semibold)
                                Image(systemName: "chevron.down").font(.caption.bold())
                            }
                        }
                        .accessibilityLabel(Text("Selected pet: \(selectedPet.name). Choose a pet"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let selectedPet {
                        Button {
                            isMenuPresented = true
                        } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                        .accessibilityLabel("Menu")
                    }
                }
            }
            .confirmationDialog("Choose a pet", isPresented: $isPetSelectorPresented, titleVisibility: .visible) {
                if let selectedPet {
                    ForEach(pets, id: \.id) { pet in
                        Button {
                            selectedPetID = pet.id
                        } label: {
                            if pet.id == selectedPet.id {
                                Label("\(pet.name), Selected", systemImage: "checkmark")
                            } else {
                                Text(pet.name)
                            }
                        }
                    }
                }
                Button("Add Pet", systemImage: "plus") { presentedForm = .create }
                Button("Manage Pets", systemImage: "pawprint") { isManagingPets = true }
            }
            .navigationDestination(isPresented: $isManagingPets) {
                ManagePetsView(
                    pets: pets,
                    addAction: { presentedForm = .create },
                    editAction: { presentedForm = .edit($0) },
                    deleteAction: petDidDelete
                )
            }
            .navigationDestination(isPresented: $isMenuPresented) {
                if let selectedPet {
                    OreamyMenuView(
                        pet: selectedPet,
                        pets: pets,
                        authentication: authentication,
                        subscription: subscription,
                        recordAction: { startRecording(for: selectedPet) },
                        addPetAction: { presentedForm = .create },
                        editPetAction: { presentedForm = .edit($0) },
                        deletePetAction: petDidDelete,
                        diaryAction: { selectedTab = .diary }
                    )
                }
            }
#if DEBUG
            .navigationDestination(isPresented: $isPremiumPresented) {
                PremiumView(controller: subscription)
            }
            .navigationDestination(isPresented: $isDevelopmentWeightPresented) {
                if let selectedPet {
                    WeightTrendView(pet: selectedPet) { startRecording(for: selectedPet) }
                }
            }
#endif
            .sheet(item: $presentedForm) { form in
                NavigationStack {
                    petForm(for: form)
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
            .task { await subscription.start() }
        }
    }

    private func homeTabs(for selectedPet: Pet) -> some View {
                    TabView(selection: $selectedTab) {
                        PetProfileView(
                            pet: selectedPet,
                            recordAction: { startRecording(for: selectedPet) },
                            editAction: { presentedForm = .edit(selectedPet) }
                        )
                        .tabItem { Label("Today", systemImage: "house") }
                        .tag(OreamyRootTab.today)

                        DiaryView(pet: selectedPet) { startRecording(for: selectedPet) }
                            .tabItem { Label("Diary", systemImage: "book.closed") }
                            .tag(OreamyRootTab.diary)
                    }
    }

    @ViewBuilder
    private func petForm(for form: PresentedPetForm) -> some View {
        switch form {
        case .create:
            PetFormView(mode: .create, saveAction: selectCreatedPet)
        case .edit(let pet):
            PetFormView(mode: .edit(pet))
        }
    }

    private func selectCreatedPet(_ pet: Pet) {
        selectedPetID = PetSelection.selectedID(afterCreating: pet.id)
    }

    private func petDidDelete(_ pet: Pet) {
        selectedPetID = PetSelection.selectedID(
            afterDeleting: pet.id,
            currentID: selectedPetID,
            remainingIDs: pets.filter { $0.id != pet.id }.map(\.id)
        )
    }

    private func startRecording(for pet: Pet) {
        recordingPet = RecordingPet(id: pet.id, name: pet.name)
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

private extension [String] {
    func value(after argument: String) -> String? {
        guard let index = firstIndex(of: argument), indices.contains(index + 1) else { return nil }
        return self[index + 1]
    }
}
