import Foundation
import AppKit

@MainActor
public final class HotkeyManager: ObservableObject {
    public static let shared = HotkeyManager()
    
    public var onTrigger: (() -> Void)?
    public var onHoldStart: (() -> Void)?
    public var onHoldEnd: (() -> Void)?
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    private var lastModifierPressTime: Date = Date.distantPast
    private let doubleTapThreshold: TimeInterval = 0.40
    private var isModifierDown = false
    
    // Minimum interval between triggers to prevent accidental rapid double-toggles
    private var lastTriggerTime: Date = Date.distantPast
    private let debounceInterval: TimeInterval = 0.75
    
    private init() {}
    
    public func startMonitoring() {
        stopMonitoring()
        
        // Global monitor for keyboard events across all applications
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // Local monitor when our app UI is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }
    
    public func stopMonitoring() {
        if let g = globalMonitor {
            NSEvent.removeMonitor(g)
            globalMonitor = nil
        }
        if let l = localMonitor {
            NSEvent.removeMonitor(l)
            localMonitor = nil
        }
    }
    
    private func fireTrigger() {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) > debounceInterval else {
            return
        }
        lastTriggerTime = now
        DispatchQueue.main.async {
            self.onTrigger?()
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Universal Shortcut 1: Option + Space
        if event.type == .keyDown && event.keyCode == 49 && event.modifierFlags.contains(.option) {
            guard !event.isARepeat else { return }
            fireTrigger()
            return
        }
        
        // Universal Shortcut 2: Cmd + Shift + D
        if event.type == .keyDown && event.keyCode == 2 && event.modifierFlags.contains([.command, .shift]) {
            guard !event.isARepeat else { return }
            fireTrigger()
            return
        }
        
        // Double-Tap Modifier Monitoring (fn, Option, or Control)
        if event.type == .flagsChanged {
            let isFn = event.keyCode == 63 || event.modifierFlags.contains(.function)
            let isOption = event.modifierFlags.contains(.option)
            let isControl = event.modifierFlags.contains(.control)
            
            let isTargetModifier = isFn || isOption || isControl
            
            if isTargetModifier && !isModifierDown {
                isModifierDown = true
                let now = Date()
                if now.timeIntervalSince(lastModifierPressTime) <= doubleTapThreshold {
                    // Double-tap detected!
                    fireTrigger()
                    lastModifierPressTime = Date.distantPast
                } else {
                    lastModifierPressTime = now
                }
            } else if !isTargetModifier {
                isModifierDown = false
            }
        }
    }
}
