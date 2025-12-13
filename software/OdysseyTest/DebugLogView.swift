//
//  DebugLogView.swift
//  OdysseyTest
//
//  Simple in-app viewer to inspect logs and adjust log level.
//

import SwiftUI

struct DebugLogView: View {
    @ObservedObject var logger = DebugLogger.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLevel: LogLevel = DebugLogger.shared.currentLevel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                levelPicker
                
                List(logger.entries.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.level.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(levelColor(entry.level).opacity(0.2))
                                .foregroundColor(levelColor(entry.level))
                                .cornerRadius(6)
                            
                            Text(entry.category)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text(entry.message)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
                
                HStack {
                    Button("Clear") {
                        logger.clear()
                    }
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                }
                .padding()
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: selectedLevel) { newValue in
            logger.setLevel(newValue)
        }
    }
    
    private var levelPicker: some View {
        Picker("Log level", selection: $selectedLevel) {
            ForEach(LogLevel.allCases) { level in
                Text(level.rawValue).tag(level)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .error: return .red
        case .warn: return .orange
        case .info: return .blue
        case .debug: return .gray
        }
    }
}

