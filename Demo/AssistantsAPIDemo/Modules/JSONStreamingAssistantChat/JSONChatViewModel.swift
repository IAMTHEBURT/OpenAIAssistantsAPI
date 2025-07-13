//
//  JSONChatViewModel.swift
//  AssistantsAPIDemo
//
//  Created by Ivan Lvov on 02.07.2025.
//

import Foundation
import OpenAIAssistantsAPI
import AVFoundation

@MainActor
class JSONChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""
    @Published var isSending = false
    @Published var useSpeech: Bool = true
    @Published var useStreamingSpeech = true
    var buffer = ""

    private let assistantsAPI: AssistantsAPI
    private let assistantId: String
    private var thread: AssistantsThread?
    private var seenIDs: [String] = []
    private let playbackQueue = SpeechPlaybackQueue()
    private var spokenTexts: Set<String> = []

    init(apiKey: String, assistantId: String) {
        self.assistantsAPI = AssistantsAPI(
            baseUrl: "https://proxy.languageminute.com/v1",
            apiKey: apiKey,
            enableDebugLogging: false
        )
        //self.assistantId = assistantId
        self.assistantId = "asst_HEmtHqHuZjsKQKYh0UdiyDvX"
        createThread()
    }

    func onAppear() {
        insertDemoWelcomeMessage()
    }

    func insertDemoWelcomeMessage() {
        let demoMessage = """
        Hi there! This is a demo of working with the OpenAI Assistants API.

        What's special about this demo is that it uses a JSON-based message structure — which allows us to customize how each message type is rendered and interacted with.

        Messages can include riddles, explanations, or plain text — each with its own layout and behavior.

        Speech playback is also enabled, so responses are read aloud automatically.

        In this example, we're using a "Riddle Assistant" — a custom assistant with structured responses tailored for this interactive format.
        """
        messages.append(.init(content: demoMessage, isUser: false))
        // speakIfNeeded(demoMessage)
    }

    private func createThread() {
        assistantsAPI.createThread { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.thread = .init(id: response.id)
                case .failure(let error):
                    print("Failed to create thread: \(error)")
                }
            }
        }
    }
    func sendButtonTouched() {
        sendMessage(input)
        input = ""
    }

    func sendMessage(_ userMessage: String) {
        guard let thread = thread else { return }
        isSending = true

        messages.append(.init(content: userMessage, isUser: true))

        assistantsAPI.createMessage(to: thread, role: .user, content: [ContentPart(text: userMessage)]) { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async{ [weak self] in
                    self?.startStreaming(for: thread)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.isSending = false
                    print("Failed to create message: \(error)")
                }
            }
        }
    }

    private func startStreaming(for thread: AssistantsThread) {
        var seenIDs = Set<String>()
        var lastProcessedIndex = 0
        self.buffer = ""
        messages.append(ChatMessage(content: "", isUser: false, isStreaming: true))

        assistantsAPI.createRunStream(
            for: thread,
            assistantId: assistantId,
            stream: true,
            onPartialResponse: { [weak self] partial in
                guard let self else { return }

                DispatchQueue.main.async {
                    self.buffer += partial
                    guard let startRange = self.buffer.range(of: #""messages":["#) else {
                        print("'\"messages\":[\"' not found in buffer yet.")
                        return
                    }

                    let searchStart = self.buffer.index(startRange.upperBound, offsetBy: lastProcessedIndex)
                    guard searchStart < self.buffer.endIndex else { return }

                    var payload = self.buffer[searchStart...]
                    // Process all JSON objects in the new part
                    while let open = payload.firstIndex(of: "{"),
                          let close = self.findMatchingBrace(in: payload, from: open) {
                        let jsonBlock = payload[open...close]
                        let processedLength = self.buffer.distance(from: searchStart, to: close) + 1

                        // Try to decode as a separate message
                        if let data = String(jsonBlock).data(using: .utf8) {
                            do {
                                let message = try JSONDecoder().decode(JSONMessage.self, from: data)
                                if let id = message.id {
                                    if seenIDs.contains(id) {
                                        print("Duplicate message with id: \(id)")
                                    } else {
                                        seenIDs.insert(id)
                                        let parsed = self.parseJSONMessage(message)
                                        print("Init speak from partial \(message)")
                                        self.speakIfNeeded(message.speakableText)
                                        self.messages.append(.init(messageId: id, jsonMessage: message, content: parsed, isUser: false))
                                        print("Parsed and added message with id: \(id)")
                                    }
                                }
                            } catch { print("Failed to decode JSON block:\n\(error)") }
                        }

                        lastProcessedIndex += processedLength
                        payload = payload[close...].dropFirst()
                    }

                    if let index = self.messages.lastIndex(where: { !$0.isUser && $0.isStreaming }) {
                        self.messages[index].content = self.buffer
                    }
                }
            },
            onSessionClosed: { [weak self] _ in
                guard let self, let thread = self.thread else { return }
                DispatchQueue.main.async {
                    self.isSending = false
                    self.messages.removeAll(where: { !$0.isUser && $0.isStreaming })
                }
                self.assistantsAPI.listMessages(from: thread, limit: 1, order: "desc") { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let assistantMessages):
                            if let message = assistantMessages.first {
                                self.parseAndAppend(content: message.content)
                            }
                        case .failure(let error):
                            print("Failed to fetch final message: \(error)")
                        }
                    }
                }
            },
            onMessageCompleted: { [weak self] message in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.messages.removeAll(where: { !$0.isUser && $0.isStreaming })
                    self.parseAndAppend(content: message)
                    self.isSending = false
                }
            },
            completion: {
                _ in
            }
        )
    }

    private func findMatchingBrace(in text: Substring, from openIndex: String.Index) -> String.Index? {
        var depth = 0
        var current = openIndex

        while current < text.endIndex {
            if text[current] == "{" {
                depth += 1
            } else if text[current] == "}" {
                depth -= 1
                if depth == 0 {
                    return current
                }
            }
            current = text.index(after: current)
        }

        return nil
    }

    private func parseAndAppend(content: String, isStreaming: Bool = false) {
        if let data = content.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(JSONMessageWrapper.self, from: data) {

            for message in decoded.messages {
                let parsed = parseJSONMessage(message)

                let newMessage = ChatMessage(
                    messageId: message.id,
                    jsonMessage: message,
                    content: parsed,
                    isUser: false,
                    isStreaming: isStreaming
                )

                if let index = self.messages.firstIndex(where: { $0 == newMessage }) {
                    self.messages[index].content = parsed
                    self.messages[index].isStreaming = isStreaming
                } else {
                    self.messages.append(newMessage)
                }

                guard spokenTexts.count < decoded.messages.count else { return }
                print("Init speak from FULL \(message.speakableText ?? "")")

                speakIfNeeded(message.speakableText)
            }

        } else {
            if !content.isEmpty,
               !self.messages.contains(where: { $0.content == content && !$0.isUser }) {
                self.messages.append(.init(content: content, isUser: false, isStreaming: isStreaming))
            }
        }
    }

    private func speakIfNeeded(_ text: String?) {
        if let speakable = text, !spokenTexts.contains(speakable) {
            spokenTexts.insert(speakable)
            if useStreamingSpeech {
                let stream = assistantsAPI.createSpeechStreamAsync(input: speakable, voice: .nova)
                playbackQueue.enqueueChunkedStream(prompt: speakable, speechStream: stream)
            } else {
                assistantsAPI.createSpeech(input: speakable, voice: .nova) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success(let audio):
                        DispatchQueue.main.async {
                            self.playbackQueue.enqueue(audio)
                        }
                    case .failure(let error):
                        print("Speech error: \(error)")
                    }
                }
            }
        }
    }

    private func parseJSONMessage(_ message: JSONMessage) -> String {
        switch message {
        case .text(let t):
            return t.text
        case .explanation(let explanation):
            return "💡 Explanation: \(explanation.explanation)"
        case .riddle(let riddle):
            return "❓ \(riddle.riddle)\n" + riddle.options.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
        }
    }

}

