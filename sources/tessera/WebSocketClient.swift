import Foundation

class WebSocketClient: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    var onEventReceived: ((HookEvent) -> Void)?
    var onConnectionStatusChanged: ((Bool) -> Void)?

    private let serverURL = "ws://localhost:4000/stream"

    func connect() {
        guard let url = URL(string: serverURL) else {
            print("Invalid WebSocket URL")
            return
        }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        print("🔌 Connecting to WebSocket server...")
        receiveMessage()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
        onConnectionStatusChanged?(false)
        print("🔌 Disconnected from WebSocket server")
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }

                // Continue receiving messages
                self?.receiveMessage()

            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self?.isConnected = false
                self?.onConnectionStatusChanged?(false)

                // Try to reconnect after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self?.connect()
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        do {
            let message = try JSONDecoder().decode(WebSocketMessage.self, from: data)

            switch message.data {
            case .single(let event):
                DispatchQueue.main.async {
                    self.onEventReceived?(event)
                }

            case .multiple(let events):
                DispatchQueue.main.async {
                    events.forEach { self.onEventReceived?($0) }
                }
            }
        } catch {
            print("Error decoding WebSocket message: \(error)")
        }
    }
}

extension WebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket connected")
        isConnected = true
        DispatchQueue.main.async {
            self.onConnectionStatusChanged?(true)
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("⚠️ WebSocket disconnected")
        isConnected = false
        DispatchQueue.main.async {
            self.onConnectionStatusChanged?(false)
        }
    }
}
