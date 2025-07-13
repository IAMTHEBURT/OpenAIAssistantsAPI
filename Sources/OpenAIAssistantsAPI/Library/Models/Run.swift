//
//  Run.swift
//  OpenAIAssistantsAPI
//
//  Created by Ivan Lvov on 24.05.2024.
//

import Foundation

public struct Run: Codable {
    public let id: String
    public let object: String
    public let created_at: Int
    public let thread_id: String
    public let assistant_id: String
    public let status: RunStatus
    public let required_action: RequiredAction?
    public let last_error: LastError?
    public let expires_at: Int?
    public let started_at: Int?
    public let cancelled_at: Int?
    public let failed_at: Int?
    public let completed_at: Int?
    public let incomplete_details: IncompleteDetails?
    public let model: String
    public let instructions: String
    public let tools: [Tool]
    public let metadata: [String: String]?
    public let usage: Usage?
    public let temperature: Float?
    public let top_p: Float?
    public let max_prompt_tokens: Int?
    public let max_completion_tokens: Int?
    public let truncation_strategy: TruncationStrategy
    public let tool_choice: ToolChoice
}

public enum RunStatus: String, Codable {
    case queued, in_progress, requires_action, cancelling, cancelled, failed, completed, incomplete, expired
}

public struct RequiredAction: Codable {
    public let type: String
    public let submit_tool_outputs: SubmitToolOutputs
}

public struct SubmitToolOutputs: Codable {
    public let tool_calls: [ToolCall]
}

public struct Function: Codable {
    public let name: String
    public let arguments: String
}

public struct Usage: Codable {
    public let prompt_tokens: Int
    public let completion_tokens: Int
    public let total_tokens: Int
}

public struct TruncationStrategy: Codable {
    public let type: String
    public let last_messages: Int?
}

public struct LastError: Codable {
    public let code: String
    public let message: String
}
