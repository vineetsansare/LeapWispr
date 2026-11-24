import Foundation

public final class ToneTransformService: Sendable {
    public static let shared = ToneTransformService()
    
    private init() {}
    
    public func transform(
        rawTranscript: String,
        tone: ToneType,
        appContext: ActiveAppContext,
        apiKey: String,
        spokenLanguage: SpokenLanguage = .auto,
        targetLanguage: TargetLanguage = .english
    ) async throws -> String {
        let cleanInput = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanInput.isEmpty else { return "" }
        
        // If tone is raw, return quick cleanup without LLM
        if tone == .raw {
            return basicCleanup(cleanInput)
        }
        
        let targetTone = (tone == .autoContext) ? appContext.suggestedTone : tone
        
        // If an API key is provided, call Gemini Flash API
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                return try await callGeminiFlash(
                    rawText: cleanInput,
                    tone: targetTone,
                    appContext: appContext,
                    apiKey: apiKey,
                    spokenLanguage: spokenLanguage,
                    targetLanguage: targetLanguage
                )
            } catch {
                print("[LeapWispr] Gemini API call error: \(error). Falling back to offline transformer.")
            }
        }
        
        // Offline / No API Key fallback: high quality local heuristic cleanup
        return offlineTransform(rawText: cleanInput, tone: targetTone, appContext: appContext)
    }
    
    private func callGeminiFlash(
        rawText: String,
        tone: ToneType,
        appContext: ActiveAppContext,
        apiKey: String,
        spokenLanguage: SpokenLanguage = .auto,
        targetLanguage: TargetLanguage = .english
    ) async throws -> String {
        var systemInstruction = tone.systemPrompt
        if tone == .translate {
            let target = targetLanguage.displayName
            let spoken = spokenLanguage.displayName
            systemInstruction = """
            You are an expert multilingual translator and writing assistant.
            The user is speaking in: \(spoken) (or conversational/code-switched speech like Hinglish).
            Translate the spoken words directly and fluently into: \(target).
            
            Key Rules:
            - If the input is in \(spoken), produce a natural, fluent, and idiomatic translation in \(target).
            - If the input is already in \(target), refine its flow and clarity.
            - If the user uses a code-switched mix (e.g. Hinglish or Spanglish), translate the entire message smoothly into \(target).
            - Strip speech filler words (e.g. 'um', 'uh', 'matlab', 'yaani', 'tu sais').
            - Preserve intended nuances, technical vocabulary, and emotional tone.
            - Ensure natural punctuation and sentence structure suitable for \(appContext.appName).
            - Return ONLY the translated \(target) text with NO quotes, conversational preamble, or explanations.
            """
        }
        
        let promptText = """
        System Instruction:
        \(systemInstruction)
        
        Target Application Context:
        User is typing in: \(appContext.appName) (\(appContext.bundleId)). Format text specifically for this context.
        
        Spoken Transcript:
        \"\"\"
        \(rawText)
        \"\"\"
        
        Output strictly ONLY the final polished text without quotes or explanation:
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
                "temperature": 0.25,
                "maxOutputTokens": 1024
            ]
        ]
        
        let payloadData = try JSONSerialization.data(withJSONObject: jsonPayload)
        
        let candidateModels = [
            "gemini-3.5-flash-lite",
            "gemini-3.8-flash",
            "gemini-flash-latest"
        ]
        
        var lastError: Error?
        for model in candidateModels {
            let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
            guard let url = URL(string: urlString) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 4.0
            request.httpBody = payloadData
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { continue }
                
                if (200...299).contains(httpResponse.statusCode) {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]] {
                        let combined = parts.compactMap { $0["text"] as? String }.joined()
                        let clean = combined.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !clean.isEmpty {
                            print("[LeapWispr LLM] Transformed successfully using model: \(model)")
                            return clean
                        }
                    }
                } else {
                    let errStr = String(data: data, encoding: .utf8) ?? "status \(httpResponse.statusCode)"
                    print("[LeapWispr LLM] Model \(model) failed: \(errStr). Trying fallback...")
                }
            } catch {
                lastError = error
                print("[LeapWispr LLM] Request failed for \(model): \(error.localizedDescription). Trying next...")
            }
        }
        
        throw lastError ?? NSError(domain: "LeapWispr.LLM", code: 204, userInfo: [NSLocalizedDescriptionKey: "All Gemini model candidates failed."])
    }
    
    // Robust offline transformation fallback
    public func offlineTransform(rawText: String, tone: ToneType, appContext: ActiveAppContext) -> String {
        let actualTone = (tone == .autoContext) ? appContext.suggestedTone : tone
        var cleaned = basicCleanup(rawText)
        
        switch actualTone {
        case .autoContext:
            return offlineTransform(rawText: rawText, tone: appContext.suggestedTone, appContext: appContext)
            
        case .professional:
            let formalReplacements: [(String, String)] = [
                ("\\bhey guys\\b", "Hello everyone"),
                ("\\bwhat's up\\b", "how are you doing"),
                ("\\bwhats up\\b", "how are you doing"),
                ("\\bcan't\\b", "cannot"),
                ("\\bwon't\\b", "will not"),
                ("\\bdon't\\b", "do not"),
                ("\\bdidn't\\b", "did not"),
                ("\\bdoesn't\\b", "does not"),
                ("\\bi'm\\b", "I am"),
                ("\\bi'll\\b", "I will"),
                ("\\bi've\\b", "I have"),
                ("\\bwe're\\b", "we are"),
                ("\\bthey're\\b", "they are"),
                ("\\byou're\\b", "you are"),
                ("\\bgonna\\b", "going to"),
                ("\\bwanna\\b", "want to"),
                ("\\bgotta\\b", "need to"),
                ("\\bkinda\\b", "somewhat"),
                ("\\bpls\\b", "please"),
                ("\\bplz\\b", "please"),
                ("\\bthx\\b", "thank you"),
                ("\\basap\\b", "as soon as possible")
            ]
            for (pattern, replacement) in formalReplacements {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.utf16.count), withTemplate: replacement)
                }
            }
            if !cleaned.isEmpty {
                let first = cleaned.prefix(1).uppercased()
                cleaned = first + cleaned.dropFirst()
            }
            if !cleaned.hasSuffix(".") && !cleaned.hasSuffix("!") && !cleaned.hasSuffix("?") {
                cleaned += "."
            }
            return cleaned
            
        case .casual:
            let casualReplacements: [(String, String)] = [
                ("\\bdo not\\b", "don't"),
                ("\\bcannot\\b", "can't"),
                ("\\bwill not\\b", "won't"),
                ("\\bgoing to\\b", "gonna"),
                ("\\bwant to\\b", "wanna"),
                ("\\bwould like to\\b", "let's"),
                ("\\bcould you please\\b", "can you"),
                ("\\bin regard to\\b", "about")
            ]
            for (pattern, replacement) in casualReplacements {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.utf16.count), withTemplate: replacement)
                }
            }
            if !cleaned.isEmpty {
                let first = cleaned.prefix(1).uppercased()
                cleaned = first + cleaned.dropFirst()
            }
            return cleaned
            
        case .translate:
            return cleaned
            
        case .excited:
            cleaned = cleaned.replacingOccurrences(of: "\\.+$", with: "", options: .regularExpression)
            if !cleaned.hasSuffix("!") {
                cleaned += "!"
            }
            return cleaned
            
        case .devPrompt:
            let codeWords = ["function", "class", "const", "let", "var", "import", "export", "async", "await", "return", "api", "endpoint", "git", "commit", "push", "pull", "merge", "branch", "pr", "repo", "url", "json", "http", "id", "pid"]
            for word in codeWords {
                if let regex = try? NSRegularExpression(pattern: "\\b\(word)\\b", options: .caseInsensitive) {
                    cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.utf16.count), withTemplate: "`\(word)`")
                }
            }
            return cleaned
            
        case .bulletPoints:
            let sentences = cleaned.components(separatedBy: CharacterSet(charactersIn: ".?!"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            if sentences.count > 1 {
                return sentences.map { "- \($0.prefix(1).uppercased() + $0.dropFirst())" }.joined(separator: "\n")
            } else {
                return "- \(cleaned.prefix(1).uppercased() + cleaned.dropFirst())"
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
