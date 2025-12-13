#include "NDP.h"
#include <ArduinoBLE.h>

//const bool lowestPower = true;
const bool lowestPower = false;

// BLE Service and Characteristic
// Custom UUID for Alexa detection service
BLEService alexaService("19B10000-E8F2-537E-4F6C-D104768A1214");
// Characteristic for sending event notifications to iPhone
BLEStringCharacteristic eventChar("19B10001-E8F2-537E-4F6C-D104768A1214", 
                                   BLERead | BLENotify, 50);

// Connection state tracking
volatile bool isConnected = false;

// BLE Event Handlers
void onConnect(BLEDevice central) {
  isConnected = true;
  if (!lowestPower) {
    Serial.print("✅ Connected to central: ");
    Serial.println(central.address());
  }
  nicla::leds.begin();
  nicla::leds.setColor(green);
  delay(100);
  nicla::leds.setColor(off);
  nicla::leds.end();
}

void onDisconnect(BLEDevice central) {
  isConnected = false;
  if (!lowestPower) {
    Serial.print("❌ Disconnected from central: ");
    Serial.println(central.address());
  }
  BLE.advertise(); // IMPORTANT: Resume advertising after disconnect
}

void ledBlueOn(char* label) {
  nicla::leds.begin();
  nicla::leds.setColor(blue);
  delay(200);
  nicla::leds.setColor(off);
  
  // Send notification via BLE if connected
  if (isConnected) {
    String message = "MATCH: ";
    message += label;
    eventChar.writeValue(message);
    if (!lowestPower) {
      Serial.print("📤 Sent BLE: ");
      Serial.println(message);
    }
  }
  
  if (!lowestPower) {
    Serial.println(label);
  }
  nicla::leds.end();
}

void ledGreenOn() {
  nicla::leds.begin();
  nicla::leds.setColor(green);
  delay(200);
  nicla::leds.setColor(off);
  
  // Send notification via BLE if connected
  if (isConnected) {
    eventChar.writeValue("EVENT: NDP Event Detected");
    if (!lowestPower) {
      Serial.println("📤 Sent BLE: EVENT: NDP Event Detected");
    }
  }
  
  nicla::leds.end();
}

void ledRedBlink() {
  while (1) {
    nicla::leds.begin();
    nicla::leds.setColor(red);
    delay(200);
    nicla::leds.setColor(off);
    delay(200);
    nicla::leds.end();
  }
}

void setup() {
  Serial.begin(115200);
  nicla::begin();
  nicla::disableLDO();
  nicla::leds.begin();

  if (!lowestPower) {
    while (!Serial && millis() < 3000) {} // Wait for serial, but not forever
  }

  // Initialize BLE
  if (!BLE.begin()) {
    Serial.println("❌ Starting BLE failed!");
    ledRedBlink(); // Error indication
  }

  // ⭐ CRITICAL: Set Apple-friendly connection intervals (15-30ms)
  BLE.setConnectionInterval(12, 24); // 12*1.25ms = 15ms, 24*1.25ms = 30ms
  
  // Set BLE device name and advertised service
  BLE.setLocalName("Alexa Nicla");
  BLE.setDeviceName("Alexa Nicla Voice");
  BLE.setAdvertisedService(alexaService);
  
  // Add characteristic to service and add service
  alexaService.addCharacteristic(eventChar);
  BLE.addService(alexaService);
  
  // ⭐ Set up event handlers (instead of polling in loop)
  BLE.setEventHandler(BLEConnected, onConnect);
  BLE.setEventHandler(BLEDisconnected, onDisconnect);
  
  // Set initial value
  eventChar.writeValue("Alexa Nicla Ready");
  
  // Start advertising
  BLE.advertise();
  Serial.println("🔵 BLE device active, waiting for connections...");
  Serial.println("📡 Advertising as 'Alexa Nicla Voice'");

  // Setup NDP
  NDP.onError(ledRedBlink);
  NDP.onMatch(ledBlueOn);
  NDP.onEvent(ledGreenOn);
  Serial.println("⚙️  Loading synpackages...");
  NDP.begin("mcu_fw_120_v91.synpkg");
  NDP.load("dsp_firmware_v91.synpkg");
  NDP.load("ei_model.synpkg");
  Serial.println("✅ Packages loaded");
  NDP.getInfo();
  Serial.println("🎤 Configuring microphone...");
  NDP.turnOnMicrophone();
  NDP.interrupts();
  Serial.println("✅ Ready! Say 'Alexa' to test.");

  // For maximum low power; please note that it's impossible to print after calling these functions
  nicla::leds.end();
  if (lowestPower) {
    NRF_UART0->ENABLE = 0;
  }
  //NDP.turnOffMicrophone();
}

void loop() {
  // ⭐ CRITICAL: Poll BLE stack to keep connection responsive
  BLE.poll();
  
  // Handle serial commands (works both connected and disconnected)
  if (Serial.available()) {
    uint8_t command = Serial.read();
    if (command == 'f') {
      Serial.println("⏸️  Interrupts disabled");
      NDP.noInterrupts();
      if (isConnected) {
        eventChar.writeValue("CMD: Interrupts disabled");
      }
    } else if (command == 'o') {
      Serial.println("▶️  Interrupts enabled");
      NDP.interrupts();
      if (isConnected) {
        eventChar.writeValue("CMD: Interrupts enabled");
      }
    } else if (command == 't') {
      // Test message
      Serial.println("📤 Sending test message...");
      if (isConnected) {
        eventChar.writeValue("TEST: Hello from Nicla!");
        Serial.println("✅ Test message sent");
      } else {
        Serial.println("⚠️  Not connected!");
      }
    }
  }
  
  // Small delay to prevent tight loop and reduce power
  delay(10);
}

