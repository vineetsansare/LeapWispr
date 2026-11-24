import SwiftUI
import AppKit

public enum HUDStatus: Equatable {
    case idle
    case listening
    case processing(String)
    case success(String)
    case error(String)
}

public struct FloatingPillView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var audioManager = AudioEngineManager.shared
    @ObservedObject var pillState = FloatingPillState.shared
    
    public var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            
            // 1. Native Liquid Glass Tone Selection Menu
            if pillState.isTonePickerOpen {
                LiquidGlassToneMenuView()
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.94, anchor: .bottom).combined(with: .opacity),
                            removal: .scale(scale: 0.94, anchor: .bottom).combined(with: .opacity)
                        )
                    )
            }
            
            // 2. Live Streaming Transcript Overlay Floating Directly Above the Pill
            if !pillState.liveTranscript.isEmpty && pillState.status == .listening && !pillState.isTonePickerOpen {
                LiveTranscriptBubble(transcript: pillState.liveTranscript)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.92, anchor: .bottom).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
            
            // 3. Sleek Compact Control Pill Bar
            ControlPillBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: pillState.isTonePickerOpen)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: pillState.liveTranscript.isEmpty)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: pillState.status)
    }
}

// MARK: - Live Transcript Bubble Floating Above the Pill

public struct LiveTranscriptBubble: View {
    let transcript: String
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text(attributedTranscript)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            
            BlinkingCaretView()
                .padding(.bottom, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: 440, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.60), location: 0.0),
                                    .init(color: Color.white.opacity(0.20), location: 0.35),
                                    .init(color: Color.white.opacity(0.06), location: 0.70),
                                    .init(color: Color.white.opacity(0.18), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                )
                .shadow(color: Color.black.opacity(0.26), radius: 22, x: 0, y: 10)
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
        )
    }
    
    /// Renders previous words in normalized soft-white, and the latest incoming word in vibrant cyan bold
    private var attributedTranscript: AttributedString {
        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return AttributedString("") }
        
        let words = clean.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !words.isEmpty else { return AttributedString("") }
        
        if words.count == 1 {
            var str = AttributedString(words[0])
            str.foregroundColor = Color.cyan
            str.font = Font.system(size: 13, weight: .bold, design: .rounded)
            return str
        }
        
        // Normalized previous words
        let previousWords = words.dropLast().joined(separator: " ") + " "
        var prevStr = AttributedString(previousWords)
        prevStr.foregroundColor = Color.white.opacity(0.85)
        prevStr.font = Font.system(size: 13, weight: .medium, design: .rounded)
        
        // Highlighted latest active word in electric cyan
        let latestWord = words.last!
        var lastStr = AttributedString(latestWord)
        lastStr.foregroundColor = Color.cyan
        lastStr.font = Font.system(size: 13, weight: .bold, design: .rounded)
        
        prevStr.append(lastStr)
        return prevStr
    }
}

// MARK: - Control Pill Bar

