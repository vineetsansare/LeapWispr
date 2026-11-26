import SwiftUI

public struct MenuBarPopoverView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var audioManager = AudioEngineManager.shared
    
    var onToggleDictation: () -> Void
    var onOpenSettings: () -> Void
    var onOpenHistory: () -> Void
    var onQuit: () -> Void
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Quick Action Hero Button
                    actionHeroButton
                    
                    // Tone Selector Grid
                    toneSection
                    
                    // Babel Translation Language Selector
                    if settings.selectedTone == .translate {
                        translationLanguageSection
                    }
                    
                    // Context Auto-Tone Pill
                    autoContextToggle
                    
                    // Productivity Stats Card
                    statsCard
                    
                    // iPhone Wireless Remote Card
                    phoneRemoteCard
                    
                    // Recent Dictations
                    if !settings.history.isEmpty {
                        recentSection
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 460)
            
            Divider()
            
            // Footer
            footerView
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("LeapWispr")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("Native Voice AI • \(settings.hotkeyMode.displayName)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                // Audio device switcher
                Menu {
                    Button(action: {
                        settings.audioInputMode = .preferContinuity
                        audioManager.updateActiveDeviceName()
                    }) {
                        HStack {
                            Text("📱 iPhone Continuity Mic (Auto-detect)")
                            if settings.audioInputMode == .preferContinuity {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button(action: {
                        settings.audioInputMode = .systemDefault
                        audioManager.updateActiveDeviceName()
                    }) {
                        HStack {
                            Text("💻 MacBook / System Default")
                            if settings.audioInputMode == .systemDefault {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(settings.audioInputMode == .preferContinuity ? "📱" : "💻")
                        Text(audioManager.activeInputDeviceName)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 7))
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.blue)
                }
                .menuStyle(.borderlessButton)
            }
            
            Spacer()
            
            // Mic status badge
            if audioManager.isRecording {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.12))
                .cornerRadius(4)
            }
        }
        .padding(14)
    }
    
    private var actionHeroButton: some View {
        Button(action: onToggleDictation) {
            HStack(spacing: 10) {
                Image(systemName: audioManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(audioManager.isRecording ? "Stop Dictation" : "Start Dictating")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text(audioManager.isRecording ? "Click to process & inject" : "or press \(settings.hotkeyMode.displayName)")
                        .font(.system(size: 10))
                        .opacity(0.8)
                }
                Spacer()
            }
            .padding(12)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(audioManager.isRecording ? Color.red : Color.accentColor)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRANSFORMATION TONE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(ToneType.allCases) { tone in
                    Button(action: {
                        settings.selectedTone = tone
                        settings.autoContextTone = (tone == .autoContext)
                    }) {
                        HStack(spacing: 6) {
                            Text(tone.emoji)
                                .font(.system(size: 12))
                            Text(tone.displayName)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .lineLimit(1)
                            Spacer()
                            if settings.selectedTone == tone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(settings.selectedTone == tone ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var translationLanguageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BABEL TRANSLATION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("🌍 Active")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            
            HStack(spacing: 8) {
                // Spoken Language Picker
                Menu {
                    ForEach(SpokenLanguage.allCases) { lang in
                        Button(action: { settings.spokenLanguage = lang }) {
                            HStack {
                                Text(lang.displayName)
                                if settings.spokenLanguage == lang {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(settings.spokenLanguage.shortName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                }
                .menuStyle(.borderlessButton)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                
                // Target Language Picker
                Menu {
                    ForEach(TargetLanguage.allCases) { lang in
                        Button(action: { settings.targetLanguage = lang }) {
                            HStack {
                                Text(lang.displayName)
                                if settings.targetLanguage == lang {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(settings.targetLanguage.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var autoContextToggle: some View {
        Toggle(isOn: Binding(
            get: { settings.selectedTone == .autoContext || settings.autoContextTone },
            set: { enabled in
                settings.autoContextTone = enabled
                if enabled {
                    settings.selectedTone = .autoContext
                } else if settings.selectedTone == .autoContext {
                    settings.selectedTone = .professional
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Smart Context Adaptation")
                    .font(.system(size: 12, weight: .semibold))
                Text("Slack → Casual, Mail → Professional, Dev tools → Code Prompt")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    private var statsCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(settings.totalWordsSpoken)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Words Dictated")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Divider().frame(height: 28)
            VStack(alignment: .leading, spacing: 2) {
                let savedMinutes = Double(settings.totalWordsSpoken) / 130.0 * 2.5
                Text(String(format: "%.1f min", savedMinutes))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.green)
                Text("Typing Time Saved")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
    }
    
    private var phoneRemoteCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("iPhone Wireless Remote")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Text("http://\(RemoteServer.shared.localIPAddress):4545")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                let urlString = "http://\(RemoteServer.shared.localIPAddress):4545"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(urlString, forType: .string)
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9.5))
                    Text("Copy")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help("Copy URL to open in Safari on iPhone")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RECENT DICTATIONS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("View All", action: onOpenHistory)
                    .font(.system(size: 10))
            }
            
            ForEach(settings.history.prefix(2)) { record in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(record.tone.emoji)
                            .font(.system(size: 11))
                        Text(record.appName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(record.timestamp, style: .time)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    Text(record.transformedText)
                        .font(.system(size: 11))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.03))
                )
            }
        }
    }
    
    private var footerView: some View {
        HStack {
            Button(action: onOpenSettings) {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: onQuit) {
                Text("Quit")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
