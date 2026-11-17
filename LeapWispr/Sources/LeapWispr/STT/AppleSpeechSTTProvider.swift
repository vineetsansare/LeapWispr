import Foundation
import Speech
import AVFoundation

public final class AppleSpeechSTTProvider: @unchecked Sendable, STTProvider {
    public let name = "Apple Speech (On-Device)"
    
    private var recognizers: [String: SFSpeechRecognizer] = [:]
    private let recognizerLock = NSLock()
    private var activeLocale: Locale = Locale.current
    
    // Live Streaming Recognition State
    private let liveLock = NSLock()
    private var liveRequest: SFSpeechAudioBufferRecognitionRequest?
    private var liveTask: SFSpeechRecognitionTask?
    private var latestLiveText: String = ""
    
    public init(locale: Locale = Locale.current) {
        self.activeLocale = locale
        if let rec = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")) {
            self.recognizers[locale.identifier] = rec
        }
    }
    
    public func setLocale(_ locale: Locale) {
        recognizerLock.lock()
        self.activeLocale = locale
        recognizerLock.unlock()
    }
    
    private func getRecognizer(for locale: Locale? = nil) -> SFSpeechRecognizer? {
        recognizerLock.lock()
        defer { recognizerLock.unlock() }
        
        let targetLocale = locale ?? activeLocale
        let id = targetLocale.identifier
        
        if let existing = recognizers[id], existing.isAvailable {
            return existing
        }
        
        if let newRec = SFSpeechRecognizer(locale: targetLocale), newRec.isAvailable {
            recognizers[id] = newRec
            return newRec
        }
        
        if let sysRec = SFSpeechRecognizer(locale: Locale.current), sysRec.isAvailable {
            recognizers[Locale.current.identifier] = sysRec
            return sysRec
        }
        
        if let fallback = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), fallback.isAvailable {
            recognizers["en-US"] = fallback
            return fallback
        }
        
        for supported in SFSpeechRecognizer.supportedLocales() {
            if let anyRec = SFSpeechRecognizer(locale: supported), anyRec.isAvailable {
                recognizers[supported.identifier] = anyRec
                return anyRec
            }
        }
        
        return nil
    }
    
    public func requestSpeechAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    // MARK: - Live Real-Time Buffer Recognition
    
    public func startLiveRecognition(locale: Locale? = nil, onPartialResult: @escaping @Sendable (String) -> Void) throws {
        _ = stopLiveRecognition()
        
        guard let recognizer = getRecognizer(for: locale), recognizer.isAvailable else {
            throw NSError(
                domain: "LeapWispr.STT",
                code: 101,
                userInfo: [NSLocalizedDescriptionKey: "Apple Speech Recognizer is not available on this system."]
            )
        }
        
        liveLock.lock()
        latestLiveText = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        self.liveRequest = request
        liveLock.unlock()
        
        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                self.liveLock.lock()
                self.latestLiveText = text
                self.liveLock.unlock()
                onPartialResult(text)
            }
            if let error = error {
                print("[LeapWispr STT] Live recognition task notice/error: \(error.localizedDescription)")
            }
        }
        
        liveLock.lock()
        self.liveTask = task
        liveLock.unlock()
    }
    
    public func appendLiveAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        liveLock.lock()
        let req = self.liveRequest
        liveLock.unlock()
        req?.append(buffer)
    }
    
    public func stopLiveRecognition() -> String {
        liveLock.lock()
        defer { liveLock.unlock() }
        
        liveRequest?.endAudio()
        let final = latestLiveText
        liveTask?.cancel()
        liveTask = nil
        liveRequest = nil
        return final
    }
    
    // MARK: - Audio File Recognition Fallback
    
    public func transcribe(audioURL: URL) async throws -> String {
        return try await transcribe(audioURL: audioURL, locale: nil)
    }
    
    public func transcribe(audioURL: URL, locale: Locale? = nil) async throws -> String {
        guard let recognizer = getRecognizer(for: locale), recognizer.isAvailable else {
            throw NSError(
                domain: "LeapWispr.STT",
                code: 101,
                userInfo: [NSLocalizedDescriptionKey: "Apple Speech Recognizer is not available on this system."]
            )
        }
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = false
        request.shouldReportPartialResults = true
        
        return try await withCheckedThrowingContinuation { continuation in
            var hasFinished = false
            var latestTranscription = ""
            
            recognizer.recognitionTask(with: request) { result, error in
                if let result = result {
                    latestTranscription = result.bestTranscription.formattedString
                    if result.isFinal {
                        if !hasFinished {
                            hasFinished = true
                            continuation.resume(returning: latestTranscription)
                        }
                        return
                    }
                }
                
                if let error = error {
                    if !hasFinished {
                        hasFinished = true
                        if !latestTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            continuation.resume(returning: latestTranscription)
                        } else {
                            continuation.resume(throwing: error)
                        }
                    }
                    return
                }
            }
        }
    }
}
