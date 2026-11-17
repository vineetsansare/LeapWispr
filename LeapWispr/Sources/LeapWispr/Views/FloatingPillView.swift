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
    
    let status: HUDStatus
    let currentTone: ToneType
    let onToneTap: () -> Void
    let onCancelTap: () -> Void
    let onStopTap: () -> Void
    
    public var body: some View {
        HStack(spacing: 12) {
            // Status Icon / Waveform
            statusIconView
            
            // Status or Live Waveform
            switch status {
            case .listening:
                WaveformBarsView(level: audioManager.audioLevel)
                    .frame(width: 48, height: 18)
                
                // Done & Insert Button right on the pill
                Button(action: onStopTap) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Done")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.blue)
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
                .opacity(0.5)
            
            // Interactive Tone Badge
            Button(action: onToneTap) {
                HStack(spacing: 5) {
                    Text(currentTone.emoji)
                        .font(.system(size: 12))
                    Text(currentTone.displayName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .help("Click to change tone")
            
            // Cancel Button
            if status == .listening {
                Button(action: onCancelTap) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel dictation")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.8)
                )
        )
    }
    
    @ViewBuilder
    private var statusIconView: some View {
        switch status {
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

// Animated 5-bar audio waveform
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
