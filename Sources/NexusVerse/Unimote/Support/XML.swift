import SwiftyXMLParser

extension XML.Accessor {
    
    var keysAndTexts: [String: String] {
        guard let element else { return [:] }
        return Dictionary(
            element.childElements.compactMap { element in
                if let text = element.text, !text.allSatisfy(\.isWhitespace) {
                    return (element.name, text)
                } else {
                    return nil
                }
            },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
