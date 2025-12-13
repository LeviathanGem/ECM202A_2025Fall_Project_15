//
//  ModelDownloader.swift
//  OdysseyTest
//
//  Downloads and manages LLM model files
//

import Foundation

class ModelDownloader: NSObject, ObservableObject {
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadError: String?
    @Published var isModelReady = LLMConfig.isModelDownloaded
    
    private var downloadTask: URLSessionDownloadTask?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    // MARK: - Download Model
    
    func downloadModel() {
        guard !isDownloading else { return }
        
        // Check if already downloaded
        if LLMConfig.isModelDownloaded {
            print("Model already downloaded")
            isModelReady = true
            return
        }
        
        guard let url = URL(string: LLMConfig.modelURL) else {
            downloadError = "Invalid model URL"
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        downloadError = nil
        
        downloadTask = urlSession.downloadTask(with: url)
        downloadTask?.resume()
        
        print("Starting model download...")
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        isDownloading = false
        downloadProgress = 0.0
    }
    
    // MARK: - Delete Model
    
    func deleteModel() {
        do {
            if FileManager.default.fileExists(atPath: LLMConfig.modelPath.path) {
                try FileManager.default.removeItem(at: LLMConfig.modelPath)
                isModelReady = false
                print("Model deleted")
            }
        } catch {
            print("Error deleting model: \(error)")
        }
    }
    
    // MARK: - Model Info
    
    func getModelSize() -> String {
        guard LLMConfig.isModelDownloaded else {
            return "Not downloaded"
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: LLMConfig.modelPath.path)
            if let fileSize = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            }
        } catch {
            print("Error getting file size: \(error)")
        }
        
        return "Unknown"
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloader: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            // Move downloaded file to documents directory
            let destinationURL = LLMConfig.modelPath
            
            // Remove if exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            DispatchQueue.main.async {
                self.isDownloading = false
                self.isModelReady = true
                self.downloadProgress = 1.0
                print("Model download completed!")
            }
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.downloadError = "Failed to save model: \(error.localizedDescription)"
                print("Error saving model: \(error)")
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            self.downloadProgress = progress
            
            // Log progress every 10%
            if Int(progress * 100) % 10 == 0 {
                let mb = Double(totalBytesWritten) / 1_000_000
                print(String(format: "Download progress: %.0f%% (%.0f MB)", progress * 100, mb))
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.downloadError = error.localizedDescription
                print("Download error: \(error)")
            }
        }
    }
}

