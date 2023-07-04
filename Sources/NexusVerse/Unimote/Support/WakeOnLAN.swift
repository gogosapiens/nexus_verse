import Foundation

public class WakeOnLAN {
    public struct Device {
        public init(mac: String, broadcastAddr: String = "255.255.255.255", port: UInt16 = 9) {
            self.mac = mac
            self.broadcastAddr = broadcastAddr
            self.port = port
        }
        
        var mac: String
        var broadcastAddr: String
        var port: UInt16 = 9
    }
    
    public enum WakeError: Error {
        case socketSetupFailed(reason: String)
        case setSocketOptionsFailed(reason: String)
        case sendMagicPacketFailed(reason: String)
    }
    
    public static func target(device: Device) -> Error? {
        var sock: Int32
        var target = sockaddr_in()
        
        target.sin_family = sa_family_t(AF_INET)
        
        // Check Broadcast address (is an IP address or a domain name)
        var bcaddr = inet_addr(device.broadcastAddr)
        if bcaddr == INADDR_NONE {
            bcaddr = inet_addr(gethostbyname(device.broadcastAddr))
        }
        target.sin_addr.s_addr = bcaddr
        
        let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
        target.sin_port = isLittleEndian ? _OSSwapInt16(device.port) : device.port
        
        // Setup the packet socket
        sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        if sock < 0 {
            let err = String(utf8String: strerror(errno)) ?? ""
            return WakeError.socketSetupFailed(reason: err)
        }
        
        let packet = WakeOnLAN.createMagicPacket(mac: device.mac)
        let sockaddrLen = socklen_t(MemoryLayout<sockaddr>.stride)
        let intLen = socklen_t(MemoryLayout<Int>.stride)
        
        // Set socket options
        var broadcast = 1
        if setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, intLen) == -1 {
            close(sock)
            let err = String(utf8String: strerror(errno)) ?? ""
            return WakeError.setSocketOptionsFailed(reason: err)
        }
        
        // Send magic packet
        var targetCast = unsafeBitCast(target, to: sockaddr.self)
        if sendto(sock, packet, packet.count, 0, &targetCast, sockaddrLen) != packet.count {
            close(sock)
            let err = String(utf8String: strerror(errno)) ?? ""
            return WakeError.sendMagicPacketFailed(reason: err)
        }
        
        close(sock)
        
        return nil
    }
    
    private static func createMagicPacket(mac: String) -> [CUnsignedChar] {
        var buffer = [CUnsignedChar]()
        
        // Create header
        for _ in 1...6 {
            buffer.append(0xFF)
        }
        
        let components = mac.components(separatedBy: ":")
        let numbers = components.map {
            return strtoul($0, nil, 16)
        }
        
        // Repeat MAC address 20 times
        for _ in 1...20 {
            for number in numbers {
                buffer.append(CUnsignedChar(number))
            }
        }
        
        return buffer
    }
}
