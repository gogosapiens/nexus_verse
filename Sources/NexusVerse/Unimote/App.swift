import UIKit

public struct App {
    public let id: String
    public let name: String
    
    public var friendlyAppIndex: Int? {
        FriendlyApp.allCases.firstIndex(where: { $0.ids.contains(self.id) })
    }
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
