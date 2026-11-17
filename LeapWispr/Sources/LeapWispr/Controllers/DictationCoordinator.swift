import Foundation
import AppKit
import Combine

@MainActor
public final class DictationCoordinator: ObservableObject {
    public static let shared = DictationCoordinator()
    
    private let audioManager = AudioEngineManager.shared
    private let contextInspector = ContextInspector.shared
    private let settings = AppSettings.shared
    private let textInjector = TextInjector.shared
    private let pillHUD = FloatingPillHUD.shared
    private let speechProvider = AppleSpeechSTTProvider()
    
    private var currentAppContext: ActiveAppContext?
    private var activeTone: ToneType = .professional
    
    private init() {
        setupHUDCallbacks()
    }
    
    private func setupHUDCallbacks() {
        pillHUD.onToneCycleRequested = { [weak self] in
            self?.cycleToNextTone()
        }
        
        pillHUD.onCancelRequested = { [weak self] in
            self?.cancelDictation()
        }
        
        pillHUD.onStopRequested = { [weak self] in
            self?.stopAndProcessDictation()
        }
    }
    
    public func toggleDictation() {
        if audioManager.isRecording {
            stopAndProcessDictation()
        } else {
            startDictation()
        }
    }
    
    public func startDictation() {
        guard !audioManager.isRecording else { return }
        
        // 1. Capture foreground app context BEFORE showing our HUD
        let appContext = contextInspector.getCurrentAppContext()
        self.currentAppContext = appContext
        
        // 2. Determine tone (auto-adaptive or user selection)
        if settings.autoContextTone && settings.selectedTone != .translate {
            self.activeTone = appContext.suggestedTone
        } else {
            self.activeTone = settings.selectedTone
        }
        
        // 3. Start audio capture and live streaming recognition
        do {
            try audioManager.startRecording()
            
            // Set spoken language locale for speech recognition
            let spokenLocale = settings.spokenLanguage.locale
            speechProvider.setLocale(spokenLocale)
            
            // Start real-time live transcript streaming to the Floating Pill HUD
            try? speechProvider.startLiveRecognition(locale: spokenLocale) { [weak self] liveText in
                DispatchQueue.main.async {
                    self?.pillHUD.updateLiveTranscript(liveText)
                }
            }
            
            // Pipe audio buffer stream to speech recognizer
            audioManager.onAudioBuffer = { [weak self] buffer in
                self?.speechProvider.appendLiveAudioBuffer(buffer)
            }
            
            if settings.soundFeedback {
                NSSound(named: "Tink")?.play()
            }
            
            // 4. Show Floating Pill HUD
            pillHUD.show(status: .listening, tone: activeTone)
        } catch {
            print("[LeapWispr] Failed to start audio: \(error)")
            pillHUD.show(status: .error("Mic error: \(error.localizedDescription)"), tone: activeTone)
        }
    }
    
    public func stopAndProcessDictation() {
        guard audioManager.isRecording else { return }
        
        // Stop live recognition stream and get transcript
        let liveTranscript = speechProvider.stopLiveRecognition()
        audioManager.onAudioBuffer = nil
        let duration = audioManager.recordingDuration
        
        guard let audioURL = audioManager.stopRecording() else {
            pillHUD.hideImmediately()
            return
        }
        
        pillHUD.update(status: .processing("Polishing with \(activeTone.displayName)..."), tone: activeTone)
        
        Task {
            do {
                // 1. Get Speech Transcript (instant from live buffer, or fallback to file transcription)
                var rawTranscript = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                if rawTranscript.isEmpty {
                    let sttProvider = getSTTProvider()
                    rawTranscript = try await sttProvider.transcribe(audioURL: audioURL)
                }
                
                guard !rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    await MainActor.run {
                        self.pillHUD.update(status: .error("No speech detected"), tone: self.activeTone)
                    }
                    try? FileManager.default.removeItem(at: audioURL)
                    return
                }
                
                // 2. LLM Tone Transformation (Gemini Flash or High-Quality Heuristic)
                let appContext = self.currentAppContext ?? self.contextInspector.getCurrentAppContext()
                let polishedText = try await ToneTransformService.shared.transform(
                    rawTranscript: rawTranscript,
                    tone: self.activeTone,
                    appContext: appContext,
                    apiKey: self.settings.geminiApiKey,
                    spokenLanguage: self.settings.spokenLanguage,
                    targetLanguage: self.settings.targetLanguage
                )
                
                // 3. Inject Text into active cursor field
                await MainActor.run {
                    // Synchronously dismiss HUD so WindowServer restores 100% key responder focus
                    self.pillHUD.hideImmediately()
                }
                
                // Allow WindowServer to complete window hierarchy tear-down
                try? await Task.sleep(nanoseconds: 40_000_000) // 40ms
                
                // Inject polished text into the active app's cursor
                await self.textInjector.inject(text: polishedText, targetPid: appContext.pid)
                
                await MainActor.run {
                    // 4. Save to history
                    let record = DictationRecord(
                        rawText: rawTranscript,
                        transformedText: polishedText,
                        tone: self.activeTone,
                        appName: appContext.appName,
                        bundleId: appContext.bundleId,
                        duration: duration
                    )
                    self.settings.addRecord(record)
                    
                    if self.settings.soundFeedback {
                        NSSound(named: "Pop")?.play()
                    }
                }
                
                // Clean up temp audio file
                try? FileManager.default.removeItem(at: audioURL)
                
            } catch {
                print("[LeapWispr] Processing error: \(error)")
                await MainActor.run {
                    self.pillHUD.update(status: .error(error.localizedDescription), tone: self.activeTone)
                }
                try? FileManager.default.removeItem(at: audioURL)
            }
        }
    }
    
    public func cancelDictation() {
        _ = speechProvider.stopLiveRecognition()
        audioManager.onAudioBuffer = nil
        
        guard audioManager.isRecording else { return }
        if let audioURL = audioManager.stopRecording() {
            try? FileManager.default.removeItem(at: audioURL)
        }
        pillHUD.hideImmediately()
    }
    
    public func cycleToNextTone() {
        let allTones = ToneType.allCases
        if let currentIndex = allTones.firstIndex(of: activeTone) {
            let nextIndex = (currentIndex + 1) % allTones.count
            activeTone = allTones[nextIndex]
            settings.selectedTone = activeTone
            pillHUD.update(status: FloatingPillState.shared.status, tone: activeTone)
        }
    }
    
    private func getSTTProvider() -> STTProvider {
        switch settings.sttEngine {
        case .cloudGroq:
            if !settings.groqApiKey.isEmpty {
                return CloudGroqSTTProvider(apiKey: settings.groqApiKey, languageCode: settings.spokenLanguage.groqLanguageCode)
            }
            return speechProvider
            
        case .appleSpeech, .customEndpoint:
            return speechProvider
        }
    }
}
