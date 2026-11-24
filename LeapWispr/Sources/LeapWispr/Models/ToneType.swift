import Foundation

public enum ToneType: String, CaseIterable, Identifiable, Codable {
    case autoContext = "auto_context"
    case professional = "professional"
    case casual = "casual"
    case translate = "translate"
    case devPrompt = "dev_prompt"
    case bulletPoints = "bullet_points"
    case excited = "excited"
    case raw = "raw"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .autoContext: return "Auto Context"
        case .professional: return "Professional"
        case .casual: return "Casual"
        case .translate: return "Translate"
        case .devPrompt: return "Dev / Prompt"
        case .bulletPoints: return "Bullet Points"
        case .excited: return "Excited"
        case .raw: return "Raw Cleaned"
        }
    }
    
    public var icon: String {
        switch self {
        case .autoContext: return "sparkles"
        case .professional: return "briefcase.fill"
        case .casual: return "bubble.left.and.bubble.right.fill"
        case .translate: return "globe"
        case .devPrompt: return "chevron.left.forwardslash.chevron.right"
        case .bulletPoints: return "list.bullet"
        case .excited: return "sparkles"
        case .raw: return "waveform"
        }
    }
    
    public var emoji: String {
        switch self {
        case .autoContext: return "🪄"
        case .professional: return "💼"
        case .casual: return "💬"
        case .translate: return "🌍"
        case .devPrompt: return "💻"
        case .bulletPoints: return "📝"
        case .excited: return "🚀"
        case .raw: return "🎙️"
        }
    }
    
    public var summaryDescription: String {
        switch self {
        case .autoContext: return "Auto-detects active app tone"
        case .professional: return "Polished business writing"
        case .casual: return "Friendly for Slack & messaging"
        case .translate: return "Multilingual to English translation"
        case .devPrompt: return "Formatted for AI coding & terminal"
        case .bulletPoints: return "Structured list & action items"
        case .excited: return "Energetic & high-impact phrasing"
        case .raw: return "Raw transcript with light cleanup"
        }
    }
    
    public var systemPrompt: String {
        switch self {
        case .autoContext:
            return "" // Handled dynamically in DictationCoordinator
        case .professional:
            return """
            Rewrite the spoken transcript into clean, polished, professional business writing.
            - Ensure impeccable grammar, polite tone, and clarity.
            - Strip conversational filler words ('um', 'uh', 'you know', 'like').
            - Correct false starts and self-corrections gracefully.
            - Return ONLY the rewritten text.
            """
        case .casual:
            return """
            Rewrite the spoken transcript into a friendly, casual, natural conversational message suitable for Slack, Teams, or texting.
            - Contractions are encouraged (e.g. 'I'll', 'we're').
            - Keep it snappy, human, and authentic.
            - Add an appropriate emoji if it fits naturally, but do not overdo it.
            - Strip filler words ('um', 'uh').
            - Return ONLY the rewritten text.
            """
        case .translate:
            return """
            You are an expert multilingual translator and writing assistant.
            The user is speaking in a non-English language (such as Hindi, Arabic, Spanish, French, German, Japanese, Mandarin, etc.) or a mixed/code-switched language (such as Hinglish).
            Translate the spoken words into natural, fluent, and idiomatic English.
            - If the input is already in English, refine its clarity and grammar while keeping it natural.
            - Eliminate speech fillers ('um', 'uh', 'matlab', 'yaani').
            - Preserve the original meaning, intent, technical terms, and emotional tone.
            - Format punctuation and capitalization cleanly.
            - Return ONLY the final translated English text without quotes, markdown headers, or explanations.
            """
        case .excited:
            return """
            Rewrite the spoken transcript with enthusiastic, energetic, and high-impact momentum!
            - Use dynamic action verbs and upbeat phrasing.
            - Preserve the core message while making it celebratory and inspiring.
            - Return ONLY the rewritten text.
            """
        case .devPrompt:
            return """
            Rewrite the spoken transcript into a crisp, technical instruction or prompt for AI coding assistants (like Cursor, Claude, ChatGPT, or terminal command).
            - Use imperative voice (e.g. 'Refactor the auth handler', 'Add error handling for 404').
            - Format code identifiers, filenames, and flags with backticks (`like_this`).
            - Keep it precise, unambiguous, and developer-focused.
            - Return ONLY the rewritten text.
            """
        case .bulletPoints:
            return """
            Summarize and structure the spoken transcript into a concise markdown bulleted list.
            - Extract key action items, decisions, or ideas.
            - Use '-' for bullet items.
            - Bold key concepts if helpful.
            - Return ONLY the markdown bullet points.
            """
        case .raw:
            return """
            Format the raw spoken transcript into properly capitalized and punctuated sentences.
            - Strip stuttering and filler words ('um', 'uh').
            - Do not change vocabulary or tone.
            - Return ONLY the cleanly punctuated transcript.
            """
        }
    }
}
