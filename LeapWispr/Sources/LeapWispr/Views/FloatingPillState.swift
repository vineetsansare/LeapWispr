import Foundation
import SwiftUI
import Combine

@MainActor
public final class FloatingPillState: ObservableObject {
    public static let shared = FloatingPillState()
    
    @Published public var status: HUDStatus = .idle
    @Published public var currentTone: ToneType = .professional
    @Published public var liveTranscript: String = ""
    
    public var onToneCycleRequested: (() -> Void)?
    public var onToneSelected: ((ToneType) -> Void)?
    public var onCancelRequested: (() -> Void)?
    public var onStopRequested: (() -> Void)?
    
    private init() {}
    
    public func reset() {
        self.status = .idle
        self.liveTranscript = ""
    }
}
