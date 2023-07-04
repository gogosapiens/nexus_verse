import UIKit
import Vapor
import AVKit
import Photos

public class FileServer: ObservableObject {
    
    private let host: String
    private let port: Int
    
    public init?() {
        guard let host = UIDevice.wifiIPv4 else {
            return nil
        }
        self.host = host
        self.port = Int(Self.getFreePort())
        
        let app = Application(.development)
        app.http.server.configuration.hostname = host
        app.http.server.configuration.port = port
        do {
            try app.register(collection: FileWebRouteCollection())
            try app.start()
        } catch {
            return nil
        }
    }
    
    public static func getFreePort() -> UInt16 {
        var port: UInt16 = 8000
        
        let socketFD = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        if socketFD == -1 {
            return port
        }
        
        var hints = addrinfo(
            ai_flags: AI_PASSIVE,
            ai_family: AF_INET,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
    
        var addressInfo: UnsafeMutablePointer<addrinfo>? = nil
        var result = getaddrinfo(nil, "0", &hints, &addressInfo)
        if result != 0 {
            close(socketFD)
            return port
        }
        
        result = Darwin.bind(socketFD, addressInfo!.pointee.ai_addr, socklen_t(addressInfo!.pointee.ai_addrlen));
        if result == -1 {
            close(socketFD)
            return port
        }
        
        result = Darwin.listen(socketFD, 1)
        if result == -1 {
            close(socketFD)
            return port
        }
        
        var addr_in = sockaddr_in()
        addr_in.sin_len = UInt8(MemoryLayout.size(ofValue: addr_in))
        addr_in.sin_family = sa_family_t(AF_INET)
        
        var len = socklen_t(addr_in.sin_len)
        result = withUnsafeMutablePointer(to: &addr_in, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                return Darwin.getsockname(socketFD, $0, &len)
            }
        })
        
        if result == 0 {
            port = addr_in.sin_port
        }
        
        Darwin.shutdown(socketFD, SHUT_RDWR)
        close(socketFD)
        
        return port
    }
    
    public func hostFile(at localURL: URL, withId id: String) -> URL? {
        let fileName = id + "." + localURL.pathExtension
        let documentsURL = Self.hostingURL(for: fileName)
        let hostingURL = URL(string: "http://\(host):\(port)/\(fileName)")!
        if !FileManager.default.fileExists(atPath: documentsURL.path) {
            do {
                try FileManager.default.copyItem(
                    at: localURL,
                    to: documentsURL
                )
            } catch {
                return nil
            }
        }
        return hostingURL
    }
    
    public enum File {
        case image(URL)
        case video(URL)
    }
    
    static private var cancelledTaskIds = Set<UUID>()
    
    public static func cancelTask(with id: UUID) {
        cancelledTaskIds.insert(id)
    }
    
    public func hostAsset(_ asset: PHAsset, progressHandler: @escaping (Float) -> Void, completionHandler: @escaping (URL?) -> Void) -> UUID {
        
        func complete(with url: URL?) {
            DispatchQueue.main.async {
                completionHandler(url)
            }
        }
        
        func setProgress(_ progress: Float) {
            DispatchQueue.main.async {
                progressHandler(progress)
            }
        }
        
        let taskId = UUID()
        
        setProgress(0)
        
        asset.getURL { [host, port] assetURL in
            guard let assetURL, !Self.cancelledTaskIds.contains(taskId) else {
                complete(with: nil)
                return
            }
            
            let id = UUID().uuidString
            setProgress(0.1)
            
            switch asset.mediaType {
            case .image:
                let fileName = id + ".jpg"
                let documentsURL = Self.hostingURL(for: fileName)
                let hostingURL = URL(string: "http://\(host):\(port)/\(fileName)")!
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let originalData = try Data(contentsOf: assetURL)
                        guard
                            let image = UIImage(data: originalData),
                            let data = image.jpegData(compressionQuality: 1)
                        else {
                            setProgress(1)
                            complete(with: nil)
                            return
                        }
                        try data.write(to: documentsURL)
                        setProgress(1)
                        complete(with: Self.cancelledTaskIds.contains(taskId) ? nil : hostingURL)
                    } catch {
                        setProgress(1)
                        complete(with: nil)
                    }
                }
            case .video:
                let fileName = id + ".mp4"
                let documentsURL = Self.hostingURL(for: fileName)
                let hostingURL = URL(string: "http://\(host):\(port)/\(fileName)")!
                if !FileManager.default.fileExists(atPath: documentsURL.path) {
                    guard let session = AVAssetExportSession(asset: AVURLAsset(url: assetURL), presetName: AVAssetExportPresetMediumQuality) else {
                        setProgress(1)
                        complete(with: nil)
                        return
                    }
                    let timer = DispatchQueue.main.sync {
                        return Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                            setProgress(0.2 + session.progress * 0.8)
                        }
                    }
                    session.outputURL = documentsURL
                    session.outputFileType = .mp4
                    session.shouldOptimizeForNetworkUse = true
                    session.exportAsynchronously {
                        timer.invalidate()
                        setProgress(1)
                        complete(with: (session.status == .completed && !Self.cancelledTaskIds.contains(taskId)) ? hostingURL : nil)
                    }
                }
            default:
                setProgress(1)
                complete(with: nil)
            }
        }
        return taskId
    }
    
    public static func hostingURL(for fileName: String) -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName)
    }
    
    public struct FileWebRouteCollection: RouteCollection {
        
        public func boot(routes: RoutesBuilder) throws {
            routes.get(":filename", use: downloadFileHandler)
        }
        
        public func downloadFileHandler(_ req: Request) throws -> Response {
            guard let fileName = req.parameters.get("filename") else {
                throw Abort(.badRequest)
            }
            let fileUrl = FileServer.hostingURL(for: fileName)
            return req.fileio.streamFile(at: fileUrl.path)
        }
    }
}
