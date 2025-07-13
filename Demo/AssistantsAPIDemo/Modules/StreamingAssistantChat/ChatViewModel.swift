//
//  ChatViewModel.swift
//  AssistantsAPIDemo
//
//  Created by Ivan Lvov on 02.07.2025.
//

import Foundation
import OpenAIAssistantsAPI

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""
    @Published var isSending = false

    private let assistantsAPI: AssistantsAPI
    private let assistantId: String
    private var thread: AssistantsThread?

    init(apiKey: String, assistantId: String) {
        self.assistantsAPI = AssistantsAPI(
            baseUrl: "https://proxy.languageminute.com/v1",
            apiKey: apiKey
        )
        self.assistantId = assistantId
        createThread()
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

    func sendMessage() {
        guard let thread = thread else { return }
        let userMessage = input
        input = ""
        isSending = true

        messages.append(.init(content: userMessage, isUser: true))

        assistantsAPI.createMessage(to: thread, role: .user, content: [ContentPart(text: userMessage)]) { [weak self] result in
            switch result {
            case .success:
                self?.startStreaming(for: thread)
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.isSending = false
                    print("Failed to create message: \(error)")
                }
            }
        }
    }

    private func startStreaming(for thread: AssistantsThread) {
        var assistantReply = ""
        messages.append(.init(content: "", isUser: false))
        let index = messages.count - 1

        assistantsAPI.createRunStream(
            for: thread,
            assistantId: assistantId,
            stream: true,
            onPartialResponse: { [weak self] partial in
                DispatchQueue.main.async {
                    assistantReply += partial
                    self?.messages[index].content = assistantReply
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    self?.isSending = false
                    switch result {
                    case .success:
                        print("Stream completed")
                    case .failure(let error):
                        print("Stream failed: \(error)")
                    }
                }
            }
        )
    }
}
