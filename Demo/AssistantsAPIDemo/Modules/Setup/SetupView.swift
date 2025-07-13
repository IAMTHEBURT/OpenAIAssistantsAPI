//
//  SetupView.swift
//  AssistantsAPIDemo
//
//  Created by Ivan Lvov on 02.07.2025.
//

import SwiftUI

struct SetupView: View {
    @AppStorage("openai_api_key") private var apiKey: String = ""
    @AppStorage("openai_assistant_id") private var assistantId: String = "asst_HEmtHqHuZjsKQKYh0UdiyDvX"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Key")) {
                    SecureField("Enter your OpenAI API key", text: $apiKey)
                }

                Section(header: Text("Assistant ID for regular chat")) {
                    TextField("Enter your Assistant ID", text: $assistantId)
                }

                Button("Save and Continue") {
                    apiKey = apiKey.trimmingCharacters(in: .whitespaces)
                    assistantId = assistantId.trimmingCharacters(in: .whitespaces)
                }
                .disabled(apiKey.isEmpty || assistantId.isEmpty)
            }
            .navigationTitle("Setup")
        }
    }
}

#Preview {
    SetupView()
}
