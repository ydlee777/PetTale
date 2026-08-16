import PhotosUI
import SwiftData
import SwiftUI

enum PetFormMode {
    case create
    case edit(Pet)
}

struct PetFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let mode: PetFormMode
    let isFirstPet: Bool
    @State private var form: PetFormState
    @State private var pickerItem: PhotosPickerItem?
    @State private var isPhotoPickerPresented = false
    @State private var errorMessage: String?
    @State private var isLoadingPhoto = false

    init(mode: PetFormMode, isFirstPet: Bool = false) {
        self.mode = mode
        self.isFirstPet = isFirstPet
        let pet: Pet? = if case .edit(let pet) = mode { pet } else { nil }
        _form = State(initialValue: PetFormState(pet: pet))
    }

    var body: some View {
        Form {
            Section {
                photoEditor
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }

            Section {
                TextField("Name", text: $form.name)
                    .textContentType(.name)
                Picker("Species", selection: $form.species) {
                    ForEach(PetSpecies.allCases, id: \.self) { species in
                        Text(species.localizedName).tag(species)
                    }
                }
                Picker("Sex", selection: $form.sex) {
                    ForEach(PetSex.allCases, id: \.self) { sex in
                        Text(sex.localizedName).tag(sex)
                    }
                }
                optionalDate(
                    title: "Birthday",
                    setLabel: "Set birthday",
                    removeLabel: "Remove birthday",
                    enabled: $form.hasBirthDate,
                    date: $form.birthDate
                )
                optionalDate(
                    title: "Adoption Date",
                    setLabel: "Set adoption date",
                    removeLabel: "Remove adoption date",
                    enabled: $form.hasAdoptionDate,
                    date: $form.adoptionDate
                )
                TextField("Breed (optional)", text: $form.breed)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isFirstPet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!canSave)
                    .accessibilityLabel("Save Pet")
            }
        }
        .alert("Unable to Save", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .task(id: pickerItem) {
            await loadSelectedPhoto()
        }
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $pickerItem, matching: .images)
    }

    private var navigationTitle: LocalizedStringKey {
        switch mode {
        case .create: "Add Your Pet"
        case .edit: "Edit Pet"
        }
    }

    private var photoEditor: some View {
        let hasPhoto = form.profilePhotoData != nil
        return VStack(spacing: 8) {
            PetAvatar(photoData: form.profilePhotoData, size: 104)
                .accessibilityLabel(form.profilePhotoData == nil ? "Profile photo placeholder" : "Pet profile photo")
            if hasPhoto {
                Menu {
                    Button {
                        isPhotoPickerPresented = true
                    } label: {
                        Label("Choose Photo", systemImage: "photo")
                    }
                    Button("Remove Photo", systemImage: "trash", role: .destructive) {
                        form.removeProfilePhoto()
                        pickerItem = nil
                    }
                    .accessibilityLabel("Remove profile photo")
                } label: {
                    Text("Change Photo")
                }
                .disabled(isLoadingPhoto)
                .accessibilityLabel("Change profile photo")
            } else {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Add Photo", systemImage: "photo")
                }
                .disabled(isLoadingPhoto)
                .accessibilityLabel("Add profile photo")
            }
            if isLoadingPhoto {
                ProgressView("Preparing Photo")
            }
        }
    }

    private func optionalDate(
        title: LocalizedStringKey,
        setLabel: LocalizedStringKey,
        removeLabel: LocalizedStringKey,
        enabled: Binding<Bool>,
        date: Binding<Date>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            if enabled.wrappedValue {
                DatePicker(title, selection: date, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                Button {
                    enabled.wrappedValue = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(removeLabel)
            } else {
                Button("Unknown") {
                    enabled.wrappedValue = true
                }
                .foregroundStyle(.secondary)
                .accessibilityLabel(setLabel)
            }
        }
    }

    private var canSave: Bool {
        !form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingPhoto
    }

    @MainActor
    private func loadSelectedPhoto() async {
        guard let pickerItem else { return }
        isLoadingPhoto = true
        defer {
            isLoadingPhoto = false
            if self.pickerItem == pickerItem {
                self.pickerItem = nil
            }
        }
        do {
            guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                throw ProfilePhotoProcessingError.invalidImage
            }
            try Task.checkCancellation()
            let processedPhoto = try ProfilePhotoProcessor.process(data)
            try Task.checkCancellation()
            form.selectProfilePhoto(processedPhoto)
        } catch is CancellationError {
            // A new selection or explicit removal superseded this load.
        } catch {
            errorMessage = String(localized: "The selected photo could not be prepared.")
        }
    }

    private func save() {
        do {
            switch mode {
            case .create:
                modelContext.insert(try form.makePet())
            case .edit(let pet):
                try form.apply(to: pet)
            }
            try modelContext.save()
            if !isFirstPet { dismiss() }
        } catch PetValidationError.emptyName {
            errorMessage = String(localized: "Please enter your pet's name.")
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Your changes could not be saved. Please try again.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
