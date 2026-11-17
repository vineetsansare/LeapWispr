import Foundation
import AppKit

public struct ActiveAppContext {
    public let appName: String
    public let bundleId: String
    public let suggestedTone: ToneType
    public let pid: pid_t
}

@MainActor
public final class ContextInspector {
    public static let shared = ContextInspector()
    
    /// Tracks the most recent non-LeapWispr application that had active user focus
    private var lastActiveExternalApp: NSRunningApplication?
    
    private init() {
        // Capture initial external frontmost application
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != ProcessInfo.processInfo.processIdentifier,
           front.activationPolicy == .regular {
            self.lastActiveExternalApp = front
        }
        
        // Listen to system-wide app activations to always know the user's active editor/app
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self else { return }
            if let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    let myPid = ProcessInfo.processInfo.processIdentifier
                    if app.processIdentifier != myPid && app.activationPolicy == .regular {
                        self.lastActiveExternalApp = app
                    }
                }
            }
        }
    }
    
    public func getCurrentAppContext() -> ActiveAppContext {
        let myPid = ProcessInfo.processInfo.processIdentifier
        let frontApp = NSWorkspace.shared.frontmostApplication
        
        var targetApp: NSRunningApplication?
        
        // If frontmost app is an external user app, use it directly
        if let front = frontApp, front.processIdentifier != myPid && front.activationPolicy == .regular {
            targetApp = front
            self.lastActiveExternalApp = front
        } else {
            // Otherwise use the tracked last active external app
            targetApp = self.lastActiveExternalApp
        }
        
        let appName = targetApp?.localizedName ?? "Antigravity"
        let bundleId = targetApp?.bundleIdentifier ?? "com.google.antigravity"
        let pid = targetApp?.processIdentifier ?? 0
        
        let suggestedTone = inferTone(fromBundleId: bundleId, appName: appName)
        
        return ActiveAppContext(
            appName: appName,
            bundleId: bundleId,
            suggestedTone: suggestedTone,
            pid: pid
        )
    }
    
    private func inferTone(fromBundleId bundleId: String, appName: String) -> ToneType {
        let b = bundleId.lowercased()
        let name = appName.lowercased()
        
        // Chat & Messaging -> Casual
        if b.contains("slack") || b.contains("discord") || b.contains("telegram") ||
           b.contains("whatsapp") || b.contains("messages") || b.contains("teams") ||
           name.contains("slack") || name.contains("chat") {
            return .casual
        }
        
        // Developer Tools -> Dev / Prompt
        if b.contains("vscode") || b.contains("cursor") || b.contains("xcode") ||
           b.contains("terminal") || b.contains("iterm") || b.contains("warp") ||
           b.contains("sublime") || b.contains("intellij") {
            return .devPrompt
        }
        
        // Email -> Professional
        if b.contains("mail") || b.contains("outlook") || b.contains("spark") ||
           b.contains("superhuman") || name.contains("mail") {
            return .professional
        }
        
        // Notes & Knowledge bases -> Bullet Points
        if b.contains("notes") || b.contains("notion") || b.contains("obsidian") ||
           b.contains("bear") || b.contains("craft") || b.contains("reminders") {
            return .bulletPoints
        }
        
        // Fallback default
        return .professional
    }
}
