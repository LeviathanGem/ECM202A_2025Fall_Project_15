---
layout: default
title: "Odyssey: A Context-Aware JITAI Hydration Assistant"
---

# **Odyssey: A Context-Aware JITAI Hydration Assistant**

*A system integrating edge audio sensing (Nicla Voice), BLE streaming, and an iOS LLM-powered reasoning layer to deliver intelligent, context-appropriate hydration reminders.*

![Project Banner](./assets/img/banner-placeholder.png)  
<sub>*Replace with a system architecture or app screenshot.*</sub>

---

## 👥 **Team**

- Assia Li (UCLA)  
- *(Add team members if applicable)*

---

## 📝 **Abstract**

We introduce **Odyssey**, a context-aware JITAI (Just-In-Time Adaptive Intervention) system that delivers hydration reminders only at optimal, non-disruptive moments. The system combines **edge audio classification** on an Arduino Nicla Voice, **BLE streaming** of environmental context, and a **SwiftUI iOS app** running a local/remote LLM reasoning layer. Odyssey integrates calendar availability, hydration history, BLE-based activity detection (keyboard typing, running faucet, background noise), and prompt history to infer *interruptibility* and determine whether **now is the right moment for a hydration reminder**. Our results demonstrate low-latency sensing-to-intervention, high classification reliability for simple environmental cues, and promising early behavior-aligned timing. The project shows how lightweight sensing + LLM reasoning can enable respectful, user-aware intervention systems.

---

## 📑 **Slides**

