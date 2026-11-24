import AppKit
import SwiftUI
import AVFoundation
import Speech

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    
    private var settingsWindowController: NSWindowController?
    private var historyWindowController: NSWindowController?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent app from quitting when all windows are closed (runs as menu bar agent)
        NSApp.setActivationPolicy(.accessory)
        
        setupMainMenu()
        setupStatusItem()
        setupPopover()
        setupHotkeys()
        
        // Start local remote server for iPhone 14 Pro Max wireless control
        RemoteServer.shared.start()
        
        // Initial setup prompt
        checkInitialPermissions()
    }
    
    /// Configures standard macOS Edit menu (Cut, Copy, Paste, Select All)
    /// This is strictly required on macOS so accessory/LSUIElement apps can
    /// process Cmd+V, Cmd+C, Cmd+A inside TextFields and SecureFields.
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About LeapWispr", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Preferences...", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit LeapWispr", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc private func openSettingsFromMenu() {
        openSettingsWindow()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "LeapWispr")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    private func setupPopover() {
        let popoverView = MenuBarPopoverView(
            onToggleDictation: { [weak self] in
                self?.popover.performClose(nil)
                DictationCoordinator.shared.toggleDictation()
            },
            onOpenSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.openSettingsWindow()
            },
            onOpenHistory: { [weak self] in
                self?.popover.performClose(nil)
                self?.openHistoryWindow()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        
        let p = NSPopover()
        p.contentSize = NSSize(width: 320, height: 460)
        p.behavior = .transient
        p.contentViewController = NSHostingController(rootView: popoverView)
        self.popover = p
    }
    
    private func setupHotkeys() {
        let hotkey = HotkeyManager.shared
        
        hotkey.onTrigger = {
            DictationCoordinator.shared.toggleDictation()
        }
        
        hotkey.onHoldStart = {
            DictationCoordinator.shared.startDictation()
        }
        
        hotkey.onHoldEnd = {
            DictationCoordinator.shared.stopAndProcessDictation()
        }
        
        hotkey.startMonitoring()
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    public func openSettingsWindow() {
        if let existing = settingsWindowController?.window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "LeapWispr Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        
        let wc = NSWindowController(window: window)
        self.settingsWindowController = wc
        wc.showWindow(nil)
        NSApp.activate()
    }
    
    public func openHistoryWindow() {
        if let existing = historyWindowController?.window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 460),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Dictation History"
        window.contentView = NSHostingView(rootView: HistoryView())
        window.isReleasedWhenClosed = false
        
        let wc = NSWindowController(window: window)
        self.historyWindowController = wc
        wc.showWindow(nil)
        NSApp.activate()
    }
    
    private func checkInitialPermissions() {
        if !TextInjector.isAccessibilityTrusted() {
            // Prompt accessibility on first launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                TextInjector.requestAccessibilityPermission()
            }
        }
        
        // Ensure Microphone permission is requested
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("[LeapWispr Permissions] Microphone access granted: \(granted)")
            }
        }
        
        // Ensure Speech Recognition permission is requested
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { status in
                print("[LeapWispr Permissions] Speech recognition auth status: \(status.rawValue)")
            }
        }
    }
}
