import SwiftUI
import Speech
import AVFoundation

public enum iOSToneType: String, CaseIterable, Identifiable {
    case professional = "Professional"
    case casual = "Casual"
    case excited = "Excited"
    case devPrompt = "Dev / Prompt"
    case bulletPoints = "Bullet Points"
    
    public var id: String { rawValue }
    public var emoji: String {
        switch self {
        case .professional: return "💼"
        case .casual: return "💬"
        case .excited: return "🚀"
        case .devPrompt: return "💻"
        case .bulletPoints: return "📝"
        }
    }
}

public struct iOSContentView: View {
    @State private var isRecording = false
    @State private var transcribedText = ""
    @State private var transformedText = ""
    @State private var selectedTone: iOSToneType = .professional
    @State private var isConnectedToMac = true
    @State private var audioLevel: CGFloat = 0.0
    
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Mac Relay Connectivity Status
                    macConnectionBanner
                    
                    // Tone Selector Carousel
                    toneSelectorSection
                    
                    // Transcribed & Polished Preview Box
                    previewCard
                    
                    Spacer()
                    
                    // Large Tactile Record Button
                    recordButtonSection
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationTitle("LeapWispr")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }
    
    private var macConnectionBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isConnectedToMac ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            Text(isConnectedToMac ? "Connected to Mac (Remote Mic Ready)" : "Local Mode")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
    
    private var toneSelectorSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(iOSToneType.allCases) { tone in
                    Button(action: {
                        haptic.impactOccurred()
                        selectedTone = tone
                    }) {
                        HStack(spacing: 6) {
                            Text(tone.emoji)
                            Text(tone.rawValue)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedTone == tone ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground))
                        )
                        .foregroundStyle(selectedTone == tone ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LIVE RESULT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !transformedText.isEmpty {
                    Button(action: {
                        UIPasteboard.general.string = transformedText
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                }
            }
            
            if isRecording {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.8)
                    Text("Listening to your voice...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
            } else if !transformedText.isEmpty {
                Text(transformedText)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            } else {
                Text("Tap the mic below and start speaking naturally...")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
    
    private var recordButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                haptic.impactOccurred(intensity: 1.0)
                isRecording.toggle()
                if !isRecording {
                    transformedText = "Here is your cleanly transcribed and formatted text, ready to paste."
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.15))
                        .frame(width: 110, height: 110)
                        .scaleEffect(isRecording ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)
                    
                    Circle()
                        .fill(isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                        .shadow(color: (isRecording ? Color.red : Color.blue).opacity(0.4), radius: 10, y: 5)
                    
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            
            Text(isRecording ? "Tap to Stop & Format" : "Tap to Speak")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}