public struct ControlPillBar: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var audioManager = AudioEngineManager.shared
    @ObservedObject var pillState = FloatingPillState.shared
    
    public var body: some View {
        HStack(spacing: 12) {
            // Status Icon / Waveform
            statusIconView
            
            // Middle Content: Waveform & Status
            switch pillState.status {
            case .listening:
                WaveformBarsView(level: audioManager.audioLevel)
                    .frame(width: 44, height: 16)
                
                // Done Button with Apple Gradient
                Button(action: { pillState.onStopRequested?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9.5, weight: .black))
                        Text("Done")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.15, green: 0.55, blue: 1.0), Color(red: 0.0, green: 0.40, blue: 0.95)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.blue.opacity(0.35), radius: 6, x: 0, y: 2)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.7)
                            )
                    )
                }
                .buttonStyle(.plain)
                .help("Stop dictating and insert text")
                
            case .processing(let message):
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.65)
                        .frame(width: 14, height: 14)
                    Text(message)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
            case .success(let message):
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 13))
                    Text(message)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
            case .error(let error):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                
            case .idle:
                Text("Ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Divider()
                .frame(height: 16)
                .opacity(0.35)
            
            // Interactive Liquid Glass Tone Selector Button
            Button(action: {
                pillState.toggleTonePicker()
            }) {
                HStack(spacing: 5) {
                    Text(toneButtonEmoji)
                        .font(.system(size: 11.5))
                    
                    Text(toneButtonLabel)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    
                    Image(systemName: pillState.isTonePickerOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(pillState.isTonePickerOpen ? Color.blue : Color.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(pillState.isTonePickerOpen ? Color.blue.opacity(0.18) : Color.primary.opacity(0.06))
                        .overlay(
                            Capsule()
                                .strokeBorder(pillState.isTonePickerOpen ? Color.blue.opacity(0.4) : Color.white.opacity(0.18), lineWidth: 0.8)
                        )
                )
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("Click to choose transformation tone")
            
            // Close / Dismiss Pill Button
            Button(action: { pillState.onCancelRequested?() }) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.07))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
                        )
                    Image(systemName: "xmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Color.secondary)
                }
            }
            .buttonStyle(.plain)
            .help(pillState.status == .listening ? "Cancel dictation and close pill" : "Close pill and dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.65), location: 0.0),
                                    .init(color: Color.white.opacity(0.25), location: 0.30),
                                    .init(color: Color.white.opacity(0.06), location: 0.65),
                                    .init(color: Color.white.opacity(0.22), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                )
                .shadow(color: Color.black.opacity(0.24), radius: 20, x: 0, y: 10)
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private var statusIconView: some View {
        switch pillState.status {
        case .listening:
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.4), lineWidth: 3)
                        .scaleEffect(1.0 + CGFloat(audioManager.audioLevel) * 0.8)
                        .opacity(Double(1.0 - audioManager.audioLevel * 0.5))
                )
                .animation(.easeInOut(duration: 0.2), value: audioManager.audioLevel)
            
        case .processing:
            Circle()
                .fill(Color.purple)
                .frame(width: 8, height: 8)
            
        case .success:
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            
        case .error:
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
            
        case .idle:
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)
        }
    }
    
    private var toneButtonEmoji: String {
        if pillState.currentTone == .autoContext {
            return "🪄"
        }
        return pillState.currentTone.emoji
    }
    
    private var toneButtonLabel: String {
        if pillState.currentTone == .autoContext {
            return "Auto (\(pillState.detectedAppTone.displayName))"
        } else if pillState.currentTone == .translate {
            return "Translate → \(settings.targetLanguage.rawValue)"
        } else {
            return pillState.currentTone.displayName
        }
    }
}

// MARK: - Native Liquid Glass Tone Selection Menu

public struct LiquidGlassToneMenuView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var pillState = FloatingPillState.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                    Text("TRANSFORMATION TONE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    pillState.toggleTonePicker()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Close tone menu")
            }
            .padding(.horizontal, 12)
            .padding(.top, 9)
            .padding(.bottom, 2)
            
            // Tone Options
            VStack(spacing: 2) {
                ForEach(ToneType.allCases) { tone in
                    ToneMenuRow(
                        tone: tone,
                        isSelected: pillState.currentTone == tone,
                        detectedAppName: pillState.detectedAppTone.displayName,
                        targetLanguage: settings.targetLanguage.rawValue
                    ) {
                        pillState.selectTone(tone)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 330)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.65), location: 0.0),
                                    .init(color: Color.white.opacity(0.25), location: 0.35),
                                    .init(color: Color.white.opacity(0.08), location: 0.70),
                                    .init(color: Color.white.opacity(0.22), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                )
                .shadow(color: Color.black.opacity(0.32), radius: 24, x: 0, y: 12)
                .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 2)
        )
    }
}

public struct ToneMenuRow: View {
    let tone: ToneType
    let isSelected: Bool
    let detectedAppName: String
    let targetLanguage: String
    let onSelect: () -> Void
    @State private var isHovered = false
    
    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Text(tone.emoji)
                    .font(.system(size: 13))
                    .frame(width: 20, alignment: .center)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(rowTitle)
                            .font(.system(size: 11.5, weight: isSelected ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(isSelected ? Color.blue : Color.primary)
                        
                        if tone == .autoContext {
                            Text("Active: \(detectedAppName)")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(Color.blue)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.blue.opacity(0.12)))
                        }
                    }
                    
                    Text(tone.summaryDescription)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.blue)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.12) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    private var rowTitle: String {
        if tone == .translate {
            return "Translate → \(targetLanguage)"
        }
        return tone.displayName
    }
}

// MARK: - Animated Caret

public struct BlinkingCaretView: View {
    @State private var isVisible = true
    
    public init() {}
    
    public var body: some View {
        Rectangle()
            .fill(Color.cyan)
            .frame(width: 2, height: 14)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: isVisible)
            .onAppear {
                isVisible = false
            }
    }
}

// MARK: - Waveform Bars

public struct WaveformBarsView: View {
    let level: Float
    
    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4.0
        let maxHeight: CGFloat = 16.0
        
        let multipliers: [Float] = [0.5, 0.9, 1.0, 0.8, 0.4]
        let currentMultiplier = multipliers[index]
        
        let dynamicHeight = baseHeight + CGFloat(level * currentMultiplier) * (maxHeight - baseHeight)
        return min(max(dynamicHeight, baseHeight), maxHeight)
    }
}
