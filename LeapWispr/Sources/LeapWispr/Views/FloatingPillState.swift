import Foundation
import SwiftUI
import Combine

@MainActor
public final class FloatingPillState: ObservableObject {
    public static let shared = FloatingPillState()
    
    @Published public var status: HUDStatus = .idle
    @Published public var currentTone: ToneType = .autoContext
    @Published public var detectedAppTone: ToneType = .professional
    @Published public var liveTranscript: String = ""
    @Published public var isTonePickerOpen: Bool = false
    
    public var onToneCycleRequested: (() -> Void)?
    public var onToneSelected: ((ToneType) -> Void)?
    public var onCancelRequested: (() -> Void)?
    public var onStopRequested: (() -> Void)?
    
    private init() {}
    
    public func reset() {
        self.status = .idle
        self.liveTranscript = ""
        self.isTonePickerOpen = false
    }
    
    public func toggleTonePicker() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            self.isTonePickerOpen.toggle()
        }
        FloatingPillHUD.shared.updateHeightForCurrentState()
    }
    
    public func selectTone(_ tone: ToneType) {
        self.currentTone = tone
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            self.isTonePickerOpen = false
        }
        FloatingPillHUD.shared.updateHeightForCurrentState()
        self.onToneSelected?(tone)
    }
}
