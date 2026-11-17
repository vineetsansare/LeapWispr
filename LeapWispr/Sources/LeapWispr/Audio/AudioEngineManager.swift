import Foundation
import AVFoundation
import CoreAudio
import Combine

@MainActor
public final class AudioEngineManager: NSObject, ObservableObject {
    public static let shared = AudioEngineManager()
    
    @Published public private(set) var isRecording = false
    @Published public private(set) var audioLevel: Float = 0.0
    @Published public private(set) var activeInputDeviceName: String = "Default Microphone"
    
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private(set) public var currentRecordingURL: URL?
    
    private var recordingStartTime: Date?
    
    public var recordingDuration: TimeInterval {
        guard let start = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    private override init() {
        super.init()
    }
    
    /// Finds any connected Continuity Microphone (e.g. iPhone 14 Pro Max) or external microphone
    private func findPreferredAudioDevice() -> (id: AudioDeviceID, name: String)? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize) == noErr else {
            return nil
        }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &devices) == noErr else {
            return nil
        }
        
        var continuityDevice: (AudioDeviceID, String)? = nil
        
        for id in devices {
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameUnmanaged: Unmanaged<CFString>?
            var sz = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            if AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &sz, &nameUnmanaged) == noErr,
               let cf = nameUnmanaged?.takeRetainedValue() {
                let name = cf as String
                
                // Check if device has audio input streams
                var streamAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyStreams,
                    mScope: kAudioDevicePropertyScopeInput,
                    mElement: kAudioObjectPropertyElementMain
                )
                var streamSize: UInt32 = 0
                AudioObjectGetPropertyDataSize(id, &streamAddr, 0, nil, &streamSize)
                if streamSize > 0 {
                    if name.localizedCaseInsensitiveContains("iPhone") ||
                       name.localizedCaseInsensitiveContains("14 Pro") ||
                       name.localizedCaseInsensitiveContains("Continuity") {
                        continuityDevice = (id, name)
                        break
                    }
                }
            }
        }
        
        return continuityDevice
    }
    
    public func startRecording() throws {
        guard !isRecording else { return }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("leapwispr_\(UUID().uuidString).wav")
        self.currentRecordingURL = fileURL
        self.recordingStartTime = Date()
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        
        // Auto-bind Continuity Microphone (iPhone) if present (especially essential in Clamshell mode)
        if let preferred = findPreferredAudioDevice(), let unit = inputNode.audioUnit {
            var devID = preferred.id
            let status = AudioUnitSetProperty(
                unit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &devID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            if status == noErr {
                self.activeInputDeviceName = preferred.name
                print("[LeapWispr Audio] Bound input to: \(preferred.name) (ID: \(preferred.id))")
            }
        }
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        guard inputFormat.sampleRate > 0 else {
            throw NSError(domain: "LeapWispr", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid microphone format."])
        }
        
        // Record in the native format directly to eliminate any conversion drops
        let file = try AVAudioFile(
            forWriting: fileURL,
            settings: inputFormat.settings,
            commonFormat: inputFormat.commonFormat,
            interleaved: inputFormat.isInterleaved
        )
        self.audioFile = file
        
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // 1. Compute lightweight audio power for UI meter
            if let channelData = buffer.floatChannelData?[0] {
                let frameCount = Int(buffer.frameLength)
                var sumSquares: Float = 0.0
                let step = max(1, frameCount / 64)
                var count = 0
                for i in stride(from: 0, to: frameCount, by: step) {
                    let sample = channelData[i]
                    sumSquares += sample * sample
                    count += 1
                }
                let rms = sqrt(sumSquares / Float(max(1, count)))
                let normalized = min(max(rms * 15.0, 0.0), 1.0)
                DispatchQueue.main.async {
                    self.audioLevel = normalized
                }
            }
            
            // 2. Write audio directly on the tap thread (guaranteed zero dropped packets)
            if let audioFile = self.audioFile {
                try? audioFile.write(from: buffer)
            }
        }
        
        try engine.start()
        self.audioEngine = engine
        self.isRecording = true
    }
    
    public func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        
        self.isRecording = false
        self.audioLevel = 0.0
        
        return currentRecordingURL
    }
}
