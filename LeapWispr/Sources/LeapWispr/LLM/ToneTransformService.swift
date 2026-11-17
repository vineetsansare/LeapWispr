import Foundation

public final class ToneTransformService: Sendable {
    public static let shared = ToneTransformService()
    
    private init() {}
    
    public func transform(
        rawTranscript: String,
        tone: ToneType,
        appContext: ActiveAppContext,
        apiKey: String
    ) async throws -> String {
        let cleanInput = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanInput.isEmpty else { return "" }
        
        // If tone is raw, return quick cleanup without LLM
        if tone == .raw {
            return basicCleanup(cleanInput)
        }
        
        // If an API key is provided, call Gemini Flash API
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                return try await callGeminiFlash(rawText: cleanInput, tone: tone, appContext: appContext, apiKey: apiKey)
            } catch {
                print("[LeapWispr] Gemini API call error: \(error). Falling back to offline transformer.")
            }
        }
        
        // Offline / No API Key fallback: high quality local heuristic cleanup
        return offlineTransform(rawText: cleanInput, tone: tone, appContext: appContext)
    }
    
    private func callGeminiFlash(
        rawText: String,
        tone: ToneType,
        appContext: ActiveAppContext,
        apiKey: String
    ) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "LeapWispr.LLM", code: 201, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini URL."])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let promptText = """
        System Instruction:
        \(tone.systemPrompt)
        
        Target Application Context:
        User is typing in: \(appContext.appName) (\(appContext.bundleId)). Format text specifically for this context.
        
        Spoken Transcript:
        \"\"\"
        \(rawText)
        \"\"\"
        
        Output ONLY the final polished text without quotes or explanation:
        """
        
        let jsonPayload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": promptText]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 1024
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonPayload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP status error"
            throw NSError(domain: "LeapWispr.LLM", code: 202, userInfo: [NSLocalizedDescriptionKey: "Gemini error: \(errorText)"])
        }
        
        // Parse Gemini Response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let text = firstPart["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        throw NSError(domain: "LeapWispr.LLM", code: 203, userInfo: [NSLocalizedDescriptionKey: "Malformed Gemini response."])
    }
    
    // Robust offline transformation fallback
    public func offlineTransform(rawText: String, tone: ToneType, appContext: ActiveAppContext) -> String {
        var cleaned = basicCleanup(rawText)
        
        switch tone {
        case .professional:
            if !cleaned.hasSuffix(".") && !cleaned.hasSuffix("!") && !cleaned.hasSuffix("?") {
                cleaned += "."
            }
            return cleaned
            
        case .casual:
            return cleaned
            
        case .excited:
            if cleaned.hasSuffix(".") {
                cleaned.removeLast()
            }
            if !cleaned.hasSuffix("!") {
                cleaned += "!"
            }
            return cleaned
            
        case .devPrompt:
            // Detect code patterns and wrap with backticks
            return cleaned
            
        case .bulletPoints:
            let sentences = cleaned.components(separatedBy: CharacterSet(charactersIn: ".?!"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            if sentences.count > 1 {
                return sentences.map { "- \($0)" }.joined(separator: "\n")
            } else {
                return "- \(cleaned)"
            }
            
        case .raw:
            return cleaned
        }
    }
    
    private func basicCleanup(_ text: String) -> String {
        var result = text
        
        // Remove common speech fillers
        let fillers = [
            "\\b(um|uh|er|ah)\\b",
            "\\b(you know|i mean|like)\\b",
            "\\b(basically|sort of|kind of)\\b"
        ]
        
        for pattern in fillers {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(location: 0, length: result.utf16.count),
                    withTemplate: ""
                )
            }
        }
        
        // Normalize multiple spaces
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Capitalize first character
        if let first = result.first {
            result = String(first).uppercased() + String(result.dropFirst())
        }
        
        return result
    }
}
