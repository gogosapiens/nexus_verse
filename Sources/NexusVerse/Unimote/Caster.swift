import Foundation

public protocol Caster: AnyObject {
    
    func castPhoto(with url: URL, completion: @escaping (Bool) -> Void)
    func castVideo(with url: URL, completion: @escaping (Bool) -> Void)
}
