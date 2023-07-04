import Foundation
import SwiftyXMLParser
import UIKit
import Network

public class DeviceBrowser {
    
    public static let shared = DeviceBrowser()
    private init() {
        self._devices = Self.savedConnections.compactMap { try? .init(connection: $0) }
    }
    
    public static let devicesUpdatedNotification = Notification.Name(rawValue: "DeviceBrowser.devicesUpdatedNotification")
    
    public static var startLocation: String {
        "intro"
    }
    
    @UserDefaultsValue(key: "saved_connections", defaultValue: [])
    static var savedConnections: [Device.Connection]
    
    @UserDefaultsValue(key: "last_connection", defaultValue: nil)
    static var _lastConnection: Device.Connection?
    public static var lastConnection: Device.Connection? { _lastConnection }
    
    @UserDefaultsValue(key: "remote_browser_tokens", defaultValue: [:])
    static var tokens: [String: String]
    
    @UserDefaultsValue(key: "remote_browser_mac_addresses", defaultValue: [:])
    static var macAddresses: [String: Set<String>]
    
    public var isBrowsing: Bool = false
    private var discovery: SSDPDiscovery?
    private var requestedLocations: [URL] = []
    private var adbRequestedHosts: [String] = []
    private var socketQueue = DispatchQueue(label: "DeviceBrowser-Socket", qos: .default, attributes: .concurrent)
    
    private var isRequiringRemote: Bool = false
    private var _devices = [Device]()
    public var devices: [Device] {
        if isRequiringRemote {
            return _devices.filter { $0.remote != nil }
        } else {
            return _devices
        }
    }
    var locationData: [URL: Data] = [:]
    
    public var logs: String = ""
    
    func notifyDevicesUpdate(_ device: Device) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.devicesUpdatedNotification, object: device)
        }
    }
    let discoveryDuration: TimeInterval = 4
    
    public func saveConnection(_ connection: Device.Connection?) {
        Self._lastConnection = connection
        if let connection, !Self.savedConnections.contains(where: { $0.host == connection.host }) {
            Self.savedConnections.append(connection)
        }
    }
    
    private func discoverService() {
        discovery?.delegate = nil
        discovery = .init()
        discovery!.delegate = self
        discovery!.discoverService(forDuration: discoveryDuration - 1.0)
    }
    
    public func startBrowsing(isRequiringRemote: Bool) {
        guard !isBrowsing else {
            return
        }
        self.isRequiringRemote = isRequiringRemote
        isBrowsing = true
        LocalNetworkAuthorization().requestAuthorization { [weak self] success in
            guard let self else { return }
            self.discoverService()
            Timer.scheduledTimer(withTimeInterval: self.discoveryDuration, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.discoverService()
            }
        }
    }
}


extension DeviceBrowser: SSDPDiscoveryDelegate {
    
    public func ssdpDiscovery(_ discovery: SSDPDiscovery, didDiscoverService service: SSDPService) {
//        logs += "\(Date()) Discovery: \(ObjectIdentifier(discovery).hashValue) Service: \(service.host) \(service.searchTarget ?? "No search target") \(service.location ?? "No location")\n"
        DispatchQueue.main.async {
            guard
                let locationString = service.location,
                let location = URL(string: locationString),
                let host = location.host,
                let port = location.port
            else {
                return
            }
            
            if !self.requestedLocations.contains(location) {
                self.requestedLocations.append(location)
                
                print("| SSDP discovered location: \(service.location ?? "none") st: \(service.searchTarget ?? "none")")
                
                let request = URLRequest(url: location)
                let session = URLSession(configuration: .default)
                let task = session.dataTask(with: request) { data, response, error in
                    DispatchQueue.main.async {
                        if let data {
                            self.locationData[location] = data
                            
                            let info = Device.SSDPInfo(port: port, data: data)
                            if let device = self._devices.first(where: { $0.host == host }) {
                                Device.updateHandler?(device, info)
                                self.notifyDevicesUpdate(device)
                            } else if let device = try? Device(host: host, ssdpInfo: info) {
                                self._devices.append(device)
                                self.notifyDevicesUpdate(device)
                            }
                            
                            DispatchQueue.main.async {
                                let device = XML.parse(data)["root", "device"]
                                if let wifiMac = device["wifiMac"].text {
                                    Self.macAddresses[host, default: []].insert(wifiMac)
                                }
                                if let wiredMac = device["wiredMac"].text {
                                    Self.macAddresses[host, default: []].insert(wiredMac)
                                }
                            }
                        }
                    }
                }
                task.resume()
            }
        }
    }
}
