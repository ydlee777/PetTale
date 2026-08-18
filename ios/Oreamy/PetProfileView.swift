import SwiftUI
import UIKit

struct PetProfileView: View {
    let pet: Pet
    let recordAction: () -> Void
    let editAction: () -> Void

    private var presentation: TodayPresentationSnapshot {
        TodayPresentation.snapshot(for: pet)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    PetAvatar(photoData: pet.profilePhotoData, size: 96)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pet.name)
                                .font(.title2.bold())
                            Text(pet.species.localizedName)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Selected pet: \(pet.name), \(pet.species.localizedName)")
                        Button("Edit", systemImage: "pencil", action: editAction)
                            .font(.subheadline.weight(.semibold))
                            .accessibilityLabel("Edit \(pet.name)'s profile")
                    }
                }

                Button(action: recordAction) {
                    HStack(spacing: 14) {
                        Image(systemName: "mic.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Record")
                                .font(.title3.bold())
                            Text("Tell today's tale")
                                .font(.subheadline)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("Record today's tale")

                if let story = presentation.recentStory {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Story")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        NavigationLink {
                            DiaryRecordDetailView(petName: pet.name, entry: story)
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(story.recordedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(story.displayText)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Recent Story, \(story.displayText)")
                        .accessibilityHint("Opens diary record details")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("My Records")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 10) {
                        destinationRow(
                            title: "Weight",
                            subtitle: weightSubtitle,
                            symbol: "chart.xyaxis.line",
                            accessibilityLabel: weightAccessibilityLabel
                        ) {
                            WeightTrendView(pet: pet, recordAction: recordAction)
                        }
                        destinationRow(
                            title: "Health History",
                            subtitle: String(localized: "Health, medication, and veterinary records"),
                            symbol: "heart.text.clipboard",
                            accessibilityLabel: String(localized: "Health History, Health, medication, and veterinary records")
                        ) {
                            HealthHistoryView(pet: pet, recordAction: recordAction)
                        }
                        destinationRow(
                            title: "Record Summary",
                            subtitle: String(localized: "See recent records at a glance"),
                            symbol: "calendar.badge.clock",
                            accessibilityLabel: String(localized: "Record Summary, See recent records at a glance")
                        ) {
                            PeriodStatisticsView(pet: pet, recordAction: recordAction)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var weightSubtitle: String {
        guard let latest = presentation.latestWeight else {
            return String(localized: "See how weight changes over time")
        }
        return String(localized: "Latest weight: \(WeightTrendPresentation.formattedKilograms(latest.kilograms))")
    }

    private var weightAccessibilityLabel: String {
        String(localized: "Weight, \(weightSubtitle)")
    }

    private func destinationRow<Destination: View>(
        title: LocalizedStringKey,
        subtitle: String,
        symbol: String,
        accessibilityLabel: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens details")
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
