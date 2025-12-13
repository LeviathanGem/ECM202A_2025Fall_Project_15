# 💧 Odyssey Companion

**Calendar-aware hydration JITAI** combining BLE activity sensing (Nicla Voice), cloud voice AI (OpenAI Realtime), and on-device chat (TinyLlama) for adaptive hydration nudges.

---

## ✨ Features

### 🤖 Unified AI Chat
- **3 Modes**: Cloud (OpenAI GPT-4o), Local (TinyLlama 1.1B), Hybrid (both)
- **Real-time voice** with OpenAI Realtime API
- **On-device text chat** - 100% private, no internet needed
- **Context-aware** - BLE events, calendar, hydration state

### 📡 BLE Activity Sensing
- Connects to **Arduino Nicla Voice** via Bluetooth
- Detects: keyboard (busy), faucet (break), background (idle)
- Real-time activity → AI context

### 📅 Calendar-Aware JITAI
- **Adaptive timing** - avoids meetings, prefers breaks
- **2-stage LLM reasoning** - decides when + what to nudge
- **Time-based pacing** - compares intake progress vs time progress

### 💦 Hydration Tracking
- Simple logging (50/100/200/250ml quick-add)
- Daily goal with progress tracking
- Configurable hydration window (default 8 AM - 10 PM)

---

## 🚀 Quick Start

### Prerequisites
- **Xcode 15.0+**, **iOS 17.0+**
- **OpenAI API Key** (for cloud mode)
- **~2 GB free space** (for local model, optional)

### Installation

1. **Clone & Open**
   ```bash
   git clone https://github.com/yourusername/OdysseyTest.git
   cd OdysseyTest
   open OdysseyTest.xcodeproj
   ```

2. **Add API Key**
   ```bash
   cp OdysseyTest/Config.swift.template OdysseyTest/Config.swift
   # Edit Config.swift and add: "sk-proj-your-key-here"
   ```

3. **Add Permissions** (Xcode → Target → Info)
   - `Privacy - Microphone Usage Description`: "For voice interaction"
   - `Privacy - Speech Recognition Usage Description`: "For transcription"

4. **Build & Run** (⌘R)

### Optional: Local LLM Setup
See [ARCHITECTURE.md](ARCHITECTURE.md) → Local LLM section for TinyLlama installation.

### Optional: BLE Hardware
Flash `AlexaDemoBLE/AlexaDemoBLE.ino` to Arduino Nicla Voice for activity sensing.

---

## 📱 Usage

### AI Chat Modes

**Cloud Mode** (☁️):
- Tap mic → speak → get voice response
- or type text → get text response
- Uses OpenAI GPT-4o (requires internet)

**Local Mode** (📱):
- Type text → get response from on-device TinyLlama
- 100% private, works offline
- First time: tap "Load" to load model (~3s)

**Hybrid Mode** (🔀):
- Sends message to both AIs
- Compare cloud vs local responses

### Hydration Tracking
- **Hydration Tab** → Quick-add water intake
- **Events Tab** → View BLE events + nudge history
- **Calendar Tab** → Manage schedule (JITAI uses this)

### BLE Connection
1. Tap BLE icon → "Scan for Devices"
2. Select "Alexa Nicla" → Connect
3. Green BLE badge = connected
4. Activity events appear in chat as system messages

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    USER LAYER                           │
│  UnifiedChatView │ HydrationView │ CalendarView         │
└────────┬──────────┴───────┬──────┴──────────┬───────────┘
         │                  │                 │
         ▼                  ▼                 ▼
┌─────────────────────────────────────────────────────────┐
│                  STATE LAYER                            │
│  UnifiedChatViewModel │ HydrationStore │ CalendarManager│
└────────┬──────────────────┴────────────────┬────────────┘
         │                                   │
         ▼                                   ▼
┌─────────────────────────────────────────────────────────┐
│                 INTEGRATION LAYER                       │
│  ConversationManager (shared state, BLE events)         │
└────┬───────────┬────────────────┬────────────┬──────────┘
     │           │                │            │
     ▼           ▼                ▼            ▼
