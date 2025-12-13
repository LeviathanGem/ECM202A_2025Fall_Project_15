//
//  BLEManager.swift
//  OdysseyTest
//
//  Manages Bluetooth connection to Alexa Nicla device
//

import Foundation
import CoreBluetooth
import SwiftUI

class BLEManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectionStatus = "Disconnected"
    @Published var lastMessage = ""
    
    // MARK: - BLE Properties
    private var centralManager: CBCentralManager!
    private var niclaPeripheral: CBPeripheral?
    private var eventCharacteristic: CBCharacteristic?
    private var shouldAutoReconnect = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    
    // UUIDs matching the Arduino code
    private let alexaServiceUUID = CBUUID(string: "19B10000-E8F2-537E-4F6C-D104768A1214")
    private let eventCharUUID = CBUUID(string: "19B10001-E8F2-537E-4F6C-D104768A1214")
    
    // Callback for event detection
    var onEventReceived: ((String) -> Void)?
    
    // MARK: - Initialization
    override init() {
        super.init()
        print("🔵 BLEManager: Initializing...")
        // Create central manager with explicit main queue
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        print("🔵 BLEManager: Central manager created with delegate: \(String(describing: self))")
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        print("🔵 BLE: startScanning() called")
        print("🔵 BLE: Central manager state: \(centralManager.state.rawValue)")
        
        guard centralManager.state == .poweredOn else {
            print("🔵 BLE: ❌ Cannot scan - Bluetooth not powered on!")
            connectionStatus = "Bluetooth not ready"
            return
        }
        
        discoveredDevices.removeAll()
        isScanning = true
        connectionStatus = "Scanning..."
        
        print("🔵 BLE: Starting scan for service UUID: \(alexaServiceUUID)")
        
        // Scan for devices advertising the Alexa service
        centralManager.scanForPeripherals(
            withServices: [alexaServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        print("🔵 BLE: Scan started - will timeout in 10 seconds")
        
        // Auto-stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.isScanning == true {
                self?.stopScanning()
            }
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        if !isConnected {
            connectionStatus = "Scan complete"
        }
    }
    
    func connect(to peripheral: CBPeripheral) {
        print("🔵 BLE: connect() called for \(peripheral.name ?? "unknown")")
        print("🔵 BLE: Peripheral UUID: \(peripheral.identifier)")
        print("🔵 BLE: Peripheral state: \(peripheral.state.rawValue)")
        print("🔵 BLE: Central manager delegate: \(String(describing: centralManager.delegate))")
        
        stopScanning()
        
        // Cancel any existing connection first
        if let existing = niclaPeripheral {
            print("🔵 BLE: Cancelling existing connection...")
            centralManager.cancelPeripheralConnection(existing)
        }
        
        niclaPeripheral = peripheral
        peripheral.delegate = self
        shouldAutoReconnect = true
        reconnectAttempts = 0
        connectionStatus = "Connecting..."
        
        print("🔵 BLE: Set peripheral delegate to: \(String(describing: peripheral.delegate))")
        
        // Simpler connection options
        let options: [String: Any] = [:]
        
        print("🔵 BLE: Calling centralManager.connect()...")
        print("🔵 BLE: Central manager: \(centralManager)")
        centralManager.connect(peripheral, options: options)
        print("🔵 BLE: Connect call completed, waiting for callback...")
        
        // Add timeout detection
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self else { return }
            if !self.isConnected && self.niclaPeripheral != nil {
                print("🔵 BLE: ⚠️⚠️⚠️ CONNECTION TIMEOUT - No callback received after 10 seconds!")
                print("🔵 BLE: Peripheral state now: \(peripheral.state.rawValue)")
                print("🔵 BLE: isConnected: \(self.isConnected)")
                print("🔵 BLE: This indicates a CoreBluetooth delegate issue")
                
                // Force disconnect and clear
                self.centralManager.cancelPeripheralConnection(peripheral)
                self.niclaPeripheral = nil
                self.connectionStatus = "Connection timeout - try again"
            }
        }
    }
    
    func disconnect() {
        guard let peripheral = niclaPeripheral else { return }
        shouldAutoReconnect = false
        reconnectAttempts = 0
        centralManager.cancelPeripheralConnection(peripheral)
        connectionStatus = "Disconnecting..."
    }
    
    func sendCommand(_ command: String) {
        // Future feature: send commands to Arduino if needed
        print("Command sending not yet implemented: \(command)")
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("🔵 BLE: Central manager state changed: \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            print("🔵 BLE: ✅ Bluetooth is POWERED ON and ready!")
            connectionStatus = "Bluetooth ready"
        case .poweredOff:
            print("🔵 BLE: ❌ Bluetooth is OFF")
            connectionStatus = "Bluetooth is off"
        case .unauthorized:
            print("🔵 BLE: ⚠️ Bluetooth UNAUTHORIZED")
            connectionStatus = "Bluetooth unauthorized"
        case .unsupported:
            print("🔵 BLE: ❌ Bluetooth NOT SUPPORTED")
            connectionStatus = "Bluetooth not supported"
        default:
            print("🔵 BLE: ⚠️ Bluetooth state: \(central.state.rawValue)")
            connectionStatus = "Bluetooth unavailable"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("🔵 BLE: Discovered device - Name: \(peripheral.name ?? "nil"), RSSI: \(RSSI)")
        
        // Check if this is the Alexa Nicla device
        if let name = peripheral.name, name.contains("Alexa Nicla") {
            print("🔵 BLE: ✅ Found Alexa Nicla device: \(name)")
            if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredDevices.append(peripheral)
                connectionStatus = "Found: \(name)"
                print("🔵 BLE: Added to discovered devices list")
            } else {
                print("🔵 BLE: Already in list, skipping")
            }
        } else {
            print("🔵 BLE: Not an Alexa Nicla device, ignoring")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("🔵 BLE: ✅✅✅ didConnect CALLBACK FIRED! ✅✅✅")
        print("🔵 BLE: Connected to \(peripheral.name ?? "device") - \(peripheral.identifier)")
        isConnected = true
        reconnectAttempts = 0
        connectionStatus = "Connected"
        
        peripheral.delegate = self
        print("🔵 BLE: Discovering services...")
        peripheral.discoverServices([alexaServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("BLE: ❌ Disconnected from \(peripheral.name ?? "device")")
        isConnected = false
        eventCharacteristic = nil
        
        if let error = error {
            print("BLE: ⚠️ Disconnection error: \(error.localizedDescription)")
            print("BLE: Error domain: \((error as NSError).domain), code: \((error as NSError).code)")
            connectionStatus = "Disconnected (error)"
        } else {
            print("BLE: ℹ️ Disconnected normally (no error)")
            connectionStatus = "Disconnected"
        }
        
        // TEMPORARILY DISABLED: Auto-reconnect for debugging
        // Uncomment after we figure out what's causing disconnects
        /*
        if shouldAutoReconnect && reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            connectionStatus = "Reconnecting... (attempt \(reconnectAttempts)/\(maxReconnectAttempts))"
            print("BLE: Auto-reconnect attempt \(reconnectAttempts)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self, let peripheral = self.niclaPeripheral else { return }
                self.centralManager.connect(peripheral, options: [
                    CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                    CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
                ])
            }
        } else {
            if reconnectAttempts >= maxReconnectAttempts {
                connectionStatus = "Failed to reconnect"
                print("BLE: Max reconnection attempts reached")
            }
            niclaPeripheral = nil
        }
        */
        
        // For now, just clear the peripheral
        niclaPeripheral = nil
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("🔵 BLE: ❌ didFailToConnect callback fired!")
        isConnected = false
        
        if let error = error {
            print("🔵 BLE: Connection error: \(error.localizedDescription)")
            print("🔵 BLE: Error domain: \((error as NSError).domain), code: \((error as NSError).code)")
            connectionStatus = "Connection failed: \(error.localizedDescription)"
        } else {
            print("🔵 BLE: Connection failed with no error")
            connectionStatus = "Connection failed"
        }
        
        // Try auto-reconnect
        if shouldAutoReconnect && reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            connectionStatus = "Retrying... (\(reconnectAttempts)/\(maxReconnectAttempts))"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self, let peripheral = self.niclaPeripheral else { return }
                self.centralManager.connect(peripheral, options: nil)
            }
        } else {
            if reconnectAttempts >= maxReconnectAttempts {
                connectionStatus = "Failed after \(maxReconnectAttempts) attempts"
            }
            niclaPeripheral = nil
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("BLE: ❌ Error discovering services: \(error.localizedDescription)")
            return
        }
        
        print("BLE: Discovered \(peripheral.services?.count ?? 0) services")
        
        // Find the Alexa service
        if let service = peripheral.services?.first(where: { $0.uuid == alexaServiceUUID }) {
            print("BLE: ✅ Found Alexa service, discovering characteristics...")
            peripheral.discoverCharacteristics([eventCharUUID], for: service)
        } else {
            print("BLE: ⚠️ Alexa service not found!")
            if let services = peripheral.services {
                for service in services {
                    print("BLE:   Available service: \(service.uuid)")
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("BLE: ❌ Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        print("BLE: Discovered \(service.characteristics?.count ?? 0) characteristics")
        
        // Find the event characteristic
        if let characteristic = service.characteristics?.first(where: { $0.uuid == eventCharUUID }) {
            eventCharacteristic = characteristic
            
            print("BLE: ✅ Found event characteristic")
            print("BLE: Properties: \(characteristic.properties)")
            
            // Subscribe to notifications
            peripheral.setNotifyValue(true, for: characteristic)
            print("BLE: Subscribing to notifications...")
            
            // Read initial value
            peripheral.readValue(for: characteristic)
            print("BLE: Reading initial value...")
        } else {
            print("BLE: ⚠️ Event characteristic not found!")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error reading characteristic: \(error!.localizedDescription)")
            return
        }
        
        // Parse the received data
        if characteristic.uuid == eventCharUUID,
           let data = characteristic.value,
           let message = String(data: data, encoding: .utf8) {
            
            DispatchQueue.main.async { [weak self] in
                self?.lastMessage = message
                self?.onEventReceived?(message)
            }
            
            print("Received BLE message: \(message)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("BLE: ❌ Error changing notification state: \(error.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            print("BLE: ✅ Notifications enabled - ready to receive events!")
            connectionStatus = "Connected & ready"
        } else {
            print("BLE: ⚠️ Notifications disabled")
        }
    }
}

