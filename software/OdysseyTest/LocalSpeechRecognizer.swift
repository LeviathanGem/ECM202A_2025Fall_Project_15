//
//  LocalSpeechRecognizer.swift
//  OdysseyTest
//
//  Apple Speech Framework wrapper for on-device speech recognition
//

import Foundation
import Speech
import AVFoundation

class LocalSpeechRecognizer: ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var isAuthorized = false
    
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    var onTranscription: ((String) -> Void)?
    var onFinished: ((String) -> Void)?
    
    init() {
        // Initialize with device's preferred language
        speechRecognizer = SFSpeechRecognizer()
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.isAuthorized = true
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    self?.isAuthorized = false
                    print("Speech recognition not authorized: \(status)")
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() {
        let startTime = Date()
        
        guard isAuthorized else {
            TimestampUtility.log("ERROR: Speech recognition not authorized", category: "SpeechRecognizer")
            return
        }
        
        guard !isRecording else { return }
        
        TimestampUtility.log("Starting speech recognition...", category: "SpeechRecognizer")
        
        // Reset previous session
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // On-device recognition if available
        if #available(iOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        // Set up audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            print("Unable to create audio engine")
            return
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
            return
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                
                DispatchQueue.main.async {
                    self.transcribedText = transcription
                }
                
                TimestampUtility.log("Transcription update: \(transcription)", category: "SpeechRecognizer")
                
                // Callback for real-time updates
                self.onTranscription?(transcription)
                
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self.isRecording = false
                }
                
                // Callback for final transcription
                if isFinal {
                    let elapsed = TimestampUtility.elapsed(since: startTime)
                    TimestampUtility.logPerformance("Speech recognition completed", duration: elapsed)
                    TimestampUtility.log("Final transcription: \(self.transcribedText)", category: "SpeechRecognizer")
                    self.onFinished?(self.transcribedText)
                }
                
                if let error = error {
                    TimestampUtility.log("ERROR: Speech recognition error: \(error.localizedDescription)", category: "SpeechRecognizer")
                }
            }
        }
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.transcribedText = ""
        }
        
        let setupElapsed = TimestampUtility.elapsed(since: startTime)
        TimestampUtility.logPerformance("Speech recognition setup", duration: setupElapsed)
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        TimestampUtility.log("Stopping speech recognition", category: "SpeechRecognizer")
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // Trigger finished callback with final text
        onFinished?(transcribedText)
        
        TimestampUtility.log("Speech recognition stopped", category: "SpeechRecognizer")
    }
    
    func reset() {
        transcribedText = ""
    }
}

