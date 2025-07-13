//
//  Assistant.swift
//  OpenAIAssistantsAPI
//
//  Created by Ivan Lvov on 24.05.2024.
//

import Foundation

public struct Assistant: Codable {
    public let id: String
    public var name: String? = nil
    public var instructions: String? = nil
    public var tools: [Tool]? = nil
    public var model: String? = nil
    public var tool_resources: ToolResources? = nil
}