- [Midterm Checkpoint Slides](http://)  
- [Final Presentation Slides](http://)

---

## 🎛️ **Media**

- Demo Video (optional)  
- Model training or BLE streaming demonstration (optional)

---

# **1. Introduction**

Hydration apps usually rely on **fixed timers**, ignoring what the user is actually doing. Reminding someone who is in a meeting or deep flow state can be counterproductive. This project seeks to redesign hydration prompting through a **JITAI framework**, delivering interventions that are:

- context-aware,  
- break-aligned,  
- low-disruption,  
- personalized to the user’s schedule and habits.

## **1.1 Motivation & Objective**

Our core objective is to build a **hydration assistant that actually pays attention**—to the user’s activity, schedule, and context—before interrupting them. By using embedded sensing (keyboard → working; faucet → break), calendar awareness, and hydration status, Odyssey determines the *best* moments to remind users to drink water.

## **1.2 State of the Art & Limitations**

Traditional health apps:  
- Use fixed reminders  
- Don't incorporate context or interruptibility  
- Rarely integrate multimodal signals  

Prior JITAI research shows the importance of timing interventions with user state, but full **hardware-to-LLM pipelines** integrating sensing + scheduling remain unexplored.

## **1.3 Novelty & Rationale**

Our system is novel because it integrates:  
- **Edge ML audio sensing** for environmental context  
- **BLE real-time event streaming**  
- **Calendar-aware LLM reasoning**  
- **A unified iOS multi-tab architecture**  

This enables *precision prompting* aligned with behavioral intervention theory.

## **1.4 Potential Impact**

This architecture could generalize to:  
- ergonomic/posture JITAIs  
- micro-break encouragement  
- digital well-being interventions  
- adaptive VR/AR safety systems  

## **1.5 Challenges**

- BLE latency and reliability  
- Edge model accuracy in noisy environments  
- Designing interpretable, rule-based JITAI logic  
- Integrating LLM reasoning safely and consistently  

## **1.6 Metrics of Success**

- Edge classification accuracy  
- BLE latency (sensor → phone → decision)  
- % prompts delivered during “appropriate context”  
- Reduction of disruptive prompts  
- Usability & alignment with user behavior  

---

# **2. Related Work**

Relevant domains include:

- **JITAI Frameworks** – timing interventions based on user state and context  
- **Context-aware mobile computing** – detecting interruptibility using sensors  
- **On-device ML (TinyML)** – efficient edge classification models  
- **LLM-based personal assistants** – reasoning over schedules and user habits  

Gaps we address:

- Lack of **low-power multimodal sensing** integrated with LLM reasoning  
- Lack of **BLE-to-LLM pipeline** for real-time adaptive interventions  
- Limited exploration of **environmental audio** as a proxy for interruptibility  

---

# **3. Technical Approach**

## **3.1 System Architecture**

A three-layer architecture:

1. **Edge Layer – Nicla Voice**
   - TinyML model classifies: `keyboard`, `faucet`, `background`
   - Sends events via BLE

2. **Context Layer – Odyssey iOS App**
   - Tabs: AI Chat, Events, Calendar, Hydration  
   - Shared services: `HydrationService`, `ContextService`, `CalendarService`

3. **Decision Layer – JITAI Engine + LLM**
   - Evaluates context  
   - Computes hydration need  
   - Determines whether to prompt  

*Add your architecture diagram here.*

---

## **3.2 Data Pipeline**

1. Audio → MFCC/Spectrograms (Edge Impulse)  
2. TinyML classifier on Nicla → label output  
3. BLE packet (timestamp, label, confidence)  
4. iOS receives event → logs + updates context buffer  
5. JITAI engine evaluates prompt decision  
6. If appropriate → hydration reminder (via chat or notification)

---

## **3.3 Algorithm / Model Details**

- Model: TinyML CNN (keyword spotting style)
- Classes: keyboard, faucet, background  
- Features: MFCC (typically 13×frames)  
- Training pipeline: Edge Impulse  
- BLE packet format: `"label,confidence,timestamp"`

Decision rules include:

- Skip if user is in a meeting (`CalendarService`)  
- Skip if last prompt < cooldown  
- Prefer prompting after faucet events  
- Prompt after long keyboard streaks + hydration deficit  
- Maintain quiet hours  

---

## **3.4 Hardware / Software Implementation**

### **Hardware**

- Arduino Nicla Voice  
- BLE communication module  
- Laptop/iPhone for development  

### **Software**

- SwiftUI iOS App (Odyssey)  
- Tabs: AI Chat, Events, Calendar, Hydration  
- Shared services for state modeling  
- LLM (OpenAI / local models) for reasoning and surface messaging  

---

## **3.5 Key Design Decisions & Rationale**

- Using **audio** instead of vision to preserve privacy  
- Performing classification **on-device** to reduce BLE bandwidth  
- Keeping JITAI decision logic **transparent and rule-based**  
- Integrating LLM only at the “explanation and interaction layer”  

---

# **4. Evaluation & Results**

(*Fill these once results are ready—here are placeholders you can update.*)

### **4.1 Edge Model Performance**
- Accuracy per class  
- Confusion matrix  
- Latency on Nicla device  

### **4.2 BLE Streaming Latency**
- Average: ~N ms  
- Worst-case: N ms  

### **4.3 JITAI Behavior Simulation**
- % of prompts delivered during meetings → expected low  
- % delivered during natural breaks → expected high  
- Prompt spacing consistency  

### **4.4 Qualitative Case Study**
- Timeline plot: activity vs. prompts vs hydration intake  

*Add figures with captions.*

---

# **5. Discussion & Conclusions**

Odyssey demonstrates that lightweight sensing + structured reasoning can create **polite, context-aware interventions**. Our system avoids interrupting users during meetings and encourages hydration during natural break points. Although the rule-based logic is simple, our results show the feasibility of combining edge ML, BLE, and LLM reasoning into a cohesive JITAI system.

Remaining limitations include noisy audio environments, limited personalization, and lack of long-term behavioral studies.

Future improvements:

- Adaptive thresholds based on user response  
- Additional sensor modalities  
- Pure on-device LLMs for private, offline reasoning  
- Extension to other wellness interventions  

---

# **6. References**

*(Fill with real citations later.)*

- JITAI survey papers  
- Edge Impulse documentation  
- TinyML literature  
- Interruptibility detection studies  

---

# **7. Supplementary Material**

## **7.a. Datasets**

- Keyboard dataset: recorded manually  
- Faucet dataset: mixed household recordings  
- Background dataset: filler ambient noise  
- Processing: WAV normalization → MFCC extraction  

## **7.b. Software**

- Nicla firmware + TinyML model  
- SwiftUI app (Odyssey):  
  - `ConversationManager`  
  - `HydrationService`  
  - `ContextService`  
  - `CalendarService`  
- BLE event logger  

---

*(Template source: UCLA ECEM202A project site template)  
:contentReference[oaicite:1]{index=1}
