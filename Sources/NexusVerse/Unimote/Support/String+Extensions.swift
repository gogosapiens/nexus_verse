import Foundation

extension String {
    
    func substring(with nsrange: NSRange) -> Substring? {
        guard let range = Range(nsrange, in: self) else { return nil }
        return self[range]
    }
    
    func truncated(to numberOfCharacters: Int = 100) -> String {
        prefix(numberOfCharacters) + (count > numberOfCharacters ? "..." : "")
    }
    
    func flattened() -> String {
        replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: " ", with: "")
    }
}
