//
//  Content.swift
//  CooksMate
//
//  Created by Ivan Lvov on 24.05.2024.
//

import Foundation

public struct ContentPart: Codable {
    public let type: ContentType
    public let text: String?
    public let image_url: String?
    public let image_file: String?

    public init(text: String) {
        type = .text
        self.text = text
        image_url = nil
        image_file = nil
    }

    public init(imageUrl: String) {
        type = .imageUrl
        text = nil
        image_url = imageUrl
        image_file = nil
    }

    public init(imageFile: String) {
        type = .imageFile
        text = nil
        image_url = nil
        image_file = imageFile
    }
}

public enum ContentType: String, Codable {
    case text
    case imageUrl = "image_url"
    case imageFile = "image_file"
}

public struct TextContent: Codable {
    public let value: String
}

public struct Attachment: Codable, Hashable {
    public static func == (lhs: Attachment, rhs: Attachment) -> Bool {
        lhs.file_id == rhs.file_id
    }

    public let file_id: String
    public let tools: [Tool]
}

public enum ResponseFormat: Codable {
    case auto
    case jsonObject

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        switch stringValue {
        case "auto":
            self = .auto
        case "json_object":
            self = .jsonObject
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid response format")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto:
            try container.encode("auto")
        case .jsonObject:
            try container.encode("json_object")
        }
    }
}
