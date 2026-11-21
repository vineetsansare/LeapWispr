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
            
            // 1. Live Streaming Transcript Overlay Floating Directly Above the Pill
            if !pillState.liveTranscript.isEmpty && pillState.status == .listening {
                LiveTranscriptBubble(transcript: pillState.liveTranscript)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.92, anchor: .bottom).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
            
            // 2. Sleek Compact Control Pill Bar
            ControlPillBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
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
                FloatingPillHUD.shared.presentToneMenu()
            }) {
                HStack(spacing: 5) {
                    Text(pillState.currentTone.emoji)
                        .font(.system(size: 11.5))
                    
                    if pillState.currentTone == .translate {
                        Text("Translate → \(settings.targetLanguage.rawValue)")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    } else {
                        Text(pillState.currentTone.displayName)
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
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
