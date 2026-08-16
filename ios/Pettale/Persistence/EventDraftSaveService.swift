import Foundation
import SwiftData

enum EventDraftSaveError: LocalizedError, Equatable {
    case emptyTranscript
    case petNotFound
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .emptyTranscript: String(localized: "Review the transcript before saving.")
        case .petNotFound: String(localized: "The recording's pet is no longer available.")
        case .persistenceFailed: String(localized: "Your events couldn't be saved. Try again.")
        }
    }
}

struct SavedEventGraph: Equatable {
    let recordID: UUID
    let eventIDs: [UUID]
}

@MainActor
enum EventDraftSaveService {
    static func save(
        petID: UUID,
        approvedTranscript: String,
        recordedAt: Date,
        drafts: [EditableEventDraft],
        in context: ModelContext,
        now: Date = Date()
    ) throws -> SavedEventGraph {
        let transcript = approvedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { throw EventDraftSaveError.emptyTranscript }
        let requestedPetID = petID
        let descriptor = FetchDescriptor<Pet>(predicate: #Predicate { $0.id == requestedPetID })
        guard let pet = try context.fetch(descriptor).first else { throw EventDraftSaveError.petNotFound }
        let normalized = try drafts.map(EventDraftValidator.normalized)

        do {
            var graph: SavedEventGraph?
            try context.transaction {
                let record = try PetRecord(
                    pet: pet,
                    originalTranscript: transcript,
                    recordedAt: recordedAt,
                    now: now
                )
                context.insert(record)
                let events = try normalized.map { draft in
                    let event = try PetEvent(
                        record: record,
                        category: draft.category,
                        eventType: draft.eventType,
                        occurredAt: draft.occurredAt,
                        numericValue: draft.numericValue,
                        unit: draft.unit,
                        count: draft.count,
                        durationMinutes: draft.durationMinutes,
                        description: draft.description,
                        now: now
                    )
                    context.insert(event)
                    return event
                }
                try context.save()
                graph = SavedEventGraph(recordID: record.id, eventIDs: events.map(\.id))
            }
            return try graph.unwrap(or: EventDraftSaveError.persistenceFailed)
        } catch let error as EventDraftValidationError {
            throw error
        } catch let error as EventDraftSaveError {
            throw error
        } catch {
            throw EventDraftSaveError.persistenceFailed
        }
    }
}

private extension Optional {
    func unwrap(or error: @autoclosure () -> Error) throws -> Wrapped {
        guard let self else { throw error() }
        return self
    }
}
