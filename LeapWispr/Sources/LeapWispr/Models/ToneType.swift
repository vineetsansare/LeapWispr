import Foundation

public enum ToneType: String, CaseIterable, Identifiable, Codable {
    case professional = "professional"
    case casual = "casual"
    case excited = "excited"
    case devPrompt = "dev_prompt"
    case bulletPoints = "bullet_points"
    case raw = "raw"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .professional: return "Professional"
        case .casual: return "Casual"
        case .excited: return "Excited"
        case .devPrompt: return "Dev / Prompt"
        case .bulletPoints: return "Bullet Points"
        case .raw: return "Raw Cleaned"
        }
    }
    
    public var icon: String {
        switch self {
        case .professional: return "briefcase.fill"
        case .casual: return "bubble.left.and.bubble.right.fill"
        case .excited: return "sparkles"
        case .devPrompt: return "chevron.left.forwardslash.chevron.right"
        case .bulletPoints: return "list.bullet"
        case .raw: return "waveform"
        }
    }
    
    public var emoji: String {
        switch self {
        case .professional: return "💼"
        case .casual: return "💬"
        case .excited: return "🚀"
        case .devPrompt: return "💻"
        case .bulletPoints: return "📝"
        case .raw: return "🎙️"
        }
    }
    
    public var systemPrompt: String {
        switch self {
        case .professional:
            return """
            Rewrite the spoken transcript into clean, polished, professional business writing.
            - Ensure impeccable grammar, polite tone, and clarity.
            - Strip conversational filler words ('um', 'uh', 'you know', 'like').
            - Correct false starts and self-corrections gracefully.
            - Do not add conversational conversational preamble (e.g. 'Here is your text:').
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
