//
//  AssistantsMessage.swift
//  OpenAIAssistantsAPI
//
//  Created by Ivan Lvov on 26.05.2024.
//

import Foundation

public struct AssistantsMessage {
    public var id: String
    public var role: Role
    public var content: String
    public var createdAt: Date
    public var threadId: String?
    public var isLocal: Bool?
    public var isRunStep: Bool?
    public var isFailed: Bool = false
    public var isInitial: Bool
    public var attachments: [Attachment]?
    public var metadata: [String: String]?

    public init(
        id: String,
        role: Role,
        content: String,
        createdAt: Date = Date(),
        threadId: String? = nil,
        isLocal: Bool? = nil,
        isRunStep: Bool? = nil,
        isFailed: Bool = false,
        isInitial: Bool = false,
        attachments: [Attachment]? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.threadId = threadId
        self.isLocal = isLocal
        self.isRunStep = isRunStep
        self.isFailed = isFailed
        self.isInitial = isInitial
        self.attachments = attachments
        self.metadata = metadata
    }
}

extension AssistantsMessage: Equatable, Codable, Hashable, Identifiable {}

public struct MessageRequest: Equatable, Codable {
    public var role: Role
    public var content: String
    public var isLocal: Bool?
    public var isRunStep: Bool?
    public var attachments: [Attachment]?

    public init(
        role: Role,
        content: String,
        isLocal: Bool? = nil,
        isRunStep: Bool? = nil,
        attachments: [Attachment]? = nil
    ) {
        self.role = role
        self.content = content
        self.isLocal = isLocal
        self.isRunStep = isRunStep
        self.attachments = attachments
    }
}

struct MessageList: Codable {
    let object: String
    let data: [AssistantsMessageDTO]
}

public struct AssistantsMessageDTO: Equatable, Codable {
    public static func == (lhs: AssistantsMessageDTO, rhs: AssistantsMessageDTO) -> Bool {
        lhs.id == rhs.id
    }

    public var id: String
    public var object: String
    public var created_at: Int
    public var thread_id: String
    public var status: MessageStatus?
    public var incomplete_details: IncompleteDetails?
    public var completed_at: Int?
    public var incomplete_at: Int?
    public var role: Role
    public var content: [ContentDTO]
    public var assistant_id: String?
    public var run_id: String?
    public var attachments: [Attachment]?
    public var metadata: [String: String]?

    public init(
        id: String,
        object: String,
        created_at: Int,
        thread_id: String,
        status: MessageStatus?,
        incomplete_details: IncompleteDetails?,
        completed_at: Int? = nil,
        incomplete_at: Int? = nil,
        role: Role, content: [ContentDTO],
        assistant_id: String? = nil,
        run_id: String? = nil,
        attachments: [Attachment]? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.object = object
        self.created_at = created_at
        self.thread_id = thread_id
        self.status = status
        self.incomplete_details = incomplete_details
        self.completed_at = completed_at
        self.incomplete_at = incomplete_at
        self.role = role
        self.content = content
        self.assistant_id = assistant_id
        self.run_id = run_id
        self.attachments = attachments
        self.metadata = metadata
    }
}

public struct IncompleteDetails: Codable {
    var reason: String
}

public enum MessageStatus: String, Codable {
    case in_progress, incomplete, completed
}

public struct TextDTO: Equatable, Codable {
    public var value: String
}

public struct ContentDTO: Equatable, Codable {
    public var type: String
    public var text: TextDTO
}
