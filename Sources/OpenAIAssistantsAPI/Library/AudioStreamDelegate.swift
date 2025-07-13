//
//  AudioStreamDelegate.swift
//  OpenAIAssistantsAPI
//
//  Created by Ivan Lvov on 12.07.2025.
//

import Foundation

final class AudioStreamDelegate: NSObject, URLSessionDataDelegate {
    private let onData: (Data) -> Void
    private let onComplete: (Result<Void, AssistantsAPIError>) -> Void

    init(onData: @escaping (Data) -> Void, onComplete: @escaping (Result<Void, AssistantsAPIError>) -> Void) {
        self.onData = onData
        self.onComplete = onComplete
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        AssistantsLogger.log("Audio chunk received: \(data.count) bytes")
        onData(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            AssistantsLogger.log("Audio stream error: \(error.localizedDescription)")
            onComplete(.failure(.requestFailed(message: error.localizedDescription)))
        } else {
            AssistantsLogger.log("Audio stream completed successfully")
            onComplete(.success(()))
        }
    }
}
