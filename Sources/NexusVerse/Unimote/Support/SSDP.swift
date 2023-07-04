import Foundation
import Socket

// MARK: Protocols

/// Delegate for service discovery
public protocol SSDPDiscoveryDelegate {
    /// Tells the delegate a requested service has been discovered.
    func ssdpDiscovery(_ discovery: SSDPDiscovery, didDiscoverService service: SSDPService)
    
    /// Tells the delegate that the discovery ended due to an error.
    func ssdpDiscovery(_ discovery: SSDPDiscovery, didFinishWithError error: Error)
    
    /// Tells the delegate that the discovery has started.
    func ssdpDiscoveryDidStart(_ discovery: SSDPDiscovery)
    
    /// Tells the delegate that the discovery has finished.
    func ssdpDiscoveryDidFinish(_ discovery: SSDPDiscovery)
}

public extension SSDPDiscoveryDelegate {
    func ssdpDiscovery(_ discovery: SSDPDiscovery, didDiscoverService service: SSDPService) {}
    
    func ssdpDiscovery(_ discovery: SSDPDiscovery, didFinishWithError error: Error) {}
    
    func ssdpDiscoveryDidStart(_ discovery: SSDPDiscovery) {}
    
    func ssdpDiscoveryDidFinish(_ discovery: SSDPDiscovery) {}
}

/// SSDP discovery for UPnP devices on the LAN
public class SSDPDiscovery {
    
    /// The UDP socket
    private var socket: Socket?
    
    /// Delegate for service discovery
    public var delegate: SSDPDiscoveryDelegate?
    
    /// The client is discovering
    public var isDiscovering: Bool {
        get {
            return self.socket != nil
        }
    }
    
    // MARK: Initialisation
    
    public init() {
    }
    
    deinit {
        self.stop()
    }
    
//    var logs: String = ""
    
    // MARK: Private functions
    
    /// Read responses.
    private func readResponses() {
        do {
            guard let socket else { return }
            var data = Data()
            let (bytesRead, address) = try socket.readDatagram(into: &data)
            
            if
                bytesRead > 0,
                let address,
                let response = String(data: data, encoding: .utf8),
                let (remoteHost, _) = Socket.hostnameAndPort(from: address)
            {
                //                logs += "Received: \(response) from \(remoteHost)\n"
                self.delegate?.ssdpDiscovery(self, didDiscoverService: SSDPService(host: remoteHost, response: response))
            }
            
        } catch let error {
            self.forceStop()
            self.delegate?.ssdpDiscovery(self, didFinishWithError: error)
        }
    }
    
    /// Read responses with timeout.
    private func readResponses(forDuration duration: TimeInterval) {
        let queue = DispatchQueue.global()
        
        queue.async() { [weak self] in
            guard let self else { return }
            while self.isDiscovering {
                self.readResponses()
            }
        }
        
        queue.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.stop()
        }
    }
    
    /// Force stop discovery closing the socket.
    private func forceStop() {
        if self.isDiscovering {
            self.socket?.close()
        }
        self.socket = nil
    }
    
    // MARK: Public functions
    
    /**
     Discover SSDP services for a duration.
     - Parameters:
     - duration: The amount of time to wait.
     - searchTarget: The type of the searched service.
     */
    open func discoverService(forDuration duration: TimeInterval = 10, searchTarget: String = "ssdp:all", port: Int32 = 1900) {
        self.delegate?.ssdpDiscoveryDidStart(self)
        
        let message = "M-SEARCH * HTTP/1.1\r\n" +
        "MAN: \"ssdp:discover\"\r\n" +
        "HOST: 239.255.255.250:\(port)\r\n" +
        "ST: \(searchTarget)\r\n" +
        "MX: \(Int(duration))\r\n\r\n"
        
        do {
            self.socket = try Socket.create(type: .datagram, proto: .udp)
            try self.socket!.listen(on: 0)
            
            self.readResponses(forDuration: duration)
            
            try self.socket?.write(from: message, to: Socket.createAddress(for: "239.255.255.250", on: port)!)
            
        } catch let error {
            self.forceStop()
            self.delegate?.ssdpDiscovery(self, didFinishWithError: error)
        }
    }
    
    /// Stop the discovery before the timeout.
    open func stop() {
        if self.socket != nil {
            self.forceStop()
            self.delegate?.ssdpDiscoveryDidFinish(self)
        }
    }
}

public class SSDPService {
    /// The host of service
    public internal(set) var host: String
    /// The value of `LOCATION` header
    public internal(set) var location: String?
    /// The value of `SERVER` header
    public internal(set) var server: String?
    /// The value of `ST` header
    public internal(set) var searchTarget: String?
    /// The value of `USN` header
    public internal(set) var uniqueServiceName: String?
    
    // MARK: Initialisation
    
    /**
     Initialize the `SSDPService` with the discovery response.
     
     - Parameters:
     - host: The host of service
     - response: The discovery response.
     */
    init(host: String, response: String) {
        self.host = host
        self.location = self.parse(header: "LOCATION", in: response) ?? self.parse(header: "Location", in: response) ?? self.parse(header: "location", in: response)
        self.server = self.parse(header: "SERVER", in: response) ?? self.parse(header: "Server", in: response) ?? self.parse(header: "server", in: response)
        self.searchTarget = self.parse(header: "ST", in: response) ?? self.parse(header: "st", in: response)
        self.uniqueServiceName = self.parse(header: "USN", in: response) ?? self.parse(header: "usn", in: response)
    }
    
    // MARK: Private functions
    
    /**
     Parse the discovery response.
     
     - Parameters:
     - header: The header to parse.
     - response: The discovery response.
     */
    private func parse(header: String, in response: String) -> String? {
        if let range = response.range(of: "\(header): .*", options: .regularExpression) {
            var value = String(response[range])
            value = value.replacingOccurrences(of: "\(header): ", with: "")
            return value
        }
        return nil
    }
}
