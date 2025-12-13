//
//  BLESettingsView.swift
//  OdysseyTest
//
//  Interface for connecting to Alexa Nicla via BLE
//

import SwiftUI

struct BLESettingsView: View {
    @ObservedObject var bleManager: BLEManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Bluetooth Connection")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(bleManager.connectionStatus)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                
                // Connected device info
                if bleManager.isConnected {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected to Alexa Nicla")
                                .font(.headline)
                        }
                        
                        if !bleManager.lastMessage.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Last message:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(bleManager.lastMessage)
                                    .font(.body)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        
                        Button(action: {
                            bleManager.disconnect()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Disconnect")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(15)
                } else {
                    // Scan button
                    Button(action: {
                        if bleManager.isScanning {
                            bleManager.stopScanning()
                        } else {
                            bleManager.startScanning()
                        }
                    }) {
                        HStack {
                            Image(systemName: bleManager.isScanning ? "stop.circle" : "magnifyingglass")
                            Text(bleManager.isScanning ? "Stop Scanning" : "Scan for Devices")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(bleManager.isScanning ? Color.orange : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    // Device list
                    if !bleManager.discoveredDevices.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Found Devices")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            List(bleManager.discoveredDevices, id: \.identifier) { peripheral in
                                Button(action: {
                                    bleManager.connect(to: peripheral)
                                }) {
                                    HStack {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading) {
                                            Text(peripheral.name ?? "Unknown Device")
                                                .font(.headline)
                                            Text(peripheral.identifier.uuidString)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    } else if bleManager.isScanning {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Searching for Alexa Nicla...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                }
                
                Spacer()
                
                // Info section
                VStack(alignment: .leading, spacing: 8) {
                    Text("📱 About BLE Integration")
                        .font(.headline)
                    
                    Text("Connect to your Alexa Nicla device to receive wake word detection events. When Alexa is detected by the Arduino, notifications will appear in the Events tab.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("BLE Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    BLESettingsView(bleManager: BLEManager())
}

