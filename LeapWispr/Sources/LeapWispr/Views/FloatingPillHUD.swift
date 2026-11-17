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
    
    private var currentStatus: HUDStatus = .idle
    private var currentTone: ToneType = .professional
    
    public var onToneCycleRequested: (() -> Void)?
    public var onCancelRequested: (() -> Void)?
    public var onStopRequested: (() -> Void)?
    
    private init() {
        setupPanel()
    }
    
    private func setupPanel() {
        let panel = NonKeyFloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 50))
        self.window = panel
        updateContent()
    }
    
    public func show(status: HUDStatus, tone: ToneType) {
        dismissTimer?.invalidate()
        self.currentStatus = status
        self.currentTone = tone
        
        updateContent()
        positionHUD()
        
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
        self.currentStatus = status
        self.currentTone = tone
        updateContent()
    }
    
    public func hide() {
        dismissTimer?.invalidate()
        guard let panel = window, panel.isVisible else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
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
    }
    
    private func updateContent() {
        guard let panel = window else { return }
        let view = FloatingPillView(
            status: currentStatus,
            currentTone: currentTone,
            onToneTap: { [weak self] in
                self?.onToneCycleRequested?()
            },
            onCancelTap: { [weak self] in
                self?.onCancelRequested?()
            },
            onStopTap: { [weak self] in
                self?.onStopRequested?()
            }
        )
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = panel.contentRect(forFrameRect: panel.frame)
        panel.contentView = hostingView
    }
    
    private func positionHUD() {
        guard let panel = window else { return }
        guard let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let pillWidth: CGFloat = 340
        let pillHeight: CGFloat = 52
        
        // Center bottom position, 80pt above dock/bottom
        let x = screenRect.origin.x + (screenRect.width - pillWidth) / 2
        let y = screenRect.origin.y + 80
        
        panel.setFrame(NSRect(x: x, y: y, width: pillWidth, height: pillHeight), display: true)
    }
}
