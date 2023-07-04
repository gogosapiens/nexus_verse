import Foundation

public protocol RemoteDelegate: AnyObject {
    func remote(_ remote: Remote, didUpdateStatus status: RemoteStatus)
    func remoteDidRequestAuthorizarion(_ remote: Remote)
    func remoteDidCompleteAuthorizarion(_ remote: Remote)
    func remoteDidFailAuthorizarion(_ remote: Remote, withMessage message: String)
    func remoteDidRequestPinInput(_ remote: Remote)
    func remote(_ remote: Remote, didUpdateApps apps: [App])
    func remote(_ remote: Remote, didUpdateChannels channels: [Channel])
}

public enum RemoteStatus {
    case connecting, connected, disconnected, failed
}

public protocol Remote: AnyObject {
    var delegate: RemoteDelegate? { get set }
    var id: String { get }
    var host: String { get }
    var logs: String { get set }
    
    func connect(shouldWake: Bool, completion: ((Error?) -> Void)?)
    func disconnect()
    var status: RemoteStatus { get }
    var isAuthorized: Bool { get }
    
    func canSend(_ command: Command) -> Bool
    func sendCommandClick(_ command: Command)
    func sendCommandPress(_ command: Command)
    func sendCommandRelease(_ command: Command)
    
    var apps: [App] { get }
    func openApp(_ app: App)
    
    var channels: [Channel] { get }
    func openChannel(_ channel: Channel)
    
    var inputs: [Input] { get }
    func openInput(_ input: Input)
    
    func sendText(_ text: String)
    var canSendText: Bool { get }
    
    func clickPointer()
    func resetTouchLocations()
    
    var canMovePointer: Bool { get }
    func movePointer(to location: CGPoint, withVelocity: CGPoint)
    
    var canScroll: Bool { get }
    func scroll(to location: CGPoint, withVelocity velocity: CGPoint)
    
    var canOpenURLs: Bool { get }
    func openURL(_ url: URL)
    
    func setPin(_ pin: String)
    
    init(host: String)
}

public extension Remote {
    
    var channels: [Channel] { [] }
    func openChannel(_ channel: Channel) {}
    
    func clickPointer() {
        sendCommandClick(.ok)
    }
    func resetTouchLocations() {}
    
    var canMovePointer: Bool { false }
    func movePointer(to location: CGPoint, withVelocity: CGPoint) {}
    
    var canScroll: Bool { false }
    func scroll(to location: CGPoint, withVelocity velocity: CGPoint) {}
    
    var canOpenURLs: Bool { false }
    func openURL(_ url: URL) {}
    
    func setPin(_ pin: String) {}
    
    var token: String? {
        get {
            DeviceBrowser.tokens[id]
        }
        set {
            DeviceBrowser.tokens[id] = newValue
        }
    }
    
    var macAddresses: Set<String> {
        get {
            DeviceBrowser.macAddresses[host] ?? []
        }
        set {
            DeviceBrowser.macAddresses[host] = newValue
        }
    }
    
    func wake() {
        for mac in macAddresses {
            let _ = WakeOnLAN.target(device: .init(mac: mac))
        }
    }
    
    func addLog(_ log: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        let time = dateFormatter.string(from: .init())
        logs += "\(time): \(log.replacingOccurrences(of: "\n", with: " "))\n"
    }
    
//    var name: String {
//        info["friendlyName"] ?? "Unnamed TV"
//    }
}
