import SwiftUI

struct OreamyMenuView: View {
    let pet: Pet
    let pets: [Pet]
    let authentication: AuthenticationController
    let subscription: SubscriptionController
    let recordAction: () -> Void
    let addPetAction: () -> Void
    let editPetAction: (Pet) -> Void
    let deletePetAction: (Pet) -> Void
    let diaryAction: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Pets") {
                NavigationLink {
                    ManagePetsView(
                        pets: pets,
                        addAction: addPetAction,
                        editAction: editPetAction,
                        deleteAction: deletePetAction
                    )
                } label: {
                    Label("Manage Pets", systemImage: "pawprint")
                }
            }

            Section("Records") {
                Button {
                    diaryAction()
                    dismiss()
                } label: {
                    Label("Diary", systemImage: "book.closed")
                }
                .foregroundStyle(.primary)

                NavigationLink {
                    WeightTrendView(pet: pet, recordAction: recordAction)
                } label: {
                    Label("Weight", systemImage: "chart.xyaxis.line")
                }
                NavigationLink {
                    HealthHistoryView(pet: pet, recordAction: recordAction)
                } label: {
                    Label("Health History", systemImage: "heart.text.clipboard")
                }
                NavigationLink {
                    PeriodStatisticsView(pet: pet, recordAction: recordAction)
                } label: {
                    Label("Record Summary", systemImage: "calendar.badge.clock")
                }
            }

            Section("Oreamy") {
                NavigationLink {
                    PremiumView(controller: subscription)
                } label: {
                    Label("Oreamy Premium", systemImage: "heart.circle.fill")
                }
                NavigationLink {
                    AuthenticationView(controller: authentication, subscription: subscription)
                } label: {
                    Label("Account", systemImage: "person.crop.circle")
                }
            }
        }
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
    }
}
