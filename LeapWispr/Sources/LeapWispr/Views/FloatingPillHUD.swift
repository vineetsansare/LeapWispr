import AppKit
import SwiftUI

/// Custom NSPanel that is strictly prohibited from ever becoming key or main window.
/// This prevents stealing focus away from target applications (Chromium, Electron, Xcode, etc.).
public final class NonKeyFloatingPanel: NSPanel {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
    
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.isFloatingPanel = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false // Shadow is rendered inside SwiftUI views
        self.isMovableByWindowBackground = true
        self.becomesKeyOnlyIfNeeded = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }
}

@MainActor
public final class FloatingPillHUD {
    public static let shared = FloatingPillHUD()
    
    private var window: NonKeyFloatingPanel?
    private var dismissTimer: Timer?
    
    public var onToneCycleRequested: (() -> Void)?
    public var onToneSelected: ((ToneType) -> Void)?
    public var onCancelRequested: (() -> Void)?
    public var onStopRequested: (() -> Void)?
    
    private let hudWidth: CGFloat = 480
    private var currentHeight: CGFloat = 54
    
    private init() {
        setupPanel()
    }
    
    private func setupPanel() {
        let panel = NonKeyFloatingPanel(contentRect: NSRect(x: 0, y: 0, width: hudWidth, height: 54))
        self.window = panel
        
        // Wire state callbacks
        FloatingPillState.shared.onToneCycleRequested = { [weak self] in
            self?.onToneCycleRequested?()
        }
        FloatingPillState.shared.onToneSelected = { [weak self] tone in
            self?.onToneSelected?(tone)
        }
        FloatingPillState.shared.onCancelRequested = { [weak self] in
            self?.onCancelRequested?()
        }
        FloatingPillState.shared.onStopRequested = { [weak self] in
            self?.onStopRequested?()
        }
        
        let hostingView = NSHostingView(rootView: FloatingPillView())
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: hudWidth, height: 54)
        panel.contentView = hostingView
    }
    
    public func show(status: HUDStatus, tone: ToneType) {
        dismissTimer?.invalidate()
        FloatingPillState.shared.status = status
        FloatingPillState.shared.currentTone = tone
        FloatingPillState.shared.liveTranscript = ""
        
        currentHeight = 54
        positionHUD(height: 54)
        
        guard let panel = window else { return }
        if !panel.isVisible {
            panel.alphaValue = 0.0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = 1.0
            }
        }
        
        switch status {
        case .error, .success:
            dismissTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.hide()
                }
            }
        default:
            break
        }
    }
    
    public func update(status: HUDStatus, tone: ToneType) {
        dismissTimer?.invalidate()
        FloatingPillState.shared.status = status
        FloatingPillState.shared.currentTone = tone
        
        switch status {
        case .error, .success:
            dismissTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.hide()
                }
            }
        default:
            break
        }
    }
    
    /// Streams live transcript to the overlay above the pill and expands window height upwards
    public func updateLiveTranscript(_ text: String) {
        FloatingPillState.shared.liveTranscript = text
        
        let targetHeight: CGFloat
        if text.isEmpty {
            targetHeight = 54
        } else if text.count <= 60 {
            targetHeight = 106
        } else if text.count <= 130 {
            targetHeight = 138
        } else {
            targetHeight = 176
        }
        
        adjustHUDHeight(targetHeight: targetHeight)
    }
    
    public func hide() {
        dismissTimer?.invalidate()
        guard let panel = window, panel.isVisible else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
            DispatchQueue.main.async {
                FloatingPillState.shared.reset()
                self.currentHeight = 54
                self.positionHUD(height: 54)
            }
        })
    }
    
    /// Synchronously dismisses the HUD window without any animation delay.
    public func hideImmediately() {
        dismissTimer?.invalidate()
        guard let panel = window else { return }
        panel.alphaValue = 0.0
        panel.orderOut(nil)
        FloatingPillState.shared.reset()
        currentHeight = 54
        positionHUD(height: 54)
    }
    
    private func adjustHUDHeight(targetHeight: CGFloat) {
        guard let panel = window, let screen = NSScreen.main else { return }
        guard abs(currentHeight - targetHeight) > 3 else { return }
        
        currentHeight = targetHeight
        let screenRect = screen.visibleFrame
        let x = screenRect.origin.x + (screenRect.width - hudWidth) / 2
        let y = screenRect.origin.y + 80 // Base y remains stationary, height grows upwards!
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(NSRect(x: x, y: y, width: hudWidth, height: targetHeight), display: true)
        }
    }
    
    private func positionHUD(height: CGFloat = 54) {
        guard let panel = window, let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let x = screenRect.origin.x + (screenRect.width - hudWidth) / 2
        let y = screenRect.origin.y + 80
        
        panel.setFrame(NSRect(x: x, y: y, width: hudWidth, height: height), display: true)
    }
}
