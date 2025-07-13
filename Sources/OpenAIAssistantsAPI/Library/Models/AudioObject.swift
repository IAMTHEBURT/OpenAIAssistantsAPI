//
//  AudioObject.swift
//  OpenAIAssistantsAPI
//
//  Created by Ivan Lvov on 12.07.2025.
//

import AVFoundation

public struct AudioSpeechResult: Equatable, Sendable {
    public let audio: Data

    public init(audio: Data) {
        self.audio = audio
    }
}

public struct AudioObject: Identifiable {
    public let id = UUID()
    public let prompt: String
    public let audioPlayer: AVAudioPlayer
    public let originResponse: AudioSpeechResult
    public let format: String

    public init(prompt: String, audioPlayer: AVAudioPlayer, originResponse: AudioSpeechResult, format: String) {
        self.prompt = prompt
        self.audioPlayer = audioPlayer
        self.originResponse = originResponse
        self.format = format
    }
}
