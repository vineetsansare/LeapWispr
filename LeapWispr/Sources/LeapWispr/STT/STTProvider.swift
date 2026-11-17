import Foundation

public protocol STTProvider: Sendable {
    var name: String { get }
    func transcribe(audioURL: URL) async throws -> String
}
