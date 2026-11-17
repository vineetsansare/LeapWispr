import Foundation
import SwiftUI
import Combine

public enum STTEngineType: String, CaseIterable, Identifiable, Codable {
    case appleSpeech = "apple_speech"
    case cloudGroq = "cloud_groq"
    case customEndpoint = "custom_endpoint"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .appleSpeech: return "Apple Speech (On-Device, Free)"
        case .cloudGroq: return "Groq Whisper (Ultra-Fast Cloud)"
        case .customEndpoint: return "Custom STT Server (Parakeet / Whisper)"
        }
    }
}

public enum HotkeyMode: String, CaseIterable, Identifiable, Codable {
    case doubleTapFn = "double_tap_fn"
    case holdFn = "hold_fn"
    case optionSpace = "option_space"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .doubleTapFn: return "Double-Tap fn"
        case .holdFn: return "Hold fn while speaking"
        case .optionSpace: return "Option + Space"
        }
    }
}

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    @Published public var geminiApiKey: String {
        didSet { defaults.set(geminiApiKey, forKey: "gemini_api_key") }
    }
    
    @Published public var groqApiKey: String {
        didSet { defaults.set(groqApiKey, forKey: "groq_api_key") }
    }
    
    @Published public var selectedTone: ToneType {
        didSet { defaults.set(selectedTone.rawValue, forKey: "selected_tone") }
    }
    
    @Published public var autoContextTone: Bool {
        didSet { defaults.set(autoContextTone, forKey: "auto_context_tone") }
    }
    
    @Published public var sttEngine: STTEngineType {
        didSet { defaults.set(sttEngine.rawValue, forKey: "stt_engine") }
    }
    
    @Published public var hotkeyMode: HotkeyMode {
        didSet { defaults.set(hotkeyMode.rawValue, forKey: "hotkey_mode") }
    }
    
    @Published public var soundFeedback: Bool {
        didSet { defaults.set(soundFeedback, forKey: "sound_feedback") }
    }
    
    @Published public var totalWordsSpoken: Int {
        didSet { defaults.set(totalWordsSpoken, forKey: "total_words_spoken") }
    }
    
    @Published public var history: [DictationRecord] = [] {
        didSet { saveHistory() }
    }
    
    private init() {
        self.geminiApiKey = defaults.string(forKey: "gemini_api_key") ?? ""
        self.groqApiKey = defaults.string(forKey: "groq_api_key") ?? ""
        
        let savedTone = defaults.string(forKey: "selected_tone") ?? ToneType.professional.rawValue
        self.selectedTone = ToneType(rawValue: savedTone) ?? .professional
        
        self.autoContextTone = defaults.object(forKey: "auto_context_tone") as? Bool ?? true
        
        let savedEngine = defaults.string(forKey: "stt_engine") ?? STTEngineType.appleSpeech.rawValue
        self.sttEngine = STTEngineType(rawValue: savedEngine) ?? .appleSpeech
        
        let savedHotkey = defaults.string(forKey: "hotkey_mode") ?? HotkeyMode.doubleTapFn.rawValue
        self.hotkeyMode = HotkeyMode(rawValue: savedHotkey) ?? .doubleTapFn
        
        self.soundFeedback = defaults.object(forKey: "sound_feedback") as? Bool ?? true
        self.totalWordsSpoken = defaults.integer(forKey: "total_words_spoken")
        
        loadHistory()
    }
    
    public func addRecord(_ record: DictationRecord) {
        history.insert(record, at: 0)
        if history.count > 100 {
            history.removeLast()
        }
        let wordCount = record.transformedText.split(separator: " ").count
        totalWordsSpoken += wordCount
    }
    
    public func clearHistory() {
        history.removeAll()
        saveHistory()
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            defaults.set(encoded, forKey: "dictation_history")
        }
    }
    
    private func loadHistory() {
        if let data = defaults.data(forKey: "dictation_history"),
           let decoded = try? JSONDecoder().decode([DictationRecord].self, from: data) {
            self.history = decoded
        }
    }
}
