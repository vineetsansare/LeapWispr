import Foundation

public enum SpokenLanguage: String, CaseIterable, Identifiable, Codable {
    case auto = "auto"
    case englishUS = "en-US"
    case englishIN = "en-IN"
    case hindi = "hi-IN"
    case spanish = "es-ES"
    case french = "fr-FR"
    case german = "de-DE"
    case italian = "it-IT"
    case portuguese = "pt-BR"
    case japanese = "ja-JP"
    case chinese = "zh-CN"
    case arabic = "ar-SA"
    case russian = "ru-RU"
    case korean = "ko-KR"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .auto: return "Auto Detect (System Locale)"
        case .englishUS: return "🇺🇸 English (US)"
        case .englishIN: return "🇮🇳 English (India / Hinglish)"
        case .hindi: return "🇮🇳 Hindi (हिन्दी)"
        case .spanish: return "🇪🇸 Spanish (Español)"
        case .french: return "🇫🇷 French (Français)"
        case .german: return "🇩🇪 German (Deutsch)"
        case .italian: return "🇮🇹 Italian (Italiano)"
        case .portuguese: return "🇧🇷 Portuguese (Português)"
        case .japanese: return "🇯🇵 Japanese (日本語)"
        case .chinese: return "🇨🇳 Chinese (中文)"
        case .arabic: return "🇸🇦 Arabic (العربية)"
        case .russian: return "🇷🇺 Russian (Русский)"
        case .korean: return "🇰🇷 Korean (한국어)"
        }
    }
    
    public var shortName: String {
        switch self {
        case .auto: return "Auto"
        case .englishUS: return "EN-US"
        case .englishIN: return "Hinglish"
        case .hindi: return "Hindi"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .japanese: return "Japanese"
        case .chinese: return "Chinese"
        case .arabic: return "Arabic"
        case .russian: return "Russian"
        case .korean: return "Korean"
        }
    }
    
    public var locale: Locale {
        switch self {
        case .auto: return Locale.current
        default: return Locale(identifier: rawValue)
        }
    }
    
    public var groqLanguageCode: String? {
        switch self {
        case .auto: return nil
        case .englishUS, .englishIN: return "en"
        case .hindi: return "hi"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .japanese: return "ja"
        case .chinese: return "zh"
        case .arabic: return "ar"
        case .russian: return "ru"
        case .korean: return "ko"
        }
    }
}

public enum TargetLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "English"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case hindi = "Hindi"
    case japanese = "Japanese"
    case chinese = "Mandarin Chinese"
    case arabic = "Arabic"
    case portuguese = "Portuguese"
    case italian = "Italian"
    case russian = "Russian"
    case korean = "Korean"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .english: return "🇺🇸 English"
        case .spanish: return "🇪🇸 Spanish"
        case .french: return "🇫🇷 French"
        case .german: return "🇩🇪 German"
        case .hindi: return "🇮🇳 Hindi"
        case .japanese: return "🇯🇵 Japanese"
        case .chinese: return "🇨🇳 Chinese"
        case .arabic: return "🇸🇦 Arabic"
        case .portuguese: return "🇧🇷 Portuguese"
        case .italian: return "🇮🇹 Italian"
        case .russian: return "🇷🇺 Russian"
        case .korean: return "🇰🇷 Korean"
        }
    }
}
