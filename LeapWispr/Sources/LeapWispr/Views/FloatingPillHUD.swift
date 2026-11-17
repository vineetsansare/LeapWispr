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
        self.hasShadow = true
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
    public var onCancelRequested: (() -> Void)?
    public var onStopRequested: (() -> Void)?
    
    private init() {
        setupPanel()
    }
    
    private func setupPanel() {
        let initialWidth: CGFloat = 340
        let panel = NonKeyFloatingPanel(contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: 52))
        self.window = panel
        
        // Wire state callbacks
        FloatingPillState.shared.onToneCycleRequested = { [weak self] in
            self?.onToneCycleRequested?()
        }
        FloatingPillState.shared.onCancelRequested = { [weak self] in
            self?.onCancelRequested?()
        }
        FloatingPillState.shared.onStopRequested = { [weak self] in
            self?.onStopRequested?()
        }
        
        let hostingView = NSHostingView(rootView: FloatingPillView())
        hostingView.frame = panel.contentRect(forFrameRect: panel.frame)
        panel.contentView = hostingView
    }
    
    public func show(status: HUDStatus, tone: ToneType) {
        dismissTimer?.invalidate()
        FloatingPillState.shared.status = status
        FloatingPillState.shared.currentTone = tone
        FloatingPillState.shared.liveTranscript = ""
        
        positionHUD(width: 340)
        
        guard let panel = window else { return }
        if !panel.isVisible {
            panel.alphaValue = 0.0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = 1.0
            }
        }
    }
    
    public func update(status: HUDStatus, tone: ToneType) {
        FloatingPillState.shared.status = status
        FloatingPillState.shared.currentTone = tone
        if case .processing = status {
            adjustHUDWidth(targetWidth: 360)
        }
    }
    
    /// Streams live transcript directly to the floating pill and smoothly adapts width
    public func updateLiveTranscript(_ text: String) {
        FloatingPillState.shared.liveTranscript = text
        let desiredWidth: CGFloat = text.isEmpty ? 340 : 480
        adjustHUDWidth(targetWidth: desiredWidth)
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
            }
        })
    }
    
    /// Synchronously dismisses the HUD window without any animation delay.
    /// This immediately releases WindowServer focus back to the target application
    /// before synthetic keystrokes or text injections are dispatched.
    public func hideImmediately() {
        dismissTimer?.invalidate()
        guard let panel = window else { return }
        panel.alphaValue = 0.0
        panel.orderOut(nil)
        FloatingPillState.shared.reset()
        positionHUD(width: 340)
    }
    
    private func adjustHUDWidth(targetWidth: CGFloat) {
        guard let panel = window, let screen = NSScreen.main else { return }
        guard abs(panel.frame.width - targetWidth) > 5 else { return }
        
        let screenRect = screen.visibleFrame
        let pillHeight: CGFloat = 52
        let x = screenRect.origin.x + (screenRect.width - targetWidth) / 2
        let y = screenRect.origin.y + 80
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(NSRect(x: x, y: y, width: targetWidth, height: pillHeight), display: true)
        }
    }
    
    private func positionHUD(width: CGFloat = 340) {
        guard let panel = window, let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let pillHeight: CGFloat = 52
        let x = screenRect.origin.x + (screenRect.width - width) / 2
        let y = screenRect.origin.y + 80
        
        panel.setFrame(NSRect(x: x, y: y, width: width, height: pillHeight), display: true)
    }
}
