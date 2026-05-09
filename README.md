<div align="center">

<img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
<img src="https://img.shields.io/badge/FastAPI-0.115-009688?style=for-the-badge&logo=fastapi&logoColor=white" />
<img src="https://img.shields.io/badge/Gemini_2.5-AI_Core-4285F4?style=for-the-badge&logo=google&logoColor=white" />
<img src="https://img.shields.io/badge/Groq-LLaMA_3.3-F55036?style=for-the-badge" />
<img src="https://img.shields.io/badge/Firebase-Realtime_DB-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" />
<img src="https://img.shields.io/badge/Platform-Android_%7C_Web-green?style=for-the-badge" />

#  NeuroSpace

### *Adaptive AI Learning for Neurodivergent Minds*

> **The world's first real-time morphing AI learning platform — where the app adapts to your brain, not the other way around.**

---

[ Download APK](https://drive.google.com/file/d/13UZm_NO3F2eQOPNTp-YOHTMXJPlqBXkc/view?usp=sharing) • [ Watch Demo](https://drive.google.com/file/d/1qVy9fYoy2NVY-rSQMmf5hM2OdSdvXG8L/view?) • [ Try Web App](https://soln-18a8c.web.app)

---

</div>

##  What is NeuroSpace?

NeuroSpace is a **full-stack, AI-powered adaptive learning application** built specifically for neurodivergent individuals — people with ADHD, Dyslexia, Autism Spectrum Disorder, and sensory processing differences. 

Most learning apps assume every user reads, focuses, and processes information the same way. NeuroSpace rejects that assumption entirely. When you tap a trait during onboarding — *"Dense text makes me dizzy"* or *"I lose focus easily"* — the **entire UI morphs in real time**: fonts shift, colors cross-fade, spacing adjusts, and the AI reconfigures its content style to match your cognitive profile.

This isn't a theme switcher. It's a **live, AI-driven accessibility system** that runs Gemini 2.5 and Groq LLaMA 3.3 in parallel to generate lessons, simplify text, narrate content, and surface nearby real-world support resources — all tuned to your specific neurological needs.

---

##  Demo

>  **[Watch the Full Demo Video](https://drive.google.com/file/d/1qVy9fYoy2NVY-rSQMmf5hM2OdSdvXG8L/view?)**

---

##  Download

>  **[Download Android APK](https://drive.google.com/file/d/13UZm_NO3F2eQOPNTp-YOHTMXJPlqBXkc/view?usp=sharing)**

---

##  Web App

>  **[Open Web App](https://soln-18a8c.web.app)**

---

##  The Problem NeuroSpace Solves

| The Status Quo | NeuroSpace's Approach |
|---|---|
| One-size-fits-all UI | Real-time AI theme morphing per cognitive profile |
| Dense walls of text | Chunked, bite-sized modules tuned per profile |
| Static reading apps | Live TTS with profile-matched voices (Gemini TTS) |
| No support discovery | Real NGO + clinic finder via OpenStreetMap |
| Learning stops in app | System-wide floating overlay works in ANY app |
| Generic fonts | OpenDyslexic / Lexend / Inter auto-selected |
| Uniform pacing | Energy-level–aware module count (4 / 7 / 12) |

---

## Core Features

### 1. Real-Time Adaptive UI (Morphing Onboarding)

The onboarding screen is the heart of NeuroSpace. As users tap trait cards, the app calls Groq's LLaMA 3.3 in the background to generate a fully custom theme JSON — while instantly applying a local blend for zero-latency visual feedback.

**Traits detected:**
- ⚡ *"I lose focus easily"* → ADHD mode: gamified cards, focus borders, chunked content, energetic TTS voice (Puck)
-  *"Dense text makes me dizzy"* → Dyslexia mode: OpenDyslexic font, 1.8× line height, 0.12em letter spacing, clear TTS voice (Kore)
-  *"Bright lights hurt my eyes"* → Sensory mode: low-contrast dark palette, muted accent colors
-  *"I need literal explanations"* → Autism mode: structured step-by-step, no metaphors, calm TTS voice (Enceladus)

Every UI element — fonts, colors, spacing, card radius, focus borders, TTS speed, module count — changes simultaneously, animated with Flutter's `AnimatedContainer` and `AnimatedDefaultTextStyle` at 400ms transitions.

**Profile settings stored in:**
- Local `SharedPreferences` for offline persistence
- Firebase Realtime Database for cross-device sync

---

### 2. AI Lesson Generation (Gemini + Groq with Auto-Rotation)

Type any topic into the search bar. NeuroSpace generates a fully structured, multi-module lesson adapted to your profile.

**How it works:**
1. Profile-specific system prompt is selected (ADHD / Dyslexia / Autism)
2. Gemini 2.5 Flash is called first (primary)
3. If rate-limited (429), the `ModelPool` auto-rotates to the next available model
4. Falls back to Groq LLaMA 3.3-70B → LLaMA-3-8B → Mixtral 8x7B
5. A strict JSON schema is enforced — lessons always return `title`, `summary`, `modules[]`, `tts_text`

**Module types generated:**
- `text_block` — core explanation with simplified language
- `key_point` — highlighted bullets with icons
- `example` — real-world analogies
- `mermaid_diagram` — flowcharts rendered via WebView + Mermaid.js
- `image_query` — visual search term for Cloudinary/Imagen
- `deep_dive` — expandable sub-topic (infinite depth)
- `quiz` — flip-card MCQ with instant feedback
- `flashcard` — spaced-repetition style memory cards

**Energy-level awareness:** If you set "Low Energy" on the Mental Battery widget, the backend returns only 4 modules. "High Energy" = up to 12 modules.

---

### 3. Model Pool — Zero-Downtime AI Failover

A custom `ModelPool` class manages automatic rate-limit rotation across all AI providers:

```
Gemini Pool:   gemini-2.5-flash → gemini-2.5-pro
Groq Text:     llama-3.3-70b → llama3-70b → llama3-8b → mixtral-8x7b
Groq Vision:   llama-3.2-90b-vision → llama-3.2-11b-vision  
Groq Audio:    whisper-large-v3 → whisper-large-v3-turbo
```

When any model returns a 429, it is put in a 60-second cooldown and the pool instantly rotates to the next. The app never shows an error — it silently falls through the chain. A `/model-status` endpoint exposes the live pool state for monitoring.

---

### 4. Gemini 3.1 Flash TTS — Profile-Matched Voices

Every lesson has a "Listen" button that calls Gemini's 3.1 Flash TTS (free tier, same API key). Unlike generic text-to-speech:

| Profile | Voice | Style Tags |
|---|---|---|
| ADHD | Puck | `[excited, upbeat]` |
| Dyslexia | Kore | `[clear, slow, enunciated]` |
| Autism | Enceladus | `[calm, gentle, steady pace]` |

Audio is returned as PCM, converted to WAV, and optionally uploaded to Cloudinary for persistent URLs. Long texts are automatically chunked at sentence boundaries and concatenated.

---

### 5. Snap-to-Understand (Camera OCR → AI Lesson)

Point your camera at any textbook page, whiteboard, or printed material. NeuroSpace:

1. Runs **on-device OCR** via Google ML Kit (`google_mlkit_text_recognition`) — no network required
2. Sends extracted text to the backend
3. Gemini Vision analyzes the image: extracts text, identifies diagrams, recreates them as Mermaid.js code
4. Returns a full structured lesson adapted to your profile

Supports both camera capture and gallery picker. Shows a full-screen "Scanning & Simplifying..." overlay while processing.

---

### 6. System-Wide Floating Accessibility Overlay (Android)

This is NeuroSpace's most unique feature. A **persistent floating bubble** lives above every app on the user's device (Android "draw over other apps" permission). Tap it to access:

| Action | Description |
|---|---|
| **Summarize Page** | Reads on-screen text via Android Accessibility Service → sends to Gemini/Groq → returns structured summary |
| **Simplify Clipboard** | Takes any copied text → rewrites it in accessible language |
| **Summarize Clipboard** | Returns key points, tone, reading time, confidence score |
| **Easy Read** | Reformats text into heading + bullet structure with emoji anchors |
| **Read Aloud** | Uses Flutter TTS to read screen/clipboard text aloud with progress tracking |
| **Open in NeuroSpace** | Sends content from any app into the full NeuroSpace reader |

The overlay intelligently filters out system UI noise (battery %, Wi-Fi status, time, notification labels) before sending text to AI, ensuring clean summarization.

---

### 7. Quiet Space Finder (OpenStreetMap + Groq)

Neurodivergent users often need sensory-safe environments. The Maps screen:

1. Fetches user's GPS location
2. Queries **Overpass API** (OpenStreetMap) for nearby cafes, libraries, parks
3. Sends results to **Groq** to generate sensory profiles (crowd level, lighting type, noise level)
4. Displays results on an interactive **flutter_map** (OpenStreetMap tiles — no Google Maps API key needed)

Each place shows: crowd density, lighting type, noise level, and a sensory-safe rating.

---

### 8. Resource Recommendation Engine

Users can find nearby neurodivergent support resources — clinics, therapists, NGOs, special educators — filtered by:

- **Category:** Medical vs. Educational
- **Urgency:** Urgent / High / Medium / Low
- **Budget:** Free / Low / Medium / High
- **Delivery:** Online / Offline / Both
- **Diagnosis:** ADHD, Dyslexia, Autism, etc.

The engine uses a **deterministic scoring algorithm** (100-point scale) weighing distance (Haversine formula), category match, urgency, diagnosis relevance, budget, and delivery mode. Real POIs are fetched from Overpass API; curated fallbacks (Action for Autism, National Trust for Disability, ADAPT) are used when APIs fail.

---

### 9. Focus Timer (Pomodoro + Sensory Break)

A profile-adaptive Pomodoro timer:

- **ADHD mode:** Digital countdown with animated progress ring and glowing shadows
- **Dyslexia / Autism mode:** Breathing circle with slow pulse animation
- Adjustable session length (1–120 minutes via slider)
- White noise toggle (plays looping rain audio from Google Sounds)
- Completed sessions logged to Firebase Realtime Database

---

### 10. Panic / Grounding Screen

A full-screen sensory-safe emergency tool for when users feel overwhelmed. Forces a near-pitch-black background (regardless of profile) and guides through the **5-4-3-2-1 grounding technique**:

1. 5 things you can **see**
2. 4 things you can **feel**
3. 3 things you can **hear**
4. 2 things you can **smell**
5. 1 thing you can **taste**

Each step has an animated ambient pulse, a large icon, and fade-in text. The entire screen is tappable to advance steps.

---

### 11. Wikipedia-Powered Search

The search screen queries Wikipedia's REST API for live article previews, rendering results in the adaptive lesson format. Results are stored to Firebase for session history.

---

### 12. Adaptive Reader

Paste or share any text into NeuroSpace's reader. The reader applies your profile's typography settings — font family, size, letter spacing, line height — and provides TTS playback with per-word progress highlighting.

---

### 13. Study Stats & Session History

The dashboard shows:
- **Mental Battery** widget — set today's energy level (High / Medium / Low)
- **Total study minutes** accumulated (synced from Firebase)
- **Recent lessons** (last 3 sessions with topic and timestamp)
- **Backend connection status** (version indicator)

---

##  Architecture

```
NEUROSPACE/
├── backend/                    # FastAPI Python backend
│   ├── main.py                 # App entry point, router registration
│   ├── routers/                # 11 API route modules
│   │   ├── lessons.py          # POST /api/lessons
│   │   ├── simplify.py         # POST /api/simplify + /api/summarize
│   │   ├── tts.py              # POST /api/tts
│   │   ├── image.py            # POST /api/image
│   │   ├── theme.py            # POST /api/theme
│   │   ├── maps.py             # GET /api/maps/quiet-spaces
│   │   ├── scan.py             # POST /api/scan
│   │   ├── search.py           # POST /api/search
│   │   ├── voice.py            # POST /api/voice
│   │   ├── assistant.py        # POST /api/assistant/*
│   │   └── resources.py        # POST /api/resources
│   ├── services/               # 17 service modules
│   │   ├── llm_core.py         # ModelPool + Gemini/Groq invocation
│   │   ├── gemini_service.py   # Lesson gen, simplify, vision, deep-dive
│   │   ├── tts_service.py      # Gemini 3.1 Flash TTS
│   │   ├── resource_engine.py  # Scoring engine + Overpass API
│   │   ├── maps_service.py     # Quiet space finder
│   │   ├── theme_generator.py  # AI theme generation
│   │   ├── vision_explainer.py # Image analysis
│   │   ├── voice_intent.py     # Voice command parsing
│   │   ├── cloudinary_service.py # Media storage
│   │   └── ...
│   ├── prompts/                # Per-profile system prompts
│   │   ├── adhd_prompt.py
│   │   ├── dyslexia_prompt.py
│   │   └── autism_prompt.py
│   ├── models/                 # Pydantic schemas
│   ├── Dockerfile
│   └── requirements.txt
│
└── neurospace/                 # Flutter application
    └── lib/
        ├── main.dart           # App entry + overlay entry point
        ├── screens/            # 19 screens
        │   ├── dashboard_screen.dart
        │   ├── onboarding_screen.dart
        │   ├── lesson_screen.dart
        │   ├── overlay_screen.dart      # System-wide floating overlay
        │   ├── focus_timer_screen.dart
        │   ├── maps_screen.dart
        │   ├── panic_screen.dart
        │   ├── resource_dashboard_screen.dart
        │   ├── resource_ngos_screen.dart
        │   ├── settings_screen.dart
        │   └── ...
        ├── providers/          # State management
        │   ├── neuro_theme_provider.dart  # AI theme + profile switching
        │   ├── bubble_provider.dart       # Overlay bubble state
        │   └── booking_provider.dart      # Resource booking state
        ├── services/           # Client services
        │   ├── api_service.dart           # HTTP client for backend
        │   ├── firebase_service.dart      # Auth + Realtime DB
        │   ├── location_service.dart      # GPS
        │   ├── ocr_service.dart           # On-device ML Kit OCR
        │   └── android_assistant_bridge.dart # Accessibility service bridge
        └── models/             # Data models
            ├── neuro_profile.dart         # Profile + theme data
            ├── lesson.dart                # Lesson schema
            └── resource_models.dart       # Resource types
```

---

## Tech Stack

### Frontend — Flutter

| Package | Purpose |
|---|---|
| `flutter` SDK ^3.11.4 | Cross-platform UI framework |
| `provider` ^6.1.2 | State management |
| `firebase_core` ^3.9.0 | Firebase initialization |
| `firebase_auth` ^5.4.2 | Anonymous authentication |
| `firebase_database` ^11.3.1 | Realtime Database (lesson history, profiles) |
| `flutter_overlay_window` ^0.5.0 | System-wide floating bubble (Android) |
| `google_mlkit_text_recognition` ^0.14.0 | On-device OCR |
| `flutter_map` ^6.1.0 | OpenStreetMap tiles (no API key) |
| `geolocator` ^13.0.2 | GPS location |
| `latlong2` ^0.9.1 | Map coordinate types |
| `google_fonts` ^6.2.1 | OpenDyslexic, Lexend, Inter |
| `flutter_markdown` ^0.7.6 | Lesson content rendering |
| `webview_flutter` ^4.10.0 | Mermaid.js diagram rendering |
| `audioplayers` ^6.1.0 | White noise / TTS audio playback |
| `speech_to_text` ^7.0.0 | Voice input |
| `flutter_tts` ^4.0.2 | On-device TTS (overlay fallback) |
| `image_picker` ^1.1.2 | Camera + gallery for Snap-to-Understand |
| `flip_card` ^0.7.0 | Flashcard quiz animations |
| `flutter_animate` ^4.5.2 | Micro-animations |
| `lottie` ^3.3.1 | Lottie JSON animations |
| `cached_network_image` ^3.3.1 | Efficient image loading |
| `shared_preferences` ^2.3.4 | Local profile persistence |
| `url_launcher` ^6.2.5 | Wikipedia + external links |
| `uuid` ^4.5.1 | Anonymous user IDs |

### Backend — Python / FastAPI

| Package | Purpose |
|---|---|
| `fastapi` 0.115.6 | REST API framework |
| `uvicorn[standard]` 0.34.0 | ASGI server |
| `google-generativeai` ≥0.8.4 | Gemini 2.5 Flash/Pro |
| `google-genai` ≥1.0.0 | Gemini 3.1 Flash TTS |
| `groq` ≥0.4.0 | LLaMA 3.3, Mixtral, Whisper |
| `cloudinary` ≥1.36.0 | TTS audio + image storage |
| `httpx` 0.28.1 | Async HTTP (Overpass API) |
| `pydantic` 2.10.4 | Request/response validation |
| `python-multipart` 0.0.20 | File upload handling |

### Infrastructure

| Service | Purpose |
|---|---|
| **Render** | Backend deployment (Docker, free tier) |
| **Firebase** | Anonymous auth + Realtime Database |
| **Cloudinary** | TTS audio file hosting |
| **OpenStreetMap / Overpass** | Maps + POI data (no API key) |
| **Firebase Hosting** | Web app deployment |

---

## 🆚 How NeuroSpace Compares

| Feature | NeuroSpace | Khan Academy | Duolingo | Headspace | Goblin Tools |
|---|---|---|---|---|---|
| Neurodivergent-first design | ✅ Core purpose | ❌ | ❌ | ❌ | ⚠️ Partial |
| Real-time UI morphing | ✅ | ❌ | ❌ | ❌ | ❌ |
| Profile-specific AI content | ✅ ADHD/Dyslexia/Autism | ❌ | ❌ | ❌ | ⚠️ |
| System-wide overlay | ✅ Any Android app | ❌ | ❌ | ❌ | ❌ |
| Camera OCR → AI lesson | ✅ | ❌ | ❌ | ❌ | ❌ |
| Profile-matched TTS voices | ✅ 3 voices | ❌ | ❌ | ❌ | ❌ |
| Nearby support resources | ✅ NGOs, clinics | ❌ | ❌ | ❌ | ❌ |
| Quiet space finder | ✅ | ❌ | ❌ | ❌ | ❌ |
| Panic/grounding mode | ✅ | ❌ | ❌ | ⚠️ | ❌ |
| Free (no subscription) | ✅ | ✅ | ⚠️ Freemium | ⚠️ Freemium | ✅ |
| Works offline (partial) | ✅ OCR + TTS | ⚠️ | ⚠️ | ⚠️ | ❌ |
| Open source | ✅ | ❌ | ❌ | ❌ | ❌ |

---

## AI Model Strategy

NeuroSpace uses a **three-layer AI cascade** to ensure maximum availability:

```
Layer 1: Gemini 2.5 Flash  ──→ Primary (best quality, JSON-native)
              ↓ 429 / fail
Layer 2: Gemini 2.5 Pro    ──→ Secondary (larger context)
              ↓ 429 / fail
Layer 3: Groq LLaMA 3.3-70B → Fast fallback (~100ms latency)
              ↓ 429 / fail
Layer 4: Groq LLaMA 3-70B  ──→ Secondary fallback
              ↓ 429 / fail
Layer 5: Groq Mixtral 8x7B ──→ Final text fallback
              ↓ all fail
Layer 6: Local Fallback    ──→ Minimal hardcoded response
```

Each layer is managed by the `ModelPool` class with 60-second per-model cooldowns. The pool's status is exposed at `GET /model-status`.

**Per-profile system prompts** ensure the same topic produces different content:
- **ADHD prompt:** Short sentences, gamified framing, immediate examples, quiz-heavy
- **Dyslexia prompt:** Large conceptual chunks, no jargon, audio-script optimized
- **Autism prompt:** Explicit step-by-step, literal language, no metaphors, structured headings

---

## What Makes NeuroSpace Unique

1. **The Morphing UI** — No other learning app changes its entire visual language (font, color, spacing, pacing) in response to a neurological profile selection, animated live on screen.

2. **System-Wide Overlay** — NeuroSpace is the only learning app that works *outside itself*. You can be reading a news article, a PDF, or a social media post — tap the floating bubble and NeuroSpace simplifies it for you.

3. **Sensory-Safe Emergency Mode** — The Panic Screen is one tap from the dashboard. It overrides all theming to create a pitch-dark, low-stimulation environment with guided grounding exercises.

4. **Real Resource Discovery** — Most mental health apps say "seek help." NeuroSpace actually shows you where that help is on a real map, filtered by your specific diagnosis, urgency, and budget.

5. **AI Energy Awareness** — The Mental Battery widget isn't cosmetic. Setting "Low Energy" literally changes how many content modules the AI generates, preventing cognitive overload on hard days.

6. **No-API-Key Maps** — Using flutter_map + OpenStreetMap instead of Google Maps means no billing surprises and no API keys to manage.

7. **On-Device OCR** — The Snap-to-Understand feature extracts text on-device via ML Kit before uploading to AI, meaning it works even on slow connections and preserves privacy.

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.11.4
- Python ≥ 3.11
- Android Studio / Xcode (for mobile)
- A Google Gemini API key (free at [aistudio.google.com](https://aistudio.google.com))
- A Groq API key (free at [console.groq.com](https://console.groq.com))
- Firebase project (free tier)

### Backend Setup

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Create `backend/.env`:
```env
GEMINI_API_KEY=your_gemini_key
GROQ_API_KEY=your_groq_key
CLOUDINARY_CLOUD_NAME=your_cloud_name     # Optional
CLOUDINARY_API_KEY=your_cloudinary_key   # Optional
CLOUDINARY_API_SECRET=your_cloudinary_secret  # Optional
GEMINI_FLASH_MODEL=gemini-2.5-flash
GEMINI_PRO_MODEL=gemini-2.5-pro
```

Start the backend:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

API docs at: `http://localhost:8000/docs`

### Flutter App Setup

```bash
cd neurospace
flutter pub get
```

Add your Firebase config files:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

(Generate via `flutterfire configure` with your Firebase project)

Run the app:
```bash
flutter run
```

For web:
```bash
flutter run -d chrome
```

### Docker Deployment (Backend)

```bash
docker build -t neurospace-api ./backend
docker run -p 8000:8000 --env-file backend/.env neurospace-api
```

One-click Render deployment via `render.yaml` (included in repo root).

---

## API Reference

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Health check |
| `GET` | `/model-status` | Live AI model pool status |
| `POST` | `/api/lessons` | Generate adaptive lesson |
| `POST` | `/api/simplify` | Simplify text for profile |
| `POST` | `/api/summarize` | Structured text summary |
| `POST` | `/api/tts` | Gemini TTS audio generation |
| `POST` | `/api/image` | AI image generation (Imagen) |
| `POST` | `/api/theme` | AI theme JSON generation |
| `GET` | `/api/maps/quiet-spaces` | Nearby sensory-safe places |
| `POST` | `/api/scan` | OCR image → AI lesson |
| `POST` | `/api/search` | Wikipedia + web search |
| `POST` | `/api/voice` | Voice command → intent |
| `POST` | `/api/assistant/easy-read` | Easy-read formatter |
| `POST` | `/api/resources/recommend` | Resource recommendations |
| `GET` | `/api/resources/ngos` | Nearby NGOs |

Full interactive docs: `[your-backend-url]/docs`

---

## Privacy & Security

- **Anonymous Auth:** Firebase anonymous sign-in creates a persistent user ID without any PII. No email, no phone, no name.
- **On-Device OCR:** Text is extracted on-device before being sent anywhere.
- **No Data Sold:** Lesson history and profiles are stored only in your Firebase project.
- **Open Source:** The full codebase is available for audit.
- **API Keys:** Never bundled in the app. Backend holds all keys server-side.

---

## Roadmap

- [ ] iOS overlay support (currently Android-only)
- [ ] Voice-first navigation mode
- [ ] Spaced repetition flashcard scheduling
- [ ] Parent/educator dashboard
- [ ] Offline lesson caching
- [ ] Multi-language support (Hindi, Spanish priority)
- [ ] Wearable integration (haptic focus reminders)
- [ ] AI-generated Mermaid diagrams rendered inline

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit changes: `git commit -m 'Add your feature'`
4. Push: `git push origin feature/your-feature`
5. Open a Pull Request

Please ensure new backend features include tests in `test_*.py` files and new Flutter screens follow the `NeuroProfile`-adaptive pattern used throughout.

---

---

## Acknowledgements

- **Google Gemini** — AI backbone for lesson generation, vision analysis, and TTS
- **Groq** — Ultra-fast LLM inference for fallback and theme generation
- **OpenStreetMap / Overpass API** — Free, open map data for resource and quiet-space discovery
- **Action for Autism, National Trust for Disability, ADAPT** — Curated fallback NGO data
- **Flutter team** — Cross-platform UI framework
- **Firebase** — Real-time sync and anonymous auth

---

<div align="center">



*NeuroSpace — because learning should meet you where your brain is, not where the curriculum expects it to be.*

</div>
