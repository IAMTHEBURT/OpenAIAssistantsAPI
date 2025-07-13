//
//  AssistantsAPIDemoApp.swift
//  AssistantsAPIDemo
//
//  Created by Ivan Lvov on 02.07.2025.
//

import SwiftUI
import OpenAIAssistantsAPI

@main
struct AssistantsAPIDemoApp: App {
    @AppStorage("openai_api_key") var apiKey: String = ""
    @AppStorage("openai_assistant_id") var assistantId: String = ""

    var body: some Scene {
        WindowGroup {
            if apiKey.isEmpty || assistantId.isEmpty {
                SetupView()
            } else {
                MainTabView(apiKey: apiKey, assistantId: assistantId)
            }
        }
    }
}

struct MainTabView: View {
    let apiKey: String
    let assistantId: String

    var body: some View {
        TabView {
            ChatView(apiKey: apiKey, assistantId: assistantId)
                .tabItem {
                    Label("Chat", systemImage: "message")
                }

            JSONChatView(apiKey: apiKey, assistantId: assistantId)
                .tabItem {
                    Label("JSON Chat", systemImage: "doc.plaintext")
                }
            
            SetupView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    @Previewable @AppStorage("openai_api_key") var apiKey: String = ""
    @Previewable @AppStorage("openai_assistant_id") var assistantId: String = "asst_HEmtHqHuZjsKQKYh0UdiyDvX"

    MainTabView(apiKey: apiKey, assistantId: assistantId)
}
