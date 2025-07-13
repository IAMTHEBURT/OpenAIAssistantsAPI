//
//  RunStep.swift
//  OpenAIAssistantsAPI
//
//  Created by Ivan Lvov on 26.05.2024.
//

import Foundation

public struct RunStep: Codable {
    public let id: String
    public let object: String
    public let created_at: Int
    public let run_id: String
    public let assistant_id: String
    public let thread_id: String
    public let type: String
    public let status: String
    public let cancelled_at: Int?
    public let completed_at: Int?
    public let expires_at: Int?
    public let failed_at: Int?
    public let last_error: LastError?
}
