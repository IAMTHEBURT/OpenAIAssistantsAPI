//
//  AssistantsThread.swift
//  OpenAIAssistantsAPI
//
//  Created by Ivan Lvov on 24.05.2024.
//

import Foundation

public struct AssistantsThread: Codable {
    public let id: String
    public var tools: [Tool]? = nil
    public var tool_resources: ToolResources? = nil

    public init(id: String, tools: [Tool]? = nil, tool_resources: ToolResources? = nil) {
        self.id = id
        self.tools = tools
        self.tool_resources = tool_resources
    }
}

public struct ThreadRequest: Codable {
    public let messages: [ThreadMessage]?
    public let attachments: [Attachment]?
    public let metadata: [String: String]?
    public let tool_resources: ToolResources?
}

public struct ThreadMessage: Codable {
    public let role: Role
    public let content: [ContentPart]
    public let attachments: [Attachment]?
    public let metadata: [String: String]?

    public init(role: Role, content: [ContentPart], attachments: [Attachment]?, metadata: [String: String]?) {
        self.role = role
        self.content = content
        self.attachments = attachments
        self.metadata = metadata
    }
}

public struct ThreadResponse: Codable {
    public let id: String
    public let object: String
    public let created_at: Int
    public let metadata: [String: String]
    public let tool_resources: ToolResources?
}
