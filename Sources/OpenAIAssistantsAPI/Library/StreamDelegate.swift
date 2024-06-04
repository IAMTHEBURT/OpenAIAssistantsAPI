//
//  StreamDelegate.swift
//  CooksMate
//
//  Created by Ivan Lvov on 26.05.2024.
//

import Foundation

class StreamDelegate: NSObject, URLSessionDataDelegate {
    var onEvent: ((StreamEvent) -> Void)?
    private var receivedData = Data()
    private var currentEvent: String?

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        let responseString = String(data: data, encoding: .utf8) ?? ""
        receivedData.append(data)
        
        if responseString.contains("\"error\":") {
            do {
                let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                let errorMessage = errorResponse.error.message
                onEvent?(.requestCompleted(.failure(.requestFailed(message: errorMessage))))
            } catch {
                onEvent?(.requestCompleted(.failure(.requestFailed(message: "Failed to decode error"))))
            }
        } else {
            responseString.enumerateLines { line, _ in
                if line.hasPrefix("event: ") {
                    self.currentEvent = line.replacingOccurrences(of: "event: ", with: "")
                } else if line.hasPrefix("data: ") {
                    let jsonString = line.replacingOccurrences(of: "data: ", with: "")
                    guard let jsonData = jsonString.data(using: .utf8) else { return }
                    self.handleEvent(eventType: self.currentEvent, data: jsonData)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            onEvent?(.requestCompleted(.failure(.requestFailed(message: "Error"))))
        } else {
            onEvent?(.requestCompleted(.success(receivedData)))
        }
        session.finishTasksAndInvalidate()
    }

    private func handleEvent(eventType: String?, data: Data) {
        guard let eventType = eventType else { return }
        do {
            switch eventType {
            case "thread.run.created":
                let run = try JSONDecoder().decode(Run.self, from: data)
                onEvent?(.runCreated(run))
            case "thread.run.queued":
                let run = try JSONDecoder().decode(Run.self, from: data)
                onEvent?(.runQueued(run))
            case "thread.run.in_progress":
                let run = try JSONDecoder().decode(Run.self, from: data)
                onEvent?(.runInProgress(run))
            case "thread.run.completed":
                let run = try JSONDecoder().decode(Run.self, from: data)
                onEvent?(.runCompleted(run))
            case "thread.run.step.created":
                let runStep = try JSONDecoder().decode(RunStep.self, from: data)
                onEvent?(.runStepCreated(runStep))
            case "thread.run.step.in_progress":
                let runStep = try JSONDecoder().decode(RunStep.self, from: data)
                onEvent?(.runStepInProgress(runStep))
            case "thread.run.step.completed":
                let runStep = try JSONDecoder().decode(RunStep.self, from: data)
                onEvent?(.runStepCompleted(runStep))
            case "thread.message.created":
                let message = try JSONDecoder().decode(AssistantsMessageDTO.self, from: data)
                onEvent?(.messageCreated(message))
            case "thread.message.in_progress":
                let message = try JSONDecoder().decode(AssistantsMessageDTO.self, from: data)
                onEvent?(.messageInProgress(message))
            case "thread.message.completed":
                let message = try JSONDecoder().decode(AssistantsMessageDTO.self, from: data)
                onEvent?(.messageCompleted(message))
            case "thread.message.delta":
                let messageDelta = try JSONDecoder().decode(AssistantsMessageDelta.self, from: data)
                onEvent?(.messageDelta(messageDelta))
            default: print("Default event \(eventType) is ignoring")
            }
        } catch {
            print("Error handling event: \(error)")
        }
    }
}

enum StreamEvent {
    case messageCreated(AssistantsMessageDTO)
    case messageInProgress(AssistantsMessageDTO)
    case messageCompleted(AssistantsMessageDTO)
    case messageDelta(AssistantsMessageDelta)
    case runCreated(Run)
    case runQueued(Run)
    case runInProgress(Run)
    case runCompleted(Run)
    case runStepCreated(RunStep)
    case runStepInProgress(RunStep)
    case runStepCompleted(RunStep)
    case requestCompleted(Result<Data, AssistantsAPIError>)
}

struct ErrorResponse: Codable {
    let error: ErrorDetail
}

struct ErrorDetail: Codable {
    let message: String
    let type: String?
    let param: String?
    let code: String?
}
