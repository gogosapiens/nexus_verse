import Foundation

public struct Channel {
    
    public let id: String
    public let name: String
    public let number: String
    
    public init(id: String, name: String, number: String) {
        self.id = id
        self.name = name
        self.number = number
    }
}
