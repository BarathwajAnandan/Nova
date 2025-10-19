//
//  SpeechSynthesisService.swift
//  nova
//
//  Provides text-to-speech playback for chat replies using macOS voices.
//

import Foundation
import AppKit

/// Simple wrapper around `NSSpeechSynthesizer` for one-shot playback.
final class SpeechSynthesisService: NSObject {
    private let synthesizer: NSSpeechSynthesizer

    override init() {
        synthesizer = NSSpeechSynthesizer()
        super.init()
        synthesizer.delegate = self
        configureDefaultVoice()
    }

    /// Stops any current utterance and speaks the supplied text.
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            stop()
            return
        }

        runOnMain {
            if self.synthesizer.isSpeaking {
                self.synthesizer.stopSpeaking()
            }
            self.synthesizer.startSpeaking(trimmed)
        }
    }

    /// Cancels any active speech.
    func stop() {
        runOnMain {
            if self.synthesizer.isSpeaking {
                self.synthesizer.stopSpeaking()
            }
        }
    }

    /// Allows callers to pick a specific macOS voice identifier. `nil` resets to default.
    func setVoice(_ identifier: NSSpeechSynthesizer.VoiceName?) {
        runOnMain {
            _ = self.synthesizer.setVoice(identifier)
        }
    }

    /// Adjusts playback rate (default 175 words per minute). Range roughly 90...720.
    func setRate(_ rate: Float) {
        runOnMain {
            self.synthesizer.rate = rate
        }
    }

    /// Adjusts playback volume (0.0 – 1.0).
    func setVolume(_ volume: Float) {
        runOnMain {
            self.synthesizer.volume = volume
        }
    }

    private func configureDefaultVoice() {
        let availableVoices = NSSpeechSynthesizer.availableVoices
        let preferred = availableVoices.first(where: { Self.voiceMatches($0, keyword: "Zoe (Premium)") })
            ?? availableVoices.first(where: { Self.voiceMatches($0, keyword: "samantha") })
        guard let voice = preferred else { return }
        _ = synthesizer.setVoice(voice)
    }

    private static func voiceMatches(_ voice: NSSpeechSynthesizer.VoiceName, keyword: String) -> Bool {
        let attributes = NSSpeechSynthesizer.attributes(forVoice: voice)
        let name = (attributes[.name] as? String) ?? ""
        let identifier = (attributes[.identifier] as? String) ?? voice.rawValue
        return name.localizedCaseInsensitiveContains(keyword) || identifier.localizedCaseInsensitiveContains(keyword)
    }

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

extension SpeechSynthesisService: NSSpeechSynthesizerDelegate {}


