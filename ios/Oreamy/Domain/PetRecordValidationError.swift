enum PetRecordValidationError: Error, Equatable {
    case emptyTranscript
    case negativeCount
    case negativeDuration
}
