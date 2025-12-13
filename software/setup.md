# Setup Guide - Odyssey Companion

Complete installation and configuration guide.

---

## 📋 Prerequisites

### Required
- **macOS 14.0+** (for development)
- **Xcode 15.0+**
- **iOS Device** with iOS 17.0+ (simulator works but limited features)
- **OpenAI API Key** (for cloud mode)

### Optional
- **~2 GB free space** on iPhone (for local LLM)
- **Arduino Nicla Voice** (for BLE activity sensing)

---

## 🚀 Step-by-Step Installation

### Step 1: Clone Repository

```bash
git clone https://github.com/yourusername/OdysseyTest.git
cd OdysseyTest
```

### Step 2: Configure API Key

**A. Copy template:**
```bash
cp OdysseyTest/Config.swift.template OdysseyTest/Config.swift
```

**B. Edit `OdysseyTest/Config.swift`:**
```swift
static let openAIAPIKey = "sk-proj-your-actual-key-here"
```

**C. Get API key:**
- Visit: https://platform.openai.com/api-keys
- Create new secret key
- Copy and paste into Config.swift

**⚠️ Security:** Never commit `Config.swift` to version control!

### Step 3: Add Privacy Permissions

**Option A: Via Xcode UI**
1. Open `OdysseyTest.xcodeproj`
2. Select **OdysseyTest** target (blue app icon)
3. Go to **Info** tab
4. Click **+** button
5. Add these keys:

| Key | Value |
|-----|-------|
| `Privacy - Microphone Usage Description` | `"For voice interaction with AI assistant"` |
| `Privacy - Speech Recognition Usage Description` | `"For transcribing hydration-related requests"` |

**Option B: Via Info.plist**
Edit `OdysseyTest/Info.plist` and add:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>For voice interaction with AI assistant</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>For transcribing hydration-related requests</string>
```

### Step 4: Build & Run

```bash
# Open in Xcode
open OdysseyTest.xcodeproj

# Or build from command line
xcodebuild -project OdysseyTest.xcodeproj -scheme OdysseyTest -sdk iphoneos
```

**In Xcode:**
1. Select your iPhone from device menu (top-left)
2. Press **⌘R** (or click ▶️ button)
3. Wait for build (~1 min first time)
4. App launches on device

### Step 5: Grant Permissions

On first launch, allow:
- ✅ **Microphone** access (for voice)
- ✅ **Speech Recognition** (for transcription)
- ✅ **Notifications** (for JITAI nudges)

---

## 🎯 Optional: Local LLM Setup

To enable **Local Mode** (on-device chat without internet):

### A. Add llama.cpp Package

1. In Xcode: **File** → **Add Package Dependencies**
2. Enter URL: `https://github.com/ggerganov/llama.cpp`
3. Select version: `master` branch
4. Add to target: **OdysseyTest**

### B. Download TinyLlama Model

**Option 1: In-App Download** (Recommended)
1. Open app → **AI Chat** tab
2. Select **Local** mode
3. Tap **"Tap to download model"**
4. Wait for 669 MB download
5. Model saves to app's Documents folder

**Option 2: Manual Download**
```bash
# Download GGUF model
curl -L -o tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
  https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf

# Copy to iPhone via Xcode
# Or use Finder → Devices → OdysseyTest → Files → drag & drop
```

### C. Verify Installation

1. Open app → **AI Chat** tab
2. Select **Local** mode
3. Should show **"Load"** button (not "Tap to download")
4. Tap **"Load"** → Wait ~3 seconds
5. Model status: ✅ "Loaded"

---

## 📡 Optional: BLE Hardware Setup

To enable **activity sensing** from Arduino Nicla Voice:

### A. Hardware Requirements
- **Arduino Nicla Voice** board
- USB-C cable
- **Arduino IDE 2.0+**

### B. Install Arduino Libraries

In Arduino IDE:
1. **Tools** → **Board** → **Boards Manager**
2. Install: **"Arduino Mbed OS Nicla Boards"**
3. **Tools** → **Manage Libraries**
4. Install: **"ArduinoBLE"**
5. Install: **"NDP"** (Syntiant Neural Decision Processor)

### C. Flash Firmware

1. Open `AlexaDemoBLE/AlexaDemoBLE.ino`
2. **Tools** → **Board** → **Nicla Voice**
3. **Tools** → **Port** → Select USB port
4. Click **Upload** (→) button
5. Wait for "Upload complete" (~30s)

### D. Verify Firmware

Open **Serial Monitor** (⚘⇧M):
```
🔵 BLE device active, waiting for connections...
📡 Advertising as 'Alexa Nicla Voice'
⚙️  Loading synpackages...
✅ Packages loaded
✅ Ready! Say 'Alexa' to test.
```

### E. Connect from iPhone

1. Open app → Tap **BLE icon** (top-left)
2. Tap **"Scan for Devices"**
3. Should see **"Alexa Nicla"**
4. Tap device → **Connect**
5. Status: ✅ "BLE Connected"

### F. Test Connection

**Arduino Serial Monitor:**
```
Type: t
📤 Sending test message...
✅ Test message sent
```

**iPhone:**
- Should see: **"🔔 Hardware Event: 🧪 Test: Hello from Nicla!"**

