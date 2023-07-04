//
//  File.swift
//  
//
//  Created by Illia Harkavy on 03/07/2023.
//

import Foundation

public extension URLSessionWebSocketTask.Message {
    var string: String {
        switch self {
        case .data(let data):
            return String(data: data, encoding: .utf8) ?? ""
        case .string(let string):
            return string
        @unknown default:
            return ""
        }
    }
    var data: Data {
        switch self {
        case .data(let data):
            return data
        case .string(let string):
            return string.data(using: .utf8) ?? .init()
        @unknown default:
            return .init()
        }
    }
}

