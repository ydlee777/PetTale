import Foundation

enum WorkflowPresentation {
    static func audioPlay(locale: Locale = .current, bundle: Bundle = .main) -> String {
        localized("audio.play", defaultValue: "Play", locale: locale, bundle: bundle)
    }

    static func audioPause(locale: Locale = .current, bundle: Bundle = .main) -> String {
        localized("audio.pause", defaultValue: "Pause", locale: locale, bundle: bundle)
    }

    static func eventType(_ code: String, locale: Locale = .current, bundle: Bundle = .main) -> String {
        switch code {
        case "BODY_WEIGHT": localized("eventType.BODY_WEIGHT", defaultValue: "Body Weight", locale: locale, bundle: bundle)
        case "VOMITING": localized("eventType.VOMITING", defaultValue: "Vomiting", locale: locale, bundle: bundle)
        case "PLAY": localized("eventType.PLAY", defaultValue: "Play", locale: locale, bundle: bundle)
        default: code.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func quotaMessage(locale: Locale = .current, bundle: Bundle = .main) -> String {
        localized(
            "ai.error.quotaExceeded",
            defaultValue: "You've reached your AI usage limit for this month.",
            locale: locale,
            bundle: bundle
        )
    }

    private static func localized(_ key: String, defaultValue: String, locale: Locale, bundle: Bundle) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        let localizedBundle = bundle.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? bundle
        return NSLocalizedString(key, bundle: localizedBundle, value: defaultValue, comment: "")
    }
}

enum TranscriptionLanguagePreference {
    static let key = "preferredTranscriptionLanguage"

    static func initialLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> TranscriptionLanguage {
        guard let first = preferredLanguages.first else { return .english }
        return Locale(identifier: first).language.languageCode == .korean ? .korean : .english
    }

    static func load(
        defaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> TranscriptionLanguage {
        guard let rawValue = defaults.string(forKey: key),
              let language = TranscriptionLanguage(rawValue: rawValue) else {
            return initialLanguage(preferredLanguages: preferredLanguages)
        }
        return language
    }

    static func save(_ language: TranscriptionLanguage, defaults: UserDefaults = .standard) {
        defaults.set(language.rawValue, forKey: key)
    }
}
