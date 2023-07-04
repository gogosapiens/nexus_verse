import Foundation

public protocol WebSocketDelegate: AnyObject {
    func webSocketDidConnect(_ webSocket: WebSocket)
    func webSocketDidDisconnect(_ webSocket: WebSocket)
    func webSocket(_ webSocket: WebSocket, didRecieve message: WebSocket.Message)
}

public class WebSocket: NSObject {
    
    public typealias Message = URLSessionWebSocketTask.Message
    
    private var url: URL
    private var pingMessage: Message?
    public weak var delegate: WebSocketDelegate?
    
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var connectCompletion: ((Error?) -> Void)?
    private var responseTimer: Timer?
    
    private (set) static var log = ""
    private func addLog(strings: String...) {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .long
        let time = dateFormatter.string(from: Date())
        Self.log += "\n" + ([time] + strings).joined(separator: " ")
    }
    
    public init(url: URL, pingMessage: Message? = nil, delegate: WebSocketDelegate?) {
        self.url = url
        self.pingMessage = pingMessage
        self.delegate = delegate
    }
    
    private var isConnecting: Bool = false
    public var isConnected: Bool = false
    
    public func connect(completion: ((Error?) -> Void)?) {
        guard !isConnecting, !isConnected else {
            return
        }
        isConnecting = true
        connectCompletion = completion
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        let request = URLRequest(url: url, timeoutInterval: 5)
        self.task = session?.webSocketTask(with: request)
        self.task?.resume()
    }
    
    public func disconnect() {
        guard session != nil else {
            return
        }
        session?.invalidateAndCancel()
        session = nil
        task = nil
        isConnected = false
        isConnecting = false
        stopPinging()
        delegate?.webSocketDidDisconnect(self)
    }
    
    public func send(_ message: URLSessionWebSocketTask.Message, completion: ((Error?) -> Void)?  = nil) {
        guard let task else { return }
        let startDate = Date()
        task.send(message) { [weak self] error in
            guard let self else {
                return
            }
            if let error {
                print("Send message error", error)
                self.addLog(strings: "Send message error. Took \(-startDate.timeIntervalSinceNow) Error: \(error.localizedDescription) Message: \(message.string)")
                self.disconnect()
            } else {
                print("Message sent",  message.string.flattened().truncated())
                self.addLog(strings: "Message sent. Took: \(-startDate.timeIntervalSinceNow) Message: \(message.string)")
            }
        }
    }
    
    private func recieveMessage() {
        guard let task else { return }
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                print("Message recieved", message.string.flattened().truncated())
                self.addLog(strings: "Message recieved", message.string)
                self.delegate?.webSocket(self, didRecieve: message)
                self.recieveMessage()
                self.responseTimer?.invalidate()
                self.responseTimer = nil
            case .failure(let error):
                print("Recieve message error", error)
                self.addLog(strings: "Recieve message error", error.localizedDescription)
                self.disconnect()
            }
        }
    }
    
    private func startPinging() {
        if let pingMessage {
            pingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }
                self.send(pingMessage)
            }
        }
    }
    
    private func stopPinging() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
}

extension WebSocket: URLSessionWebSocketDelegate {
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("Websocket connected to", url.absoluteString)
        addLog(strings: "Connected", url.absoluteString)
        isConnecting = false
        isConnected = true
        connectCompletion?(nil)
        connectCompletion = nil
        recieveMessage()
        startPinging()
        delegate?.webSocketDidConnect(self)
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Websocket disconnected from", url.absoluteString)
        addLog(strings: "Disonnected", url.absoluteString)
        disconnect()
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            isConnecting = false
            connectCompletion?(error)
            connectCompletion = nil
        }
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let authMethod = challenge.protectionSpace.authenticationMethod
        
        guard challenge.previousFailureCount < 1, authMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
