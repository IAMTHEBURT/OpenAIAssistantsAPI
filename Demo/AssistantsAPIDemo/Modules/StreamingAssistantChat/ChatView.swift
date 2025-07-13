//
//  ChatView.swift
//  AssistantsAPIDemo
//
//  Created by Ivan Lvov on 02.07.2025.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel

    init(apiKey: String, assistantId: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(apiKey: apiKey, assistantId: assistantId))
    }

    var body: some View {
        VStack {
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
                                    VStack {
                                        Text(message.messageId ?? "")
                                        Text(message.content)
                                            .padding()
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(12)
                                        Spacer()
                                    }

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

            HStack {
                TextField("Message", text: $viewModel.input)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(viewModel.isSending)
                Button("Send") {
                    viewModel.sendMessage()
                }
                .disabled(viewModel.input.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
            }
            .padding()
        }
    }
}
