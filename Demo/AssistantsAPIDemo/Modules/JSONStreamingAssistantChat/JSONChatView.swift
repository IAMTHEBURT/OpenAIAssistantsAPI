//
//  JSONChatView.swift
//  AssistantsAPIDemo
//
//  Created by Ivan Lvov on 02.07.2025.
//

import SwiftUI

struct JSONChatView: View {
    @StateObject private var viewModel: JSONChatViewModel

    init(apiKey: String, assistantId: String) {
        _viewModel = StateObject(wrappedValue: JSONChatViewModel(apiKey: apiKey, assistantId: assistantId))
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages.indices, id: \.self) { index in
                            let message = viewModel.messages[index]
                            HStack {
                                if message.isUser {
                                    Spacer()
                                    Text(message.content)
                                        .padding()
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(12)
                                } else {
                                    if let json = message.jsonMessage {
                                        switch json {
                                        case .text(let t):
                                            TextMessageView(text: t.text)
                                        case .explanation(let e):
                                            ExplanationMessageView(explanation: e.explanation)
                                        case .riddle(let r):
                                            RiddleMessageView(riddle: r.riddle, options: r.options) { text in
                                                viewModel.sendMessage(text)
                                            }
                                        }
                                    } else {
                                        Text(message.content)
                                            .padding()
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(12)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(viewModel.messages.count - 1, anchor: .bottom)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle("🔊 Speech ", isOn: $viewModel.useSpeech)
                Toggle("📶 Stream", isOn: $viewModel.useStreamingSpeech)
            }
            .padding(.horizontal)
            .toggleStyle(SwitchToggleStyle(tint: .blue))

            HStack {
                TextField("Message", text: $viewModel.input)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(viewModel.isSending)
                Button("Send") {
                    viewModel.sendButtonTouched()
                }
                .disabled(viewModel.input.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
            }
            .padding()
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

struct TextMessageView: View {
    let text: String

    var body: some View {
        Text(text)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
    }
}

struct ExplanationMessageView: View {
    let explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("💡 Explanation")
                .font(.caption)
                .foregroundColor(.gray)
            Text(explanation)
        }
        .padding()
        .background(Color.yellow.opacity(0.2))
        .cornerRadius(12)
    }
}

struct RiddleMessageView: View {
    let riddle: String
    let options: [String]
    var onSelected: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("❓ \(riddle)")
                .font(.headline)

            ForEach(options.indices, id: \.self) { index in
                Button(action: {
                    onSelected?(options[index])
                }) {
                    Text(options[index])
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.15))
        .cornerRadius(12)
    }
}
