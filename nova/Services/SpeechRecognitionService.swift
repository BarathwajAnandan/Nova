//
//  SpeechRecognitionService.swift
//  nova
//
//  Provides live microphone transcription via Apple's Speech framework.
//

import Foundation
import AVFoundation
import Speech

protocol SpeechRecognitionServiceDelegate: AnyObject {
    func speechService(_ svc: SpeechRecognitionService, didUpdatePartial text: String)
    func speechService(_ svc: SpeechRecognitionService, didFinishWith text: String)
    func speechService(_ svc: SpeechRecognitionService, didFail error: Error)
    func speechServiceDidChangeState(_ svc: SpeechRecognitionService, isRunning: Bool)
}

final class SpeechRecognitionService {
    weak var delegate: SpeechRecognitionServiceDelegate?
    var locale: Locale = Locale(identifier: "en-US")

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer? { SFSpeechRecognizer(locale: locale) }
    private var isCancelling: Bool = false

    private(set) var isRunning: Bool = false {
        didSet { delegate?.speechServiceDidChangeState(self, isRunning: isRunning) }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    func start() throws {
        guard isRunning == false else { return }
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw NSError(domain: "SpeechRecognitionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable"])
        }
        isCancelling = false

        #if os(iOS) || os(tvOS) || os(watchOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // No strict on-device requirement per plan; system decides
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    self.delegate?.speechService(self, didFinishWith: text)
                    self.stop()
                } else {
                    self.delegate?.speechService(self, didUpdatePartial: text)
                }
            } else if let error = error {
                if self.isCancelling {
                    // Ignore expected cancellation error triggered by user stop
                    self.isCancelling = false
                    return
                }
                self.delegate?.speechService(self, didFail: error)
                self.stop()
            }
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        isCancelling = true
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        #if os(iOS) || os(tvOS) || os(watchOS)
        do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) } catch {}
        #endif
        isRunning = false
    }
}


