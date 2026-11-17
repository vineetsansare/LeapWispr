import Foundation
import Speech

public final class AppleSpeechSTTProvider: @unchecked Sendable, STTProvider {
    public let name = "Apple Speech (On-Device)"
    
    private let speechRecognizer: SFSpeechRecognizer?
    
    public init(locale: Locale = Locale.current) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    public func requestSpeechAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    public func transcribe(audioURL: URL) async throws -> String {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
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
                            // Completed recognition before error (e.g. EOF or socket shutdown)
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