┌──────────┐ ┌─────────┐  ┌──────────┐  ┌──────────────┐
│ OpenAI   │ │ Local   │  │   BLE    │  │   JITAI      │
│ Realtime │ │ LLMgr   │  │ Manager  │  │  Reasoner    │
│ (cloud)  │ │(llamacpp)│  │ (Nicla)  │  │ (2-stage AI) │
└──────────┘ └─────────┘  └──────────┘  └──────────────┘
```

**Key Files:**
- `UnifiedChatView.swift` - Main chat UI
- `UnifiedChatViewModel.swift` - Chat logic + JITAI reasoning
- `ConversationManager.swift` - Shared state hub
- `OpenAIRealtimeService.swift` - WebSocket to OpenAI
- `LLMManager.swift` + `LlamaBridge.mm` - Local inference
- `BLEManager.swift` - CoreBluetooth client
- `HydrationStore.swift` - Water tracking persistence

---

## 🧪 Testing

### Test Cloud AI
1. Open app → AI Chat tab
2. Select "Cloud" mode
3. Tap mic or type: "How much water have I drunk today?"
4. Should get contextual response

### Test Local AI
1. AI Chat tab → "Local" mode
2. Tap "Load" if needed (wait ~3s)
3. Type: "log 250ml"
4. Should get response from TinyLlama

### Test BLE
1. Power on Arduino Nicla Voice
2. Tap BLE icon → Scan → Connect
3. Arduino Serial Monitor: type `t` (sends test message)
4. Should see "🔔 Hardware Event: 🧪 Test" in chat

### Test JITAI Nudge
1. Hydration tab → Log some water
2. Calendar tab → Add upcoming meeting
3. Wait (periodic 60s check runs in background)
4. AI decides if/when to nudge based on context
5. Check Debug Logs (⋯ menu) for reasoning

---

## 🔐 Security & Privacy

- **API Keys**: `Config.swift` is gitignored
- **Local Mode**: All inference on-device (private)
- **Cloud Mode**: Data sent to OpenAI (see their privacy policy)
- **BLE**: Local Bluetooth only, no data leaves device
- **Storage**: UserDefaults (hydration, nudges) - stays on device

---

## 📊 Performance

| Component | Metric |
|-----------|--------|
| **Local LLM Load** | 2-3s first time |
| **Local LLM Generation** | 15-20 tokens/sec (iPhone 15 Pro) |
| **Cloud Voice Latency** | 500-1000ms |
| **BLE Connection** | <1s |
| **RAM Usage (Local)** | ~920 MB during inference |
| **Model Size** | 669 MB (TinyLlama Q4_K_M) |

---

## 🐛 Troubleshooting

### "API Key Required"
- Create `Config.swift` from template
- Add valid OpenAI key starting with `sk-proj-`

### "Microphone Permission Required"
- Settings → Privacy → Microphone → Enable for OdysseyTest

### Cloud mode not working
- Check internet connection
- Verify API key at https://platform.openai.com/api-keys
- Ensure Realtime API access enabled

### Local mode shows "Model not loaded"
- Tap "Load" button
- Wait for download (669 MB, first time only)
- Requires ~2 GB free space

### BLE not connecting
- Check Arduino is powered on
- Verify "Alexa Nicla" appears in scan
- Try power cycle Arduino
- Check Bluetooth is enabled on iPhone

### JITAI not sending nudges
- Check Debug Logs (⋯ menu → Debug Logs)
- Look for "JITAI" category entries
- Verify hydration data exists (log some water)
- System checks every 60 seconds

---

## 📚 Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Deep technical overview
- **[SETUP.md](SETUP.md)** - Detailed installation guide
- **Config.swift.template** - API key template

---

## 💰 Costs (Cloud Mode)

**OpenAI Realtime API**:
- Input audio: ~$0.06/min
- Output audio: ~$0.24/min
- Chat API: ~$0.002/1K tokens

**Local Mode**: Free (uses on-device TinyLlama)

Monitor usage: https://platform.openai.com/usage

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push (`git push origin feature/AmazingFeature`)
5. Open Pull Request

---

## 📄 License

MIT License - See LICENSE file for details

---

## 📧 Contact

Project Link: https://github.com/yourusername/OdysseyTest

---

**Built with:** Swift, SwiftUI, AVFoundation, CoreBluetooth, llama.cpp, OpenAI Realtime API
