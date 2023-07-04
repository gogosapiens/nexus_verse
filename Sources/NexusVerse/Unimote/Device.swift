import Foundation
import SwiftyXMLParser

public class Device {
    
    public typealias UpdateHandler = (Device, SSDPInfo) -> Bool
    
    public static var updateHandler: UpdateHandler?
    
    public struct SSDPInfo: Codable, Equatable {
        public let port: Int
        public let data: Data
        
        public static var empty = SSDPInfo(port: 0, data: .init())
    }
    
    public struct Connection: Codable {
        public let host: String
        public let ssdpInfo: SSDPInfo
    }
    
    public var host: String
    public var name: String
    public var model: String?
    public var manufacturer: String?
    
    public var caster: Caster?
    public var remote: Remote?
    
    init(host: String, ssdpInfo: SSDPInfo) throws {
        self.host = host
        self.name = ""
        self.ssdpInfo = .empty
        if let handler = Self.updateHandler {
            let success = handler(self, ssdpInfo)
            if !success {
                throw InfoError.noInfo
            }
        }
    }
    
    public convenience init(connection: Connection) throws {
        try self.init(host: connection.host, ssdpInfo: connection.ssdpInfo)
    }
    
    public var connection: Connection {
        return .init(host: host, ssdpInfo: ssdpInfo)
    }
    
    public var ssdpInfo: SSDPInfo
    
    public enum InfoError: Error {
        case wrongDeviceType
        case noName
        case noControlURL
        case noInfo
    }
    
    public var analyticsAttributes: [String: Any] {
        var attributes = [String: Any]()
        let values = XML.parse(ssdpInfo.data)["root", "device"].keysAndTexts
        values.forEach { key, value in
            let key = "SSDP" + key
            attributes[key] = value
        }
        DeviceBrowser.shared.locationData.forEach { location, data in
            guard let host = location.host, host == self.host else { return }
            let values = XML.parse(data)["root", "device"].keysAndTexts
            values.forEach { key, value in
                let key = "OtherSSDP" + key
                let current = attributes[key] as? [String] ?? []
                if !current.contains(value) {
                    attributes[key] = current + [value]
                }
            }
        }
        attributes.forEach { key, value in
            if key.hasPrefix("OtherSSDP"), let values = value as? [String], values.count == 1 {
                attributes[key] = nil
            }
        }
        attributes["Name"] = self.name
        attributes["Model"] = self.model ?? "Unknown"
        attributes["Manufacturer"] = self.manufacturer ?? "Unknown"
        
        attributes["HasRemote"] = self.remote != nil
        attributes["HasCaster"] = self.caster != nil
        
        if let remote {
            attributes["RemoteType"] = String(describing: type(of: remote))
        }
        
        return attributes
    }
}
