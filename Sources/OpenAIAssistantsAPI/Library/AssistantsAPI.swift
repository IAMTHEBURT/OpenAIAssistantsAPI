//
//  AssistantsAPI.swift
//  OpenAIAssistantsAPI
//
//  Created by Ivan Lvov on 23.05.2024.
//

import Foundation
import AVFoundation

public enum AssistantsAPIError: Error {
    case invalidURL
    case networkError
    case serializationError
    case decodingFailed(message: String)
    case requestFailed(message: String)
    case invalidResponse(message: String)
}

public class AssistantsAPI: NSObject, URLSessionDataDelegate {
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession
    private var urlSession: URLSession!
    public static var debugLoggingEnabled: Bool = true

    public init(baseUrl: String = "https://api.openai.com/v1", apiKey: String, enableDebugLogging: Bool = true) {
        baseURL = baseUrl
        self.apiKey = apiKey
        session = URLSession.shared
        super.init()
        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        AssistantsLogger.debugLoggingEnabled = enableDebugLogging
    }

    public func createThread(
        messages: [ThreadMessage]? = nil,
        attachments: [Attachment]? = nil,
        toolResources: ToolResources? = nil,
        metadata: [String: String]? = nil,
        completion: @escaping (Result<ThreadResponse, AssistantsAPIError>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/threads") else {
            completion(.failure(.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let threadRequest = ThreadRequest(
            messages: messages,
            attachments: attachments,
            metadata: metadata,
            tool_resources: toolResources
        )

        do {
            request.httpBody = try JSONEncoder().encode(threadRequest)
        } catch {
            completion(.failure(.serializationError))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? error.localizedDescription
                completion(.failure(.requestFailed(message: errorMessage)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 299).contains(httpResponse.statusCode)
            else {
                let serverMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Invalid server response"
                completion(.failure(.invalidResponse(message: serverMessage)))
                return
            }

            do {
                let threadResponse = try JSONDecoder().decode(ThreadResponse.self, from: data!)
                completion(.success(threadResponse))
            } catch {
                let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Decoding error"
                completion(.failure(.decodingFailed(message: errorMessage)))
            }
        }.resume()
    }

    public func createMessage(
        to thread: AssistantsThread,
        role: Role,
        content: [ContentPart],
        attachments: [Attachment]? = nil,
        metadata: [String: String]? = nil,
        completion: @escaping (Result<AssistantsMessage, AssistantsAPIError>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/threads/\(thread.id)/messages") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let messageRequest = ThreadMessage(role: role, content: content, attachments: attachments, metadata: metadata)
        do {
            request.httpBody = try JSONEncoder().encode(messageRequest)
        } catch {
            completion(.failure(.serializationError))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? error.localizedDescription
                completion(.failure(.requestFailed(message: errorMessage)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 299).contains(httpResponse.statusCode)
            else {
                let serverMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Invalid server response"
                completion(.failure(.invalidResponse(message: serverMessage)))
                return
            }

            do {
                let messageDTO = try JSONDecoder().decode(AssistantsMessageDTO.self, from: data!)
                let message = AssistantsMessage(id: messageDTO.id, role: messageDTO.role, content: messageDTO.content.last?.text.value ?? "No content")
                completion(.success(message))
            } catch {
                let decodingErrorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Decoding error"
                completion(.failure(.decodingFailed(message: decodingErrorMessage)))
            }
        }.resume()
    }

    public func listMessages(from thread: AssistantsThread, limit: Int? = nil, order: String? = nil, after: String? = nil, before: String? = nil, run_id: String? = nil, completion: @escaping (Result<[AssistantsMessage], AssistantsAPIError>) -> Void) {
        var components = URLComponents(string: "\(baseURL)/threads/\(thread.id)/messages")
        var queryItems = [URLQueryItem]()
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let order = order { queryItems.append(URLQueryItem(name: "order", value: order)) }
        if let after = after { queryItems.append(URLQueryItem(name: "after", value: after)) }
        if let before = before { queryItems.append(URLQueryItem(name: "before", value: before)) }
        if let run_id = run_id { queryItems.append(URLQueryItem(name: "run_id", value: run_id)) }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? error.localizedDescription
                completion(.failure(.requestFailed(message: errorMessage)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 299).contains(httpResponse.statusCode)
            else {
                let serverMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Invalid server response"
                completion(.failure(.invalidResponse(message: serverMessage)))
                return
            }

            do {
                let list = try JSONDecoder().decode(MessageList.self, from: data!)
                let messages = list.data.map { messageDTO in
                    AssistantsMessage(
                        id: messageDTO.id,
                        role: messageDTO.role,
                        content: messageDTO.content.last?.text.value ?? "No content",
                        metadata: messageDTO.metadata
                    )
                }
                completion(.success(messages))
            } catch {
                let decodingErrorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Decoding error"
                completion(.failure(.decodingFailed(message: decodingErrorMessage)))
            }
        }.resume()
    }

    public func createRunStream(
        for thread: AssistantsThread,
        assistantId: String,
        model: String? = nil,
        instructions: String? = nil,
        additional_instructions: String? = nil,
        additional_messages: [ThreadMessage]? = nil,
        tools: [Tool]? = nil,
        temperature: Float? = nil,
        stream: Bool = true,
        max_prompt_tokens: Int? = nil,
        max_completion_tokens: Int? = nil,
        onPartialResponse: @escaping (String) -> Void,
        onSessionClosed: ((Result<Data, AssistantsAPIError>) -> Void)? = nil,
        onMessageCompleted: ((String) -> Void)? = nil,
        completion: @escaping (Result<Run, AssistantsAPIError>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/threads/\(thread.id)/runs") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        var runRequest: [String: Any] = [
            "assistant_id": assistantId,
            "instructions": instructions ?? "",
        ]

        if let model = model {
            runRequest["model"] = model
        }
        if let additional_instructions = additional_instructions {
            runRequest["additional_instructions"] = additional_instructions
        }
        if let additional_messages = additional_messages {
            runRequest["additional_messages"] = additional_messages.map { message in
                [
                    "role": message.role.rawValue,
                    "content": message.content.map { content in
                        var contentDict: [String: Any] = ["type": content.type.rawValue]
                        if let text = content.text {
                            contentDict["text"] = ["value": text]
                        }
                        if let image_url = content.image_url {
                            contentDict["image_url"] = image_url
                        }
                        if let image_file = content.image_file {
                            contentDict["image_file"] = image_file
                        }
                        return contentDict
                    },
                    "attachments": message.attachments?.map { attachment in
                        [
                            "file_id": attachment.file_id,
                            "tools": attachment.tools.map { $0.type },
                        ]
                    },
                ]
            }
        }
        if let tools = tools {
            runRequest["tools"] = tools.map { ["type": $0.type] }
        }
        if let temperature = temperature {
            runRequest["temperature"] = temperature
        }
        runRequest["stream"] = stream
        if let max_prompt_tokens = max_prompt_tokens {
            runRequest["max_prompt_tokens"] = max_prompt_tokens
        }
        if let max_completion_tokens = max_completion_tokens {
            runRequest["max_completion_tokens"] = max_completion_tokens
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: runRequest, options: [])
        } catch {
            completion(.failure(.serializationError))
            return
        }

        let streamDelegate = StreamDelegate()
        streamDelegate.onEvent = { event in
            switch event {
            case let .requestCompleted(result):
                onSessionClosed?(result)
            case let .messageDelta(message):
                guard let content = message.delta.content.first else { return }
                onPartialResponse(content.text.value)
            case let .messageCompleted(message):
                guard let content = message.content.first else { return }
                onMessageCompleted?(content.text.value)
            case let .runCompleted(run):
                completion(.success(run))
            default:
                AssistantsLogger.log("DEFAULT \(event.self)")
            }
        }

        let session = URLSession(configuration: .default, delegate: streamDelegate, delegateQueue: nil)
        streamDelegate.session = session
        let task = session.dataTask(with: request)
        task.resume()
    }

    public func createRun(
        for thread: AssistantsThread,
        assistantId: String,
        model: String? = nil,
        instructions: String? = nil,
        additional_instructions: String? = nil,
        additional_messages: [ThreadMessage]? = nil,
        tools: [Tool]? = nil,
        temperature: Float? = nil,
        stream: Bool = false,
        max_prompt_tokens: Int? = nil,
        max_completion_tokens: Int? = nil,
        completion: @escaping (Result<Run, AssistantsAPIError>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/threads/\(thread.id)/runs") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        var runRequest: [String: Any] = [
            "assistant_id": assistantId,
            "instructions": instructions ?? "",
        ]

        if let model = model {
            runRequest["model"] = model
        }
        if let additional_instructions = additional_instructions {
            runRequest["additional_instructions"] = additional_instructions
        }
        if let additional_messages = additional_messages {
            runRequest["additional_messages"] = additional_messages.map { message in
                [
                    "role": message.role.rawValue,
                    "content": message.content.map { content in
                        var contentDict: [String: Any] = ["type": content.type.rawValue]
                        if let text = content.text {
                            contentDict["text"] = ["value": text]
                        }
                        if let image_url = content.image_url {
                            contentDict["image_url"] = image_url
                        }
                        if let image_file = content.image_file {
                            contentDict["image_file"] = image_file
                        }
                        return contentDict
                    },
                    "attachments": message.attachments?.map { attachment in
                        [
                            "file_id": attachment.file_id,
                            "tools": attachment.tools.map { $0.type },
                        ]
                    },
                ]
            }
        }
        if let tools = tools {
            runRequest["tools"] = tools.map { ["type": $0.type] }
        }
        if let temperature = temperature {
            runRequest["temperature"] = temperature
        }
        runRequest["stream"] = stream
        if let max_prompt_tokens = max_prompt_tokens {
            runRequest["max_prompt_tokens"] = max_prompt_tokens
        }
        if let max_completion_tokens = max_completion_tokens {
            runRequest["max_completion_tokens"] = max_completion_tokens
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: runRequest, options: [])
        } catch {
            completion(.failure(.serializationError))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? error.localizedDescription
                completion(.failure(.requestFailed(message: errorMessage)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 299).contains(httpResponse.statusCode)
            else {
                let serverMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Invalid server response"
                completion(.failure(.invalidResponse(message: serverMessage)))
                return
            }

            do {
                let run = try JSONDecoder().decode(Run.self, from: data!)
                completion(.success(run))
            } catch {
                let decodingErrorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Decoding error"
                completion(.failure(.decodingFailed(message: decodingErrorMessage)))
            }
        }.resume()
    }

    public func getRun(threadID: String, runID: String, completion: @escaping (Result<Run, AssistantsAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/threads/\(threadID)/runs/\(runID)") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? error.localizedDescription
                completion(.failure(.requestFailed(message: errorMessage)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 299).contains(httpResponse.statusCode)
            else {
                let serverMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Invalid server response"
                completion(.failure(.invalidResponse(message: serverMessage)))
                return
            }

            do {
                let runStatus = try JSONDecoder().decode(Run.self, from: data!)
                completion(.success(runStatus))
            } catch {
                let decodingErrorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Decoding error"
                completion(.failure(.decodingFailed(message: decodingErrorMessage)))
            }
        }.resume()
    }
}

// MARK: - AUDIO

public extension AssistantsAPI {
    public func createSpeech(
        model: String = "tts-1",
        input: String,
        voice: Voice,
        responseFormat: String = "mp3",
        speed: Double? = nil,
        completion: @escaping (Result<AudioObject, AssistantsAPIError>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/audio/speech") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var speechRequest: [String: Any] = [
            "model": model,
            "input": input,
            "voice": voice.rawValue,
            "response_format": responseFormat
        ]

        if let speed = speed {
            speechRequest["speed"] = speed
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: speechRequest, options: [])
        } catch {
            completion(.failure(.serializationError))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? error.localizedDescription
                completion(.failure(.requestFailed(message: errorMessage)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse(message: "Invalid server response")))
                return
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                let serverMessage = String(data: data ?? Data(), encoding: .utf8) ?? "HTTP Error: \(httpResponse.statusCode)"
                completion(.failure(.invalidResponse(message: serverMessage)))
                return
            }

            guard let responseData = data else {
                completion(.failure(.invalidResponse(message: "No data received")))
                return
            }

            do {
                let audioPlayer = try AVAudioPlayer(data: responseData)
                let audioResult = AudioSpeechResult(audio: responseData)
                let audioObject = AudioObject(
                    prompt: input,
                    audioPlayer: audioPlayer,
                    originResponse: audioResult,
                    format: responseFormat
                )
                completion(.success(audioObject))
            } catch {
                completion(.failure(.requestFailed(message: "Failed to create AVAudioPlayer: \(error.localizedDescription)")))
            }
        }.resume()
    }

    @available(iOS 13.0, *)
    public func createSpeechStreamAsync(
        model: String = "tts-1",
        input: String,
        voice: Voice,
        speed: Double = 1.0,
        responseFormat: String = "mp3"
    ) -> AsyncThrowingStream<AudioSpeechResult, Error> {
        var task: URLSessionDataTask? = nil

        return AsyncThrowingStream { continuation in
            guard let url = URL(string: "\(baseURL)/audio/speech") else {
                continuation.finish(throwing: AssistantsAPIError.invalidURL)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "model": model,
                "input": input,
                "voice": voice.rawValue,
                "response_format": responseFormat,
                "speed": speed
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                continuation.finish(throwing: AssistantsAPIError.serializationError)
                return
            }

            let delegate = AudioStreamDelegate(
                onData: { chunk in
                    continuation.yield(AudioSpeechResult(audio: chunk))
                },
                onComplete: { result in
                    switch result {
                    case .success:
                        continuation.finish()
                    case .failure(let error):
                        continuation.finish(throwing: error)
                    }
                }
            )

            let streamSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            task = streamSession.dataTask(with: request)
            task?.resume()

            continuation.onTermination = { _ in
                task?.cancel()
            }
        }
    }


    public func createSpeechStream(
        model: String = "tts-1",
        input: String,
        voice: Voice,
        speed: Double? = nil,
        responseFormat: String = "pcm", // opus
        onData: @escaping (Data) -> Void,
        onComplete: @escaping (Result<Void, AssistantsAPIError>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/audio/speech") else {
            onComplete(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "input": input,
            "voice": voice.rawValue,
            "response_format": responseFormat,
            "speed": speed ?? 1.0
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            onComplete(.failure(.serializationError))
            return
        }

        let delegate = AudioStreamDelegate(onData: onData, onComplete: onComplete)
        let streamSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = streamSession.dataTask(with: request)
        task.resume()
    }

    func createTranscription(
        file: Data,
        model: String = "whisper-1",
        language: String? = nil,
        prompt: String? = nil,
        responseFormat: String? = nil,
        temperature: Double? = nil,
        timestampGranularities: [String]? = nil,
        completion: @escaping (Result<TranscriptionResponse, AssistantsAPIError>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/audio/transcriptions") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(file)
        body.append("\r\n".data(using: .utf8)!)

        let parameters: [String: Any] = [
            "model": model,
            "language": language ?? "",
            "prompt": prompt ?? "",
            "response_format": responseFormat ?? "json",
            "temperature": temperature ?? 0,
            "timestamp_granularities": timestampGranularities?.joined(separator: ",") ?? "",
        ]

        for (key, value) in parameters {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? error.localizedDescription
                completion(.failure(.requestFailed(message: errorMessage)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                let serverMessage = "Invalid server response"
                completion(.failure(.invalidResponse(message: serverMessage)))
                return
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                let serverMessage = String(data: data ?? Data(), encoding: .utf8) ?? "HTTP Error: \(httpResponse.statusCode)"
                completion(.failure(.invalidResponse(message: serverMessage)))
                return
            }

            do {
                let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data!)
                completion(.success(transcriptionResponse))
            } catch {
                let decodingErrorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Decoding error"
                completion(.failure(.decodingFailed(message: decodingErrorMessage)))
            }
        }.resume()
    }
}

public enum AssistantsLogger {
    public static var debugLoggingEnabled: Bool = true

    public static func log(_ message: @autoclosure () -> String) {
        if debugLoggingEnabled {
            print("🔹[AssistantsAPI] \(message())")
        }
    }
}
