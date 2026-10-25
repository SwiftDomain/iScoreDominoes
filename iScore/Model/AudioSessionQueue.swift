//
//  AudioSessionQueue.swift
//  iScore
//
//  Every call that talks to the audio server — activating or deactivating
//  the shared session, starting or stopping the engine — runs here, off the
//  main thread. Those calls block on the server, and on the main thread they
//  freeze the UI (Xcode's "AVAudioSession Hang Risk"). One serial queue keeps
//  them in order, so a stop is never overtaken by the next start.
//

import Foundation

enum AudioSessionQueue {

    private static let queue = DispatchQueue(label: "SwiftDomainUI.iScore.audio-session", qos: .userInitiated)

    /// Runs `work` on the queue and waits for it, rethrowing its error.
    static func run(_ work: @escaping @Sendable () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try work()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Runs `work` on the queue without waiting: teardown, which nobody waits on.
    static func enqueue(_ work: @escaping @Sendable () -> Void) {
        queue.async(execute: work)
    }
}

/// Hands a non-Sendable audio object to the queue. Safe because only the
/// queue touches it once it is handed over.
struct AudioHandoff<Value>: @unchecked Sendable {
    let value: Value
}