---

## 🔧 Configuration Options

### Hydration Window

Default: 8 AM - 10 PM

To change:
```swift
// In HydrationView.swift
HydrationStore.shared.setHydrationWindow(startHour: 7, endHour: 22)
```

### Daily Hydration Goal

Default: 2000 ml

To change:
```swift
// In HydrationStore.swift
static let dailyGoal = 2500  // Change to your preference
```

### JITAI Nudge Frequency

Default: Check every 60 seconds

To change:
```swift
// In UnifiedChatViewModel.swift (line ~369)
nudgeTimer = Timer.scheduledTimer(withTimeInterval: 120, ...)  // 120 = 2 minutes
```

### Local LLM Parameters

Edit `LLMConfig.swift`:
```swift
static let maxTokens = 64          // Response length
static let temperature: Float = 0.5 // Randomness (0-1)
static let topP: Float = 0.85       // Nucleus sampling
```

---

## ✅ Verification Checklist

After installation, verify:

### Basic Functionality
- [ ] App launches without crashes
- [ ] Can navigate between tabs
- [ ] No error alerts on startup

### Cloud Mode
- [ ] AI Chat tab → Cloud mode selected
- [ ] Can tap mic → speak → get response
- [ ] Can type text → get response
- [ ] Xcode console shows: "Connected to OpenAI"

### Local Mode (if installed)
- [ ] AI Chat tab → Local mode
- [ ] "Load" button appears (or "Loaded" if already loaded)
- [ ] Can type text → get response
- [ ] No internet needed

### Hydration Tracking
- [ ] Hydration tab → Can tap quick-add buttons
- [ ] Progress bar updates
- [ ] Today's total shows correct sum

### Calendar
- [ ] Calendar tab opens
- [ ] Can add new events
- [ ] Events display in list

### BLE (if connected)
- [ ] BLE icon shows green badge
- [ ] Arduino test message appears in chat
- [ ] Activity events appear (keyboard/faucet/background)

### JITAI
- [ ] Debug Logs shows "JITAI" category entries
- [ ] Nudges appear after ~60s (if conditions met)
- [ ] Events tab shows nudge history

---

## 🐛 Common Issues

### "Config.swift not found"
**Solution:** Copy `Config.swift.template` to `Config.swift`

### "API Key Required" alert
**Solution:** Edit `Config.swift`, add valid OpenAI key

### "Microphone Permission" alert
**Solution:** Settings → Privacy → Microphone → Enable for OdysseyTest

### Cloud mode: "Connection failed"
**Causes:**
- No internet connection → Check WiFi/cellular
- Invalid API key → Verify at platform.openai.com
- No credits → Add payment method

**Check:** Xcode console for "Connected to OpenAI" or error details

### Local mode: "Model not downloaded"
**Solution:** 
1. Ensure ~2 GB free space
2. Tap "Tap to download model"
3. Wait for download (WiFi recommended)
4. If fails: Check storage space, retry

### Local mode: "Failed to load model"
**Causes:**
- Model file corrupted → Delete and re-download
- Insufficient RAM → Close other apps
- Wrong file format → Should be `.gguf`

### BLE: "Device not found"
**Solutions:**
- Check Arduino is powered on
- Re-upload firmware to Arduino
- Arduino Serial Monitor should show "Advertising"
- Try power cycle Arduino

### BLE: "Connection timeout"
**Solutions:**
- Move iPhone closer to Arduino
- Check no other device connected to Arduino
- Restart Bluetooth: Settings → Bluetooth → Off/On

### JITAI not sending nudges
**Check:**
1. Debug Logs (⋯ menu → Debug Logs)
2. Filter by "JITAI" category
3. Look for "Decision: NO_NUDGE" or "SEND_NUDGE"
4. Verify conditions met (water logged, time in window, etc.)

---

## 🔍 Debug Tips

### Enable Verbose Logging

In `DebugLogger.swift`:
```swift
var currentLevel: LogLevel {
    return .debug  // Change from .info to .debug
}
```

### Monitor Network Requests

In Xcode: **Debug** → **View Debugging** → **Network Link Conditioner**
- Test with slow network
- Test offline mode

### Profile Performance

In Xcode: **Product** → **Profile** (⌘I)
- Select "Time Profiler" for CPU analysis
- Select "Leaks" for memory issues

### View Logs

**Real-time (Xcode console):**
- Filter by category: `[OpenAI]`, `[JITAI]`, etc.
- Look for `ERROR:` prefix

**In-App (Debug Logs):**
- AI Chat → ⋯ menu → Debug Logs
- Filter by level: Error, Warn, Info, Debug
- Export logs if needed

---

## 🎓 Next Steps

1. **Explore features** - Try all 3 AI modes
2. **Connect BLE** - Add activity sensing
3. **Customize prompts** - Edit system prompts in code
4. **Add calendar events** - Test JITAI timing logic
5. **Monitor hydration** - Log water, observe nudges
6. **Check documentation** - Read ARCHITECTURE.md for deep dive

---

## 📞 Support

- **Issues:** https://github.com/yourusername/OdysseyTest/issues
- **Discussions:** https://github.com/yourusername/OdysseyTest/discussions

---

**Setup complete! 🎉** Start chatting with your AI assistant.

