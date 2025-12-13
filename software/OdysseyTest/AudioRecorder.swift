//
//  AudioRecorder.swift
//  OdysseyTest
//
//  Audio recording manager for capturing microphone input
//

import AVFoundation
import Foundation

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        let startTime = Date()
        guard !isRecording else { return }
        
        TimestampUtility.log("Starting audio recording...", category: "AudioRecorder")
        
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        guard let inputNode = inputNode else {
            TimestampUtility.log("ERROR: Audio input node not available", category: "AudioRecorder")
            return
        }
        
        // OpenAI Realtime API prefers PCM16 at 24kHz
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 24000,
            channels: 1,
            interleaved: false
        )
        
        guard let format = recordingFormat else {
            print("Failed to create audio format")
            return
        }
        
        // Install tap to capture audio
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Convert to desired format if needed
            if let convertedBuffer = self.convertBuffer(buffer, to: format) {
                self.onAudioBuffer?(convertedBuffer)
                
                // Calculate audio level for UI feedback
                self.calculateAudioLevel(buffer: buffer)
            }
        }
        
        audioEngine?.prepare()
        
        do {
            try audioEngine?.start()
            DispatchQueue.main.async {
                self.isRecording = true
            }
            let elapsed = TimestampUtility.elapsed(since: startTime)
            TimestampUtility.logPerformance("Audio recording start", duration: elapsed)
        } catch {
            TimestampUtility.log("ERROR: Failed to start audio engine: \(error.localizedDescription)", category: "AudioRecorder")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        TimestampUtility.log("Stopping audio recording", category: "AudioRecorder")
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }
        TimestampUtility.log("Audio recording stopped", category: "AudioRecorder")
    }
    
    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            return nil
        }
        
        let ratio = buffer.format.sampleRate / format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) / ratio)
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("Audio conversion error: \(error.localizedDescription)")
            return nil
        }
        
        if status == .error {
            return nil
        }
        
        return convertedBuffer
    }
    
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelDataValue[$0] }
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalized = max(0, min(1, (avgPower + 50) / 50))
        
        DispatchQueue.main.async {
            self.audioLevel = normalized
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }
}

