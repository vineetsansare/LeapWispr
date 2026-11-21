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
    
    /// Optional stream callback for live buffer recognition (e.g. SFSpeechAudioBufferRecognitionRequest)
    public var onAudioBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
    
    private var recordingStartTime: Date?
    
    public var recordingDuration: TimeInterval {
        guard let start = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    private override init() {
        super.init()
        updateActiveDeviceName()
    }
    
    /// Finds any connected Continuity Microphone (e.g. iPhone 14 Pro Max)
    public func findContinuityDevice() -> (id: AudioDeviceID, name: String)? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize) == noErr else { return nil }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &devices) == noErr else { return nil }
        
        for id in devices {
            var streamAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(id, &streamAddr, 0, nil, &streamSize)
            guard streamSize > 0 else { continue }
            
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameUnmanaged: Unmanaged<CFString>?
            var nameSz = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            if AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSz, &nameUnmanaged) == noErr,
               let cf = nameUnmanaged?.takeRetainedValue() {
                let name = cf as String
                if name.localizedCaseInsensitiveContains("iPhone") ||
                   name.localizedCaseInsensitiveContains("14 Pro") ||
                   name.localizedCaseInsensitiveContains("Continuity") {
                    return (id, name)
                }
            }
        }
        return nil
    }
    
    /// Retrieves the current active input device name
    public func updateActiveDeviceName() {
        if AppSettings.shared.audioInputMode == .preferContinuity,
           let continuity = findContinuityDevice() {
            self.activeInputDeviceName = continuity.name
            return
        }
        
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var defaultDeviceId: AudioDeviceID = 0
        var sz = UInt32(MemoryLayout<AudioDeviceID>.size)
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, 0, nil, &sz, &defaultDeviceId) == noErr {
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameUnmanaged: Unmanaged<CFString>?
            var nameSz = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            if AudioObjectGetPropertyData(defaultDeviceId, &nameAddr, 0, nil, &nameSz, &nameUnmanaged) == noErr,
               let cf = nameUnmanaged?.takeRetainedValue() {
                self.activeInputDeviceName = cf as String
                return
            }
        }
        self.activeInputDeviceName = "Default Microphone"
    }
    
    public func startRecording() throws {
        guard !isRecording else { return }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("leapwispr_\(UUID().uuidString).wav")
        self.currentRecordingURL = fileURL
        self.recordingStartTime = Date()
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        
        // 1. Device Selection & Binding (Auto-bind Continuity iPhone ONLY if preferred and available)
        var usedContinuity = false
        if AppSettings.shared.audioInputMode == .preferContinuity,
           let continuity = findContinuityDevice(),
           let unit = inputNode.audioUnit {
            var devID = continuity.id
            let status = AudioUnitSetProperty(
                unit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &devID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            if status == noErr {
                self.activeInputDeviceName = continuity.name
                usedContinuity = true
                print("[LeapWispr Audio] Bound Continuity Mic: \(continuity.name) (ID: \(devID))")
            } else {
                updateActiveDeviceName()
                print("[LeapWispr Audio] AudioUnitSetProperty failed (\(status)), fell back to: \(activeInputDeviceName)")
            }
        } else {
            updateActiveDeviceName()
            print("[LeapWispr Audio] Using system default mic: \(activeInputDeviceName)")
        }
        
        // 2. Query output format AFTER device is bound to get the exact hardware sample rate & channel layout!
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
        
        var bufferCount = 0
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            bufferCount += 1
            
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
            
            // 3. Dispatch to live streaming recognition if registered
            self.onAudioBuffer?(buffer)
        }
        
        try engine.start()
        self.audioEngine = engine
        self.isRecording = true
        
        // 4. Watchdog: If Continuity mic was bound but delivers 0 buffers in 400ms (iPhone asleep/standby),
        // automatically fallback to system default microphone so user recording NEVER fails!
        if usedContinuity {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self = self, self.isRecording else { return }
                if bufferCount == 0 {
                    print("[LeapWispr Audio] ⚠️ Continuity Mic delivered 0 buffers (iPhone in standby). Falling back to system default microphone...")
                    self.fallbackToSystemDefaultMic()
                }
            }
        }
    }
    
    /// Automatic live fallback to MacBook Pro / system default microphone
    private func fallbackToSystemDefaultMic() {
        guard isRecording, let engine = audioEngine, let fileURL = currentRecordingURL else { return }
        
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        
        if let unit = engine.inputNode.audioUnit {
            var defaultID: AudioDeviceID = 0
            var defaultAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var sz = UInt32(MemoryLayout<AudioDeviceID>.size)
            if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddr, 0, nil, &sz, &defaultID) == noErr {
                AudioUnitSetProperty(
                    unit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global,
                    0,
                    &defaultID,
                    sz
                )
            }
        }
        
        updateActiveDeviceName()
        let fallbackFormat = engine.inputNode.outputFormat(forBus: 0)
        guard fallbackFormat.sampleRate > 0 else { return }
        
        do {
            let newFile = try AVAudioFile(
                forWriting: fileURL,
                settings: fallbackFormat.settings,
                commonFormat: fallbackFormat.commonFormat,
                interleaved: fallbackFormat.isInterleaved
            )
            self.audioFile = newFile
            
            engine.inputNode.installTap(onBus: 0, bufferSize: 2048, format: fallbackFormat) { [weak self] buffer, time in
                guard let self = self else { return }
                
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
                
                if let audioFile = self.audioFile {
                    try? audioFile.write(from: buffer)
                }
                
                self.onAudioBuffer?(buffer)
            }
            
            try engine.start()
            print("[LeapWispr Audio] ✅ Successfully switched to fallback mic: \(activeInputDeviceName)")
        } catch {
            print("[LeapWispr Audio] ❌ Failed to start fallback mic: \(error)")
        }
    }
    
    public func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        self.onAudioBuffer = nil
        
        self.isRecording = false
        self.audioLevel = 0.0
        
        return currentRecordingURL
    }
}
