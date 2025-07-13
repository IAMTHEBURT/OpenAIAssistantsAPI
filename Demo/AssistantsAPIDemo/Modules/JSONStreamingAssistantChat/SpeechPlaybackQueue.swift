//
//  SpeechPlaybackQueue.swift
//  AssistantsAPIDemo
//
//  Created by Ivan Lvov on 04.06.2025.
//

import Foundation
import AVFoundation
import Combine
import ChunkedAudioPlayer
import OpenAIAssistantsAPI

enum PlaybackItem {
    case audioObject(AudioObject)
    case chunked(prompt: String, stream: AsyncThrowingStream<AudioSpeechResult, Error>)
}

@MainActor
final class SpeechPlaybackQueue: NSObject, AVAudioPlayerDelegate {
    private var queue: [PlaybackItem] = []
    private var isPlaying = false

    private var currentAVPlayer: AVPlayer?
    private var currentAVAudioPlayer: AVAudioPlayer?
    private var chunkedPlayer = AudioPlayer()
    private var chunkedCancellable: AnyCancellable?

    weak var delegate: SpeechPlaybackQueueDelegate?

    func enqueue(_ audio: AudioObject) {
        queue.append(.audioObject(audio))
        playNextIfNeeded()
    }


    func enqueueChunkedStream(prompt: String, speechStream: AsyncThrowingStream<AudioSpeechResult, Error>) {
        guard !queue.contains(where: {
            if case .chunked(let p, _) = $0 { return p == prompt } else { return false }
        }) else { return }

        queue.append(.chunked(prompt: prompt, stream: speechStream))
        playNextIfNeeded()
    }

    private func playNextIfNeeded() {
        guard !isPlaying, let next = queue.first else { return }

        switch next {
        case .audioObject(let audio):
            currentAVAudioPlayer = audio.audioPlayer
            currentAVAudioPlayer?.delegate = self
            currentAVAudioPlayer?.play()
            isPlaying = true
            delegate?.didStartPlaying(prompt: audio.prompt, duration: audio.audioPlayer.duration)

        case .chunked(let prompt, let stream):
            isPlaying = true
            delegate?.didStartPlaying(prompt: prompt, duration: 0)

            let dataStream = AsyncThrowingStream<Data, Error> { continuation in
                Task {
                    do {
                        for try await chunk in stream {
                            continuation.yield(chunk.audio)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }

            chunkedPlayer.start(dataStream, type: kAudioFileMP3Type)

            chunkedCancellable = chunkedPlayer.$currentState
                .sink { [weak self] state in
                    print(state)
                    guard let self else { return }

                    if state == AudioPlayerState.completed || state == .failed {
                        self.queue.removeFirst()
                        self.isPlaying = false
                        self.chunkedCancellable = nil
                        self.playNextIfNeeded()
                    }
                }
        }
    }

    @objc private func streamDidFinish(notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        queue.removeFirst()
        isPlaying = false
        currentAVPlayer = nil
        playNextIfNeeded()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.queue.removeFirst()
            self.isPlaying = false
            self.currentAVAudioPlayer = nil
            self.playNextIfNeeded()
        }
    }

    func clear() {
        queue.removeAll()
        currentAVPlayer?.pause()
        currentAVAudioPlayer?.stop()
        chunkedPlayer.stop()
        isPlaying = false
    }
}

protocol SpeechPlaybackQueueDelegate: AnyObject {
    func didStartPlaying(prompt: String, duration: TimeInterval)
}
