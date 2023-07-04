import Foundation

public enum Action {
    
    static let typePrefix: String = ""
    static let appPrefix = Self.typePrefix + "app-"
    static let commandPrefix = Self.typePrefix + "command-"
    static let textPrefix = Self.typePrefix + "text-"
    static let urlScheme = "action://"
    
    case openApp(FriendlyApp)
    case sendCommand(Command)
    case sendText(String)
    
    var url: URL {
        return .init(string: "action://\(type)")!
    }
    
    init?(url: URL) {
        guard url.absoluteString.hasPrefix(Self.urlScheme) else {
            return nil
        }
        let type = url.absoluteString.replacingOccurrences(of: Self.urlScheme, with: "")
        self.init(type: type)
    }
    
    var type: String {
        switch self {
        case .openApp(let friendlyApp):
            return Self.typePrefix + "app-\(friendlyApp.rawValue)"
        case .sendCommand(let command):
            return Self.typePrefix + "command-\(command.rawValue)"
        case .sendText(let string):
            return Self.typePrefix + "text-\(string)"
        }
    }
    
    init?(type: String) {
        if type.hasPrefix(Self.appPrefix) {
            let rawValue = type.replacingOccurrences(of: Self.appPrefix, with: "")
            if let friendlyApp = FriendlyApp(rawValue: rawValue) {
                self = .openApp(friendlyApp)
                return
            }
        } else if type.hasPrefix(Self.commandPrefix) {
            let rawValue = type.replacingOccurrences(of: Self.commandPrefix, with: "")
            if let command = Command(rawValue: rawValue) {
                self = .sendCommand(command)
                return
            }
        } else if type.hasPrefix(Self.textPrefix) {
            let text = type.replacingOccurrences(of: Self.textPrefix, with: "")
            self = .sendText(text)
            return
        }
        return nil
    }
}
