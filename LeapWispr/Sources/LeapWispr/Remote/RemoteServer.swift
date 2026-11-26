import Foundation
import Network
import AppKit
import Darwin

public final class RemoteServer: @unchecked Sendable {
    public static let shared = RemoteServer()
    
    private var listener: NWListener?
    public let port: UInt16 = 4545
    
    public var localIPAddress: String {
        var address: String = "localhost"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return address }
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(ptr.pointee.ifa_addr, socklen_t(ptr.pointee.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: hostname)
                        if !ip.starts(with: "127.") {
                            address = ip
                            break
                        }
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }
    
    private init() {}
    
    public func start() {
        guard listener == nil else { return }
        
        do {
            let parameters = NWParameters.tcp
            let nwPort = NWEndpoint.Port(rawValue: port)!
            let newListener = try NWListener(using: parameters, on: nwPort)
            
            newListener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            newListener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("[LeapWispr Remote] Server listening on port 4545")
                case .failed(let error):
                    print("[LeapWispr Remote] Server failed: \(error)")
                default:
                    break
                }
            }
            
            newListener.start(queue: .global())
            self.listener = newListener
        } catch {
            print("[LeapWispr Remote] Failed to start NWListener: \(error)")
        }
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            guard let self = self, let data = data, error == nil else {
                connection.cancel()
                return
            }
            
            let requestString = String(decoding: data, as: UTF8.self)
            self.processRequest(requestString: requestString, connection: connection)
        }
    }
    
    private func processRequest(requestString: String, connection: NWConnection) {
        let firstLine = requestString.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            connection.cancel()
            return
        }
        
        let path = parts[1]
        
        if path == "/" {
            let html = self.generateiPhoneHTML()
            self.sendResponse(connection: connection, contentType: "text/html", body: html)
        } else if path.starts(with: "/api/toggle") {
            Task { @MainActor in
                DictationCoordinator.shared.toggleDictation()
                let isRec = AudioEngineManager.shared.isRecording
                let json = "{\"status\":\"ok\",\"recording\":\(isRec)}"
                self.sendResponse(connection: connection, contentType: "application/json", body: json)
            }
        } else if path.starts(with: "/api/tone") {
            Task { @MainActor in
                if let urlComponents = URLComponents(string: path),
                   let queryItem = urlComponents.queryItems?.first(where: { $0.name == "type" }),
                   let toneVal = queryItem.value,
                   let tone = ToneType(rawValue: toneVal) {
                    AppSettings.shared.selectedTone = tone
                    FloatingPillState.shared.currentTone = tone
                    FloatingPillHUD.shared.onToneSelected?(tone)
                }
                let currentTone = AppSettings.shared.selectedTone.rawValue
                let json = "{\"status\":\"ok\",\"tone\":\"\(currentTone)\"}"
                self.sendResponse(connection: connection, contentType: "application/json", body: json)
            }
        } else if path == "/api/status" {
            Task { @MainActor in
                let isRecording = AudioEngineManager.shared.isRecording
                let tone = AppSettings.shared.selectedTone.rawValue
                let words = AppSettings.shared.totalWordsSpoken
                let json = "{\"recording\":\(isRecording),\"tone\":\"\(tone)\",\"words\":\(words)}"
                self.sendResponse(connection: connection, contentType: "application/json", body: json)
            }
        } else {
            self.sendResponse(connection: connection, statusCode: 404, contentType: "text/plain", body: "Not found")
        }
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int = 200, contentType: String, body: String) {
        let data = body.data(using: .utf8) ?? Data()
        let headers = """
        HTTP/1.1 \(statusCode) OK\r
        Content-Type: \(contentType); charset=utf-8\r
        Content-Length: \(data.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r
        
        """
        var responseData = headers.data(using: .utf8) ?? Data()
        responseData.append(data)
        
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func generateiPhoneHTML() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
            <title>LeapWispr Remote</title>
            <meta name="apple-mobile-web-app-capable" content="yes">
            <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
            <style>
                * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
                body {
                    margin: 0; padding: env(safe-area-inset-top, 24px) 16px env(safe-area-inset-bottom, 24px);
                    background: #000; color: #fff; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
                    display: flex; flex-direction: column; height: 100vh; justify-content: space-between; text-align: center;
                }
                .header { margin-top: 10px; }
                .logo { font-size: 22px; font-weight: 700; letter-spacing: -0.5px; }
                .status-badge {
                    display: inline-flex; align-items: center; gap: 6px; padding: 6px 14px;
                    border-radius: 20px; background: rgba(255,255,255,0.1); font-size: 13px; margin-top: 10px;
                }
                .dot { width: 8px; height: 8px; border-radius: 50%; background: #34C759; }
                .dot.live { background: #FF3B30; animation: pulse 1s infinite; }
                @keyframes pulse { 0% { transform: scale(1); opacity: 1; } 50% { transform: scale(1.4); opacity: 0.5; } 100% { transform: scale(1); opacity: 1; } }
                
                .tones { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; margin: 24px 0; }
                .tone-btn {
                    padding: 9px 15px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.15);
                    background: rgba(255,255,255,0.06); color: #fff; font-size: 13px; font-weight: 500; cursor: pointer;
                    transition: all 0.2s;
                }
                .tone-btn.active { background: #007AFF; border-color: #007AFF; font-weight: 600; }
                
                .mic-container { margin: auto 0; }
                .mic-button {
                    width: 140px; height: 140px; border-radius: 50%; border: none;
                    background: linear-gradient(135deg, #007AFF, #5856D6); color: #fff;
                    font-size: 54px; display: flex; align-items: center; justify-content: center;
                    margin: 0 auto; box-shadow: 0 10px 35px rgba(0,122,255,0.4); cursor: pointer;
                    transition: transform 0.15s, background 0.3s;
                }
                .mic-button.recording {
                    background: linear-gradient(135deg, #FF3B30, #FF9500);
                    box-shadow: 0 10px 45px rgba(255,59,48,0.6);
                    transform: scale(1.08);
                }
                .mic-label { margin-top: 20px; font-size: 16px; font-weight: 600; color: rgba(255,255,255,0.8); }
                .footer { font-size: 12px; color: rgba(255,255,255,0.4); margin-bottom: 10px; }
            </style>
        </head>
        <body>
            <div class="header">
                <div class="logo">🎙️ LeapWispr Remote</div>
                <div class="status-badge">
                    <div class="dot" id="statusDot"></div>
                    <span id="statusText">Connected to Mac</span>
                </div>
                
                <div class="tones">
                    <button class="tone-btn" data-tone="auto_context" onclick="setTone('auto_context', this)">🪄 Auto</button>
                    <button class="tone-btn" data-tone="professional" onclick="setTone('professional', this)">💼 Professional</button>
                    <button class="tone-btn" data-tone="casual" onclick="setTone('casual', this)">💬 Casual</button>
                    <button class="tone-btn" data-tone="translate" onclick="setTone('translate', this)">🌍 Translate</button>
                    <button class="tone-btn" data-tone="dev_prompt" onclick="setTone('dev_prompt', this)">💻 Dev</button>
                    <button class="tone-btn" data-tone="bullet_points" onclick="setTone('bullet_points', this)">📝 Bullets</button>
                    <button class="tone-btn" data-tone="excited" onclick="setTone('excited', this)">🚀 Excited</button>
                    <button class="tone-btn" data-tone="raw" onclick="setTone('raw', this)">🎙️ Raw</button>
                </div>
            </div>

            <div class="mic-container">
                <button class="mic-button" id="micBtn" onclick="toggleMic()">🎙️</button>
                <div class="mic-label" id="micLabel">Tap to Speak into Mac</div>
            </div>

            <div class="footer">
                iPhone • Wireless Remote Controller • Clamshell Ready
            </div>

            <script>
                let isRecording = false;
                let activeTone = '';
                
                function toggleMic() {
                    if (navigator.vibrate) navigator.vibrate(60);
                    fetch('/api/toggle')
                        .then(r => r.json())
                        .then(data => updateState(data.recording));
                }

                function setTone(tone, btn) {
                    if (navigator.vibrate) navigator.vibrate(35);
                    activeTone = tone;
                    document.querySelectorAll('.tone-btn').forEach(b => b.classList.remove('active'));
                    if (btn) btn.classList.add('active');
                    fetch('/api/tone?type=' + tone);
                }

                function updateState(recording, tone) {
                    isRecording = recording;
                    const btn = document.getElementById('micBtn');
                    const label = document.getElementById('micLabel');
                    const dot = document.getElementById('statusDot');
                    const statusText = document.getElementById('statusText');
                    
                    if (isRecording) {
                        btn.classList.add('recording');
                        btn.innerHTML = '⏹️';
                        label.innerText = 'Listening... Tap to Stop & Inject';
                        dot.classList.add('live');
                        statusText.innerText = 'Dictating to Mac';
                    } else {
                        btn.classList.remove('recording');
                        btn.innerHTML = '🎙️';
                        label.innerText = 'Tap to Speak into Mac';
                        dot.classList.remove('live');
                        statusText.innerText = 'Connected to Mac';
                    }
                    
                    if (tone && tone !== activeTone) {
                        activeTone = tone;
                        document.querySelectorAll('.tone-btn').forEach(b => {
                            if (b.dataset.tone === tone) b.classList.add('active');
                            else b.classList.remove('active');
                        });
                    }
                }

                setInterval(() => {
                    fetch('/api/status')
                        .then(r => r.json())
                        .then(data => {
                            updateState(data.recording, data.tone);
                        }).catch(() => {});
                }, 800);
            </script>
        </body>
        </html>
        """
    }
}
