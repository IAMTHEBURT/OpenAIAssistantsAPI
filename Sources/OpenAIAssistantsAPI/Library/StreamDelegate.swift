//
//  StreamDelegate.swift
//  OpenAIAssistantsAPI
//
//  Created by Ivan Lvov on 26.05.2024.
//

import Foundation

class StreamDelegate: NSObject, URLSessionDataDelegate {
    var onEvent: ((StreamEvent) -> Void)?
    private var receivedData = Data()
    private var currentEvent: String?
    weak var session: URLSession?

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        let responseString = String(data: data, encoding: .utf8) ?? ""
        AssistantsLogger.log("Received data chunk: \(responseString.count) chars")

        receivedData.append(data)
        responseString.enumerateLines { line, _ in
            if line.hasPrefix("event: ") {
                self.currentEvent = line.replacingOccurrences(of: "event: ", with: "")
                AssistantsLogger.log("Event type: \(self.currentEvent ?? "unknown")")
            } else if line.hasPrefix("data: ") {
                let jsonString = line.replacingOccurrences(of: "data: ", with: "")
                AssistantsLogger.log("Data payload: \(jsonString.prefix(120))...") // обрезка для читаемости
                guard let jsonData = jsonString.data(using: .utf8) else {
                    AssistantsLogger.log("Failed to convert JSON string to Data")
                    return
                }
                self.handleEvent(eventType: self.currentEvent, data: jsonData)
            }
        }
    }

    func urlSession(_ session: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            AssistantsLogger.log("Session completed with error: \(error.localizedDescription)")
            onEvent?(.requestCompleted(.failure(.requestFailed(message: error.localizedDescription))))
        } else {
            AssistantsLogger.log("Session completed successfully. Total bytes: \(receivedData.count)")
            onEvent?(.requestCompleted(.success(receivedData)))
        }
        session.finishTasksAndInvalidate()
    }

    private func handleEvent(eventType: String?, data: Data) {
        guard let eventType = eventType else {
            AssistantsLogger.log("handleEvent called with nil eventType")
            return
        }

        do {
            switch eventType {
            case "thread.run.created":
                let run = try JSONDecoder().decode(Run.self, from: data)
                AssistantsLogger.log("Parsed thread.run.created")
                onEvent?(.runCreated(run))

            case "thread.run.queued":
                let run = try JSONDecoder().decode(Run.self, from: data)
                AssistantsLogger.log("Parsed thread.run.queued")
                onEvent?(.runQueued(run))

            case "thread.run.in_progress":
                let run = try JSONDecoder().decode(Run.self, from: data)
                AssistantsLogger.log("Parsed thread.run.in_progress")
                onEvent?(.runInProgress(run))

            case "thread.run.completed":
                let run = try JSONDecoder().decode(Run.self, from: data)
                AssistantsLogger.log("Parsed thread.run.completed")
                onEvent?(.runCompleted(run))
                session?.finishTasksAndInvalidate()

            case "thread.run.step.created":
                let step = try JSONDecoder().decode(RunStep.self, from: data)
                AssistantsLogger.log("Parsed thread.run.step.created")
                onEvent?(.runStepCreated(step))

            case "thread.run.step.in_progress":
                let step = try JSONDecoder().decode(RunStep.self, from: data)
                AssistantsLogger.log("Parsed thread.run.step.in_progress")
                onEvent?(.runStepInProgress(step))

            case "thread.run.step.completed":
                let step = try JSONDecoder().decode(RunStep.self, from: data)
                AssistantsLogger.log("Parsed thread.run.step.completed")
                onEvent?(.runStepCompleted(step))

            case "thread.message.created":
                let msg = try JSONDecoder().decode(AssistantsMessageDTO.self, from: data)
                AssistantsLogger.log("Parsed thread.message.created")
                onEvent?(.messageCreated(msg))

            case "thread.message.in_progress":
                let msg = try JSONDecoder().decode(AssistantsMessageDTO.self, from: data)
                AssistantsLogger.log("Parsed thread.message.in_progress")
                onEvent?(.messageInProgress(msg))

            case "thread.message.completed":
                let msg = try JSONDecoder().decode(AssistantsMessageDTO.self, from: data)
                AssistantsLogger.log("Parsed thread.message.completed")
                onEvent?(.messageCompleted(msg))

            case "thread.message.delta":
                let delta = try JSONDecoder().decode(AssistantsMessageDelta.self, from: data)
                AssistantsLogger.log("Parsed thread.message.delta")
                onEvent?(.messageDelta(delta))

            default:
                AssistantsLogger.log("Ignoring unknown event: \(eventType)")
            }
        } catch {
            AssistantsLogger.log("Failed to decode \(eventType): \(error)")
            if let jsonStr = String(data: data, encoding: .utf8) {
                AssistantsLogger.log("Raw payload: \(jsonStr)")
            }
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
