import SwiftUI
import AppKit
import Speech
import AVFoundation

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    
    @State private var hasMicPermission = false
    @State private var hasAccessibilityPermission = false
    @State private var hasSpeechPermission = false
    
    @State private var showGeminiKey = false
    @State private var showGroqKey = false
    
    public var body: some View {
        TabView {
            // General Settings Tab
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            // AI & Models Tab
            aiModelsTab
                .tabItem {
                    Label("AI Models", systemImage: "sparkles")
                }
            
            // Permissions Tab
            permissionsTab
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
        }
        .frame(width: 480, height: 420)
        .padding(20)
        .onAppear {
            checkPermissions()
        }
    }
    
    private var generalTab: some View {
        Form {
            Section("Trigger Shortcut") {
                Picker("Activation Hotkey", selection: $settings.hotkeyMode) {
                    ForEach(HotkeyMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Text("Double-tap or hold the fn key to dictate from any app on your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Behavior") {
                Toggle("Auto-adapt tone to active application", isOn: $settings.autoContextTone)
                Toggle("Audio feedback chime on start/stop", isOn: $settings.soundFeedback)
            }
        }
        .formStyle(.grouped)
    }
    
    private var aiModelsTab: some View {
        Form {
            Section("Speech Recognition (STT)") {
                Picker("Engine", selection: $settings.sttEngine) {
                    ForEach(STTEngineType.allCases) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                
                Text("Apple Speech runs 100% on-device using Apple Silicon Neural Engine without sending audio over the internet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("LLM Tone Transformation (Gemini Flash)") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Google Gemini API Key:")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        if !settings.geminiApiKey.isEmpty {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.green)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        if showGeminiKey {
                            TextField("Paste your Gemini API Key here", text: $settings.geminiApiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Paste your Gemini API Key here", text: $settings.geminiApiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button(action: { showGeminiKey.toggle() }) {
                            Image(systemName: showGeminiKey ? "eye.slash" : "eye")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(showGeminiKey ? "Hide API key" : "Show API key")
                        
                        Button(action: {
                            if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !clip.isEmpty {
                                settings.geminiApiKey = clip
                            }
                        }) {
                            Label("Paste", systemImage: "doc.on.clipboard")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        if !settings.geminiApiKey.isEmpty {
                            Button(action: { settings.geminiApiKey = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Clear API Key")
                        }
                    }
                    
                    Text("Free tier allows 1,500 requests/day. If empty, local heuristic formatting will be used.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Link("Get a Free Gemini API Key →", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                        .font(.caption)
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Groq API Key (Optional for Cloud Whisper):")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        if !settings.groqApiKey.isEmpty {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.green)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        if showGroqKey {
                            TextField("Paste Groq API Key here", text: $settings.groqApiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Paste Groq API Key here", text: $settings.groqApiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button(action: { showGroqKey.toggle() }) {
                            Image(systemName: showGroqKey ? "eye.slash" : "eye")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !clip.isEmpty {
                                settings.groqApiKey = clip
                            }
                        }) {
                            Label("Paste", systemImage: "doc.on.clipboard")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        if !settings.groqApiKey.isEmpty {
                            Button(action: { settings.groqApiKey = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Clear API Key")
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
    
    private var permissionsTab: some View {
        Form {
            Section("System Permissions Required") {
                // Microphone
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(hasMicPermission ? .green : .red)
                        .frame(width: 24)
                    VStack(alignment: .leading) {
                        Text("Microphone")
                            .font(.system(size: 13, weight: .medium))
                        Text("Required to capture voice audio.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !hasMicPermission {
                        Button("Authorize") {
                            openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
                        }
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)
                
                // Accessibility
                HStack {
                    Image(systemName: "hand.tap.fill")
                        .foregroundStyle(hasAccessibilityPermission ? .green : .red)
                        .frame(width: 24)
                    VStack(alignment: .leading) {
                        Text("Accessibility")
                            .font(.system(size: 13, weight: .medium))
                        Text("Required to detect active app and inject text.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !hasAccessibilityPermission {
                        Button("Authorize") {
                            TextInjector.requestAccessibilityPermission()
                            openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                        }
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)
                
                // Speech Recognition
                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(hasSpeechPermission ? .green : .red)
                        .frame(width: 24)
                    VStack(alignment: .leading) {
                        Text("Speech Recognition")
                            .font(.system(size: 13, weight: .medium))
                        Text("Required for Apple Speech on-device STT.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !hasSpeechPermission {
                        Button("Authorize") {
                            SFSpeechRecognizer.requestAuthorization { _ in
                                DispatchQueue.main.async { checkPermissions() }
                            }
                        }
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
    
    private func checkPermissions() {
        hasAccessibilityPermission = TextInjector.isAccessibilityTrusted()
        
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        hasSpeechPermission = (speechStatus == .authorized)
        
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        hasMicPermission = (audioStatus == .authorized)
    }
    
    private func openSystemSettings(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
