import Foundation

public final class CloudGroqSTTProvider: Sendable, STTProvider {
    public let name = "Groq Whisper (Cloud)"
    private let apiKey: String
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func transcribe(audioURL: URL) async throws -> String {
        guard !apiKey.isEmpty else {
            throw NSError(
                domain: "LeapWispr.STT",
                code: 102,
                userInfo: [NSLocalizedDescriptionKey: "Groq API Key is missing. Please set it in Settings."]
            )
        }
        
        let endpoint = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let audioData = try Data(contentsOf: audioURL)
        var body = Data()
        
        // model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-large-v3\r\n".data(using: .utf8)!)
        
        // file parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // finish boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(domain: "LeapWispr.STT", code: 103, userInfo: [NSLocalizedDescriptionKey: "Groq error: \(errorText)"])
        }
        
        struct TranscriptionResponse: Codable {
            let text: String
        }
        
        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
