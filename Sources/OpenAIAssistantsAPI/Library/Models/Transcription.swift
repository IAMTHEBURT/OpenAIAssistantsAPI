//
//  Transcription.swift
//  OpenAIAssistantsAPI
//
//  Created by Ivan Lvov on 02.06.2024.
//

import Foundation

public struct TranscriptionResponse: Codable {
    public let text: String
    public let segments: [Segment]?

    public struct Segment: Codable {
        public let start: Double
        public let end: Double
        public let text: String
    }
}
