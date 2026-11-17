import Foundation

public struct DictationRecord: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let rawText: String
    public let transformedText: String
    public let tone: ToneType
    public let appName: String
    public let bundleId: String
    public let duration: TimeInterval
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        rawText: String,
        transformedText: String,
        tone: ToneType,
        appName: String,
        bundleId: String,
        duration: TimeInterval
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rawText = rawText
        self.transformedText = transformedText
        self.tone = tone
        self.appName = appName
        self.bundleId = bundleId
        self.duration = duration
    }
}