enum JSONMessage: Decodable, Equatable {
    case text(TextMessage)
    case riddle(Riddle)
    case explanation(Explanation)

    struct TextMessage: Decodable, Equatable {
        let id: String
        let speak: String
        let text: String
    }

    struct Riddle: Decodable, Equatable {
        let id: String
        let speak: String
        let riddle: String
        let options: [String]
    }

    struct Explanation: Decodable, Equatable {
        let id: String
        let speak: String
        let explanation: String
    }

    enum CodingKeys: String, CodingKey {
        case id, text, riddle, options, explanation, speak
    }

    var id: String? {
        switch self {
        case .text(let t): return t.id
        case .riddle(let r): return r.id
        case .explanation(let e): return e.id
        }
    }

    var speakableText: String? {
        switch self {
        case .text(let t): return t.speak
        case .riddle(let r): return r.speak
        case .explanation(let e): return e.speak
        }
    }

    init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)

        if let text = try? keyed.decode(String.self, forKey: .text),
           let speak = try? keyed.decode(String.self, forKey: .speak),
           let id = try? keyed.decode(String.self, forKey: .id) {
            self = .text(TextMessage(id: id, speak: speak, text: text))
            return
        }

        if let explanation = try? keyed.decode(String.self, forKey: .explanation),
           let speak = try? keyed.decode(String.self, forKey: .speak),
           let id = try? keyed.decode(String.self, forKey: .id) {
            self = .explanation(Explanation(id: id, speak: speak, explanation: explanation))
            return
        }

        if let riddle = try? keyed.decode(String.self, forKey: .riddle),
           let id = try? keyed.decode(String.self, forKey: .id),
           let speak = try? keyed.decode(String.self, forKey: .speak),
           let options = try? keyed.decode([String].self, forKey: .options) {
            self = .riddle(Riddle(id: id, speak: speak, riddle: riddle, options: options))
            return
        }

        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unrecognized JSONMessage"))
    }

    static func == (lhs: JSONMessage, rhs: JSONMessage) -> Bool {
        switch (lhs, rhs) {
        case let (.text(l), .text(r)):
            return l == r
        case let (.riddle(l), .riddle(r)):
            return l == r
        case let (.explanation(l), .explanation(r)):
            return l == r
        default:
            return false
        }
    }
}

struct JSONMessageWrapper: Decodable {
    let messages: [JSONMessage]
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    var messageId: String? = nil
    var jsonMessage: JSONMessage? = nil
    var content: String
    var isUser: Bool
    var isStreaming: Bool = false

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        if lhs.messageId == rhs.messageId { return true }
        if lhs.jsonMessage?.speakableText == rhs.jsonMessage?.speakableText { return true }
        if lhs.content == rhs.content && lhs.isUser && rhs.isUser { return true }
        return false
    }
}
