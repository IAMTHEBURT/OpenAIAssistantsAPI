//
//  Tool.swift
//  OpenAIAssistantsAPI
//
//  Created by Ivan Lvov on 24.05.2024.
//

import Foundation

public struct Tool: Codable, Hashable {
    let type: String
}

public struct VectorStore: Codable {
    public let vector_store_ids: [String]
}

public struct ToolResources: Codable {
    public let file_search: VectorStore?
    public let code_interpreter: CodeInterpreterFiles?
}

public struct ToolCall: Codable {
    public let id: String
    public let type: String
    public let function: Function
}

public enum ToolChoice: Codable {
    case none
    case auto
    case required
    case specificTool(Tool)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            switch stringValue {
            case "none":
                self = .none
            case "auto":
                self = .auto
            case "required":
                self = .required
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid tool choice")
            }
        } else if let tool = try? container.decode(Tool.self) {
            self = .specificTool(tool)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid tool choice")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case .required:
            try container.encode("required")
        case let .specificTool(tool):
            try container.encode(tool)
        }
    }
}

public struct CodeInterpreterFiles: Codable {
    public let file_ids: [String]
}
