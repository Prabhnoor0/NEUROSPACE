# Executive Summary  
This plan delivers a **production-grade implementation** for NEUROSPACE—a Flutter-based learning app for neurodivergent users. Key components include: a strict **JSON schema** for AI-generated content (lessons, summaries, TTS scripts), a **master Gemini prompt** and a **Groq fallback prompt**, robust error/fallback logic, and extensive UI/UX enhancements. The app will use Google’s Gemini API (Generative Language) primarily and Groq’s Llama 3.3 model as a fallback for cost/performance.  The UI will be overhauled with a cohesive design system (accessible fonts, spacing, colors) and a fully functional hover/overlay interface with features like text-to-speech (FlutterTTS), summarization, and a draggable mini-window.  We include architecture/data-flow diagrams, tables comparing Gemini vs Groq, sample API calls, pseudocode, and a detailed timeline with tasks, owners, and estimates.  This comprehensive plan ensures developers or AI agents can execute and test all features end-to-end.

## Project Goals  
- **Neurodivergent Accessibility:** Design UI and content for ADHD, autism, dyslexia – simple layout, dyslexia-friendly fonts, high-contrast colors, focus mode, text-to-speech, reduced motion.  
- **Structured AI Content:** Generate lessons and summaries via LLMs in a fixed JSON format (schema enforcement) for reliable parsing and display.  
- **Hover/Overlay Interface:** Fix the hover-circle feature so users can hover/tap a node to get a popup card with actions (TTS, Simplify, Expand, etc.). Provide a persistent draggable mini-widget for quick reference.  
- **Enhanced Features:** In-app search (for topics), camera OCR (scan text → TTS/summarize/format), Wikipedia link integration, and dynamic image/graph inclusion in lessons.  
- **Robust System:** Implement Gemini+Groq with validation, fallbacks, caching, rate-limiting, and cost-control strategies. Ensure full testing (unit, widget, integration, AI-output) and CI/CD for deployment.  

## Prioritized Feature List  
1. **LLM Integration (Gemini + Groq)**: Define strict JSON schema; implement prompt, parse and fallback logic (High).  
2. **Prompt Engineering**: Master prompt guiding AI structure; fallback prompt for summarization (High).  
3. **Hover/Overlay UI**: Fix `MouseRegion`/`OverlayEntry` to show hover card; add actions (TTS, Summarize, Expand, Open Full, Mini). Draggable mini-widget (High).  
4. **Design System / Accessibility**: Establish fonts, spacing, colors; add dyslexia-friendly option, focus mode, reduce-motion toggle (High).  
5. **Module/Lesson Schema & Generation**: Structured course/module data model; incorporate wiki links, image/graph queries, quizzes (Medium).  
6. **Text-to-Speech (flutter_tts)**: Integrate and control speech playback (Medium).  
7. **OCR Integration**: Use ML Kit text recognition + `permission_handler` for camera → auto-summarize/format (Medium).  
8. **Image/Graph Fetching**: Integrate Google Custom Search or Bing Image API for visuals, or use Unsplash for free images (Low).  
9. **Testing & CI/CD**: Write unit/widget/integration tests【31†L125-L133】; set up GitHub Actions for building and testing (High).  

## System Architecture and Data Flow  

```mermaid
flowchart LR
    subgraph "User"
        U[User Input]
    end
    subgraph "Flutter App"
        P[Prompt Builder]
        API[Gemini API<br>(REST)] 
        FAPI[Groq API<br>(OpenAI-Compatible)]
        V[JSON Parser/Validator]
        UI[UI Renderer]
    end
    U --> P
    P --> API
    P --> FAPI
    API --> V
    FAPI --> V
    V --> UI
```

**Figure:** *Data flow: user input goes to a prompt builder which calls Gemini (primary) or Groq (fallback). The JSON response is validated/parses and then rendered in the UI.*  

## JSON Schema and LLM Prompts  

### JSON Schema (Gemini/Groq Output)  
Define a strict JSON schema for all outputs. For example:

```json
{
  "type": "object",
  "properties": {
    "type": {"enum": ["lesson","summary"]},
    "title": {"type": "string"},
    "summary": {"type": "string"},
    "key_points": {"type": "array", "items": {"type": "string"}},
    "detailed_explanation": {"type": "string"},
    "examples": {"type": "array", "items": {"type": "string"}},
    "visuals": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "type": {"enum": ["image","graph"]},
          "query": {"type": "string"}
        },
        "required": ["type","query"]
      }
    },
    "wikipedia_links": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {"title":{"type":"string"},"url":{"type":"string","format":"uri"}},
        "required": ["title","url"]
      }
    },
    "interactive": {
      "type": "object",
      "properties": {
        "questions": {"type":"array","items":{"type":"string"}},
        "quiz": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "question": {"type":"string"},
              "options": {"type":"array","items":{"type":"string"}},
              "answer": {"type":"string"}
            },
            "required": ["question","options","answer"]
          }
        }
      }
    },
    "accessibility": {
      "type": "object",
      "properties": {
        "simplified_text": {"type":"string"},
        "audio_script": {"type":"string"}
      }
    }
  },
  "required": ["type","title","summary","key_points"]
}
```

Gemini (and Groq) will be instructed to use this schema (via `response_format`/JSON schema) so they output valid JSON【21†L198-L206】【25†L261-L268】.  

### Master Prompt (Gemini, Groq)  
```
You are an educational AI tutor for neurodivergent learners. Output a JSON object matching the schema above. Use clear, simple language. Short sentences and bullet points only. Include an image search query and Wikipedia links.  
- If user asks a topic: type="lesson" and teach it.  
- If user provides text: type="summary" and summarize.
```
We append the actual user query after this system prompt. The prompt should mention:
- The exact JSON schema (as instructions or via API `json_schema` config).
- Behavioral rules (keep it calm, structured).
- GPT-4’s structured output guidelines mention using JSON schema【21†L198-L206】.

**Groq Fallback Prompt:** Use the same content, since Groq supports OpenAI-compatible chat format【25†L260-L268】. For example:
```json
{"role":"system","content":"<Master prompt including schema>"},
{"role":"user","content":"<User query>"}
```

### Sample Prompts  
- **Lesson Generation:** `"Explain the topic 'Photosynthesis' step by step for ADHD learners."`  
- **Summarization:** `"Summarize this text in easy terms: '<user-provided text>'"`.  
- **TTS Script:** Ensure `audio_script` is simply a spoken version (the prompt should clarify that too).

## API Requests and Examples  

### Gemini API (Generative Language)【18†L300-L309】  
Use REST v1beta:
```bash
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent" \
 -H "x-goog-api-key: $GEMINI_API_KEY" \
 -H "Content-Type: application/json" \
 -d '{
      "contents": [{"parts":[{"text": "Explain photosynthesis for neurodivergent learners in JSON."}]}],
      "response_format": {"type":"json_schema","json_schema": {/*schema as above*/}}
   }'
```
**Response:** JSON with a `candidates[0].content` field containing a JSON string. Parse it and validate.  

### Groq API (OpenAI-compatible)【25†L100-L104】【25†L261-L268】  
URL: `https://api.groq.com/openai/v1/chat/completions`.  
Request JSON (using `messages` like ChatGPT):
```json
{
  "model": "llama-3.3-70b-versatile",
  "messages": [
    {"role": "system", "content": "<master prompt + schema>"},
    {"role": "user", "content": "Explain photosynthesis in JSON."}
  ],
  "response_format": {"type":"json_schema","json_schema": {/*schema*/}}
}
```
**Response:** Contains `choices[0].message.content` with JSON. Use `model=llama-3.3-70b` (production, costs ~$0.59/$0.79 per 1M tokens【26†L277-L286】).  

## Error Handling & Fallback Rules  
- **JSON Validation:** Immediately attempt to parse. If parse fails or required fields missing, trigger fallback or default.  
- **Fallback Triggers:** Invalid JSON, empty result, or **output lacking key fields** like `title` or `summary`. Timeouts/errors also trigger fallback.  
- **Fallback Behavior:** On error from Gemini, switch to Groq using same prompt and schema. If Groq fails, use a simple static fallback (e.g. *“Could not generate. Please try again.”*) or a very short summary prompt.  
- **Rate/Cost Control:** If queries are frequent, cache responses (especially repeated queries). Monitor tokens; consider setting `max_tokens` to reasonable limits.  
- **Routing:** Optionally, use a lightweight rule (e.g. if query mentions "image" or >8000 chars, prefer Gemini【27†L179-L188】). For most short text, default to Groq for speed.  

## JSON Parser Pseudocode  
```pythno
response = call_gemini_api(prompt, schema)
try:
    data = json.loads(response)
except JSONDecodeError:
    # Gemini output invalid, try Groq
    response = call_groq_api(prompt, schema)
    try: data = json.loads(response)
    except:
        raise FallbackException("AI output invalid")

# Validate required fields
for field in ["title","summary","key_points"]:
    if not data.get(field):
        # Missing required content
        # e.g., fallback or error
        raise ValidationException(f"Missing {field}")

# If all good, return parsed JSON data structure
return data
```

## Flutter Implementation Details  

### Hover Circle & Overlay (MouseRegion/OverlayEntry)  
- Wrap hover target in a `MouseRegion` widget. Provide `onEnter` and `onExit` callbacks. Use `opaque: false` and `behavior: HitTestBehavior.translucent` to capture events through transparent areas.  
- On `onEnter`, create an `OverlayEntry` (using `Overlay.of(context).insert`) to show the hover card. Set `overlayEntry.opaque = false` so it doesn’t block everything【7†L38-L46】.  
- On `onExit`, remove the overlay entry (`overlayEntry.remove()`).  
- Ensure the hover card’s z-order is above app UI (Overlay does this by default). For cross-app: *iOS prohibits persistent overlay above other apps*. On Android, system alert windows (needs platform channels) but typically not allowed in Flutter app context without special permission. *Note:* true cross-app overlay isn't possible on iOS; Android needs special APIs. We’ll target in-app overlay only.  
- **Implementation Sketch:**  
  ```dart
  class HoverTarget extends StatefulWidget { ... }
  class _HoverTargetState extends State<HoverTarget> {
    OverlayEntry? _hoverOverlay;
    void _showOverlay() {
      _hoverOverlay = OverlayEntry(builder: (ctx) => HoverCardWidget(...));
      Overlay.of(context)!.insert(_hoverOverlay!);
    }
    void _hideOverlay() {
      _hoverOverlay?.remove();
      _hoverOverlay = null;
    }
    @override
    Widget build(BuildContext context) {
      return MouseRegion(
        onEnter: (_) => _showOverlay(),
        onExit:  (_) => _hideOverlay(),
        child: widget.child
      );
    }
  }
  ```  
- **HitTestBehavior:** If the hover region isn’t responding, ensure parent containers do not absorb pointer events (use `behavior: HitTestBehavior.translucent`).  

### Draggable Mini Floating Widget  
- Use an `OverlayEntry` for the mini widget, also. Make it draggable: wrap content in `GestureDetector` and update position on `onPanUpdate`.  
- **State:** Keep the mini-widget’s position in app state (e.g. using Provider/Riverpod). On drag, update state to reposition `OverlayEntry`.  
- Example structure:  
  ```dart
  class MiniWidget extends StatefulWidget { ... }
  class _MiniWidgetState extends State<MiniWidget> {
    Offset position = Offset(50, 100);
    @override Widget build(BuildContext context) {
      return Positioned(
        left: position.dx, top: position.dy,
        child: Draggable(
          feedback: buildContent(),
          child: buildContent(),
          onDragEnd: (details) {
            setState(() { position = details.offset; });
          },
        ),
      );
    }
  }
  ```  
- **Visibility:** The mini-widget should remain on-screen; provide an "X" or close button to remove it.  

### Flutter Packages  
- **State Management:** Use `provider` or `riverpod` for global state (current lesson data, mini-widget visibility).  
- **Networking:** `http` or `dio` for API calls (Gemini/Groq/Image/Wiki).  
- **TTS:** `flutter_tts` (already example in pub.dev【9†L128-L136】).  
- **Image Caching:** `cached_network_image` for network images.  
- **Charts:** `fl_chart` or `charts_flutter` for any graphs.  
- **Notifications:** `flutter_local_notifications` if needed for reminders (optional).  
- **Permissions:** `permission_handler` to request camera/microphone.  
- **OCR:** `google_ml_kit` or `flutter_barcode_scanner` (text recognition) for scanning text.  

### UI Design System (Typography, Spacing, Colors)  
- **Typography:**  
  - **Fonts:** Default to a clear sans-serif (Roboto/Arial). Offer a dyslexia-friendly font option (e.g. [OpenDyslexic, Dyslexie][16†L300-L309]).  
  - **Sizes:** Body ≥16pt (WCAG recommends ≥16px for readability)【16†L330-L338】. Headings larger (20–24pt).  
  - **Line Spacing:** ≥1.5× line height, letter spacing ~0.12em, word spacing ~0.16em【16†L339-L348】.  
  - **Alignment:** Left-aligned text (more predictable for dyslexia【16†L362-L370】).  
- **Color Palette:**  
  - **Background:** Off-white/light (e.g. #FAFAF9) to reduce glare【16†L152-L160】.  
  - **Text:** Dark gray/black (≥4.5:1 contrast vs background)【23†L1-L4】.  
  - **Accent:** Muted blues/greens, no highly saturated neons.  
  - **Buttons:** Distinct color (e.g. calm blue) with clear labels/icons.  
- **Spacing/Grid:** Use an 8dp baseline grid (padding 8/16/24/32).  
- **Components:** Cards with subtle shadow and rounded corners (12–16dp radius).  
- **Accessibility Toggles:** In settings, allow enabling “High Contrast” (darker backgrounds), “Dyslexia Font”, “Reduce Motion”.

## Hover Card UI Specification  
When user hovers (desktop) or long-presses (mobile) a topic card, display a floating card with:  
- **Title** (larger font) and short 1–2 line **summary**.  
- **Action Buttons** (icon + label):  
  - 🔊 **Play**: Plays `audio_script` via TTS.  
  - 📜 **Simplify**: Toggles between normal and `simplified_text`.  
  - 📖 **Expand**: Opens detailed explanation (expands card or navigates to lesson screen).  
  - 📂 **Open Full**: Switch to full-screen lesson view.  
  - 🪟 **Mini**: Activate mini floating widget.  
- **Layout:** Buttons in a row or grid with adequate spacing (target ~48px each). Use tooltips for clarity.  
- Example snippet (conceptual):  
  ```dart
  Column(
    children: [
      Text(data.title, style: titleStyle),
      Text(data.summary, style: bodyStyle),
      Row(children: [
        IconButton(icon: Icons.play_arrow, onPressed: _playTTS),
        IconButton(icon: Icons.text_snippet, onPressed: _toggleSimplify),
        IconButton(icon: Icons.menu_book, onPressed: _expand),
        IconButton(icon: Icons.open_in_new, onPressed: _openFull),
        IconButton(icon: Icons.filter_tilt_shift, onPressed: _openMini),
      ])
    ]
  )
  ```

### Mini Floating Widget Behavior  
- **Content:** Minimal: title, play/pause TTS button (along with progress), maybe a close “X”.  
- **Draggable:** User can drag it anywhere on screen (update position state).  
- **Persistence:** Remains on top of app UI, even if navigating to other screens (use a global overlay).  
- **Controls:**  
  - 🔊 **Play/Pause**: Starts/stops TTS. While reading, optionally highlight text (if main UI showing it).  
  - ✖️ **Close**: Removes mini-widget overlay.  
- **Example:** The mini-widget could be implemented as an `OverlayEntry` containing a `Positioned` that wraps a `GestureDetector` (as sketched above).  

## Module and Lesson Generation Flow  
- **Structure:** Each module has a title and summary; contains multiple lessons. Each lesson has summary, details, examples, visuals, links, quiz.  
- **Generation Steps:**  
  1. **User selects a topic or course.**  
  2. **Prompt LLM:** Use the master prompt with `type="lesson"` or `"summary"`.  
  3. **LLM Response:** Parse JSON into a Lesson object.  
  4. **Post-process:**  
     - Fetch each `visuals.query` image via API (below).  
     - Verify `wikipedia_links` and fetch titles/URLs (could trust LLM or use MediaWiki API for accuracy).  
     - Store lesson object in local database.  
  5. **UI:** Render lesson with headings, bullet lists. Embed images from fetched URLs. Insert interactive quiz UI.  

- **Example Schema Snippet:**  
  ```yaml
  Module:
    - title: "Biology Basics"
    - summary: "Intro to biology for different learners"
    - lessons:
        - id: "lesson1"
          title: "Photosynthesis"
          summary: "Plants make food from sunlight."
          examples: ["Example1", "Example2"]
          visuals: [ {type:image, url:"...", caption:"..."} ]
          wikipedia_links: [ {title:"Photosynthesis",url:"..."} ]
          questions: ["Q1", "Q2"]
          quiz: [ {question:"...", options:["A","B"], answer:"A"} ]
  ```  

## Image and Graph Fetching Strategy  
- **APIs:**  
  - **Google Custom Search** (with `searchType=image`) or **Bing Image Search API** (Azure). Both are official and support query restrictions.  
  - **Unsplash API**: For free high-quality images (randomness; might not match query exactly).  
- **Implementation:**  
  - After LLM returns a `visuals` query, make an HTTP request to the image API.  
  - Use `cached_network_image` to display and cache the result.  
  - For charts/graphs, either find an illustrative image or use a chart library (`fl_chart`) to draw based on sample data from LLM (optional, since LLM might not generate numeric data easily).  
- **Fallback:** If no image found, display a placeholder or skip that visual.  

## Flutter Text-to-Speech Integration【9†L128-L136】  
- Use `flutter_tts` package. Initialize and configure voice/rate.  
- On Play button tap: `flutterTts.speak(lesson.audio_script)`.  
- Handle completion and cancellation events to update UI (e.g. disable Play button while speaking).  
- Provide controls: volume, rate slider in settings.  

## Interaction: Camera OCR → TTS/Summarize  
- Use `google_ml_kit` or `camera` + `vision` to capture text from camera.  
- On capture, run `TextRecognizer` to get string.  
- Prompt LLM: either summarize or explain captured text (`"Summarize the scanned text..."`).  
- This is effectively an alternate input path feeding into the same LLM system.  

## UI Design for Neurodivergent Users【16†L325-L334】【16†L339-L348】  
- **Fonts:** Sans-serif for general text; dyslexia-friendly font option.  
- **Spacing:** Ample whitespace. Increase line-height (≥1.5) and letter spacing【16†L339-L348】.  
- **Contrast:** Ensure 4.5:1 contrast for text【23†L1-L4】. Avoid all-caps.  
- **Layout:** Break content into small paragraphs (max 4 sentences), use bullet lists for steps (reduces cognitive load).  
- **Controls:** Big touch targets (≥48dp).  
- **Modes:** Offer “Focus mode” toggling UI elements off, “Read-aloud mode” where text is highlighted as read.  

## Gemini vs Groq (Tradeoff Table)  

| Characteristic      | Gemini (Google)                           | Groq (Llama 3.3)                         |
|---------------------|-------------------------------------------|------------------------------------------|
| **Model Family**    | Google Gemini 3.1 Pro (multimodal)        | Llama 3.3 70B (text)【26†L277-L286】       |
| **Strengths**       | Highest accuracy, reasoning, image tools  | Fast (<100ms) text, low cost            |
| **Weaknesses**      | High latency (~400ms text)【27†L164-L172】, expensive ($2,200/mo @10M tokens)【27†L155-L163】 | Lower accuracy on complex questions (HumanEval 78% vs 91%【27†L139-L142】) |
| **JSON Accuracy**   | 99.4% (virtually perfect)【27†L139-L144】 | 98.1% (still excellent)【27†L139-L144】    |
| **Cost (1M tok)**   | ~$1.00 input + $3.00 output (example)     | ~$0.05 input + $0.08 output【27†L171-L179】 |
| **Use Case**        | Complex reasoning, images, multimodal     | Routine text Q&A, fallback summaries     |
| **Fallback Role**   | Primary for long/contextual queries       | Fallback for speed/cost, short queries   |

*Data from NeuraPulse analysis【27†L139-L144】【27†L171-L179】.*  

## Testing and Quality Assurance【31†L125-L133】  
- **Unit Tests:** Verify JSON parsing, prompt builder, and any logic (e.g. TTS text passed correctly).  
- **Widget Tests:**  
  - Test UI components (e.g. a `Text` widget shows title). Example:  
    ```dart
    testWidgets('Lesson title appears', (tester) async {
      await tester.pumpWidget(MaterialApp(home: LessonCard(title: 'Test')));
      expect(find.text('Test'), findsOneWidget);
    });
    ```  
  - Test hover card appears on `MouseRegion` enter.  
  - Test mini-widget drag (might simulate by gesture).  
- **Integration Tests:** Run on emulator/device: simulate search for a topic, verify a lesson card shows, hover to open card, press TTS, etc. Use Flutter’s `integration_test` package【31†L125-L133】.  
- **LLM Output Tests:** Provide mocked AI responses (good JSON vs malformed) to ensure parser handles them properly (fallback triggered).  
- **Accessibility Checks:** Use tools or manual checks for contrast, text scaling, screen reader flow.  

## CI/CD and Deployment  
- **CI (GitHub Actions):**  
  - On push to main: run `flutter test` (unit & widget) on Linux, iOS, Android.  
  - On pull request: run tests.  
- **Build:** Automated builds for Android APK and iOS (IPA). Use `flutter build apk/ios`.  
- **Beta Deployment:** Use Fastlane or GitHub Actions to upload to TestFlight and Google Play Internal for testers.  
- **Release:** After QA, merge to main and push release to stores.  
- **Monitoring:** Setup error monitoring (e.g. Sentry) to catch runtime issues post-release.  

## Timeline with Milestones  

| Phase                      | Tasks                                                               | Owner           | ETA       | Complexity |
|----------------------------|---------------------------------------------------------------------|-----------------|-----------|------------|
| **1. LLM & Schema Setup**  | Define JSON schema; craft master prompts (Gemini+Groq); implement API clients; parsing & fallback logic; simple console tests | Backend/AI Dev   | 2 weeks   | High       |
| **2. UI Overhaul**         | Establish design system (fonts, colors, spacing); refactor existing screens with accessible UI; typography and layout fixes | UI/Flutter Dev   | 2 weeks   | Medium     |
| **3. Hover & Overlay**     | Fix `MouseRegion` hover; implement `OverlayEntry` hover card; action button handlers; draggable mini-widget with state | Flutter Dev      | 1 week    | High       |
| **4. Features Integration**| Integrate `flutter_tts`; OCR text capture with ML Kit; image search API calls; build module/lesson data model; quizzes UI | Fullstack Dev    | 2 weeks   | Medium     |
| **5. Testing & CI**        | Write unit, widget, integration tests【31†L125-L133】; configure GitHub Actions for tests/build; fix bugs | QA/DevOps        | 1 week    | Medium     |
| **6. Deployment**          | Build final release; submit to App Store/Play Store; set up monitoring | DevOps/PM        | 1 week    | Low        |

_Total ~7–8 weeks for MVP features._ Estimates assume a small team. Complexity: Low/Medium/High scale.  

## Prioritized Task Table  

| Task                             | Owner          | ETA      | Complexity |
|----------------------------------|----------------|----------|------------|
| Define JSON schema & prompts     | AI/Backend Dev | 2 days   | Medium     |
| Gemini API integration           | Backend Dev    | 3 days   | High       |
| Groq fallback integration        | Backend Dev    | 2 days   | Medium     |
| JSON validation & fallback logic | Backend Dev    | 2 days   | High       |
| Design system (fonts/colors)     | UI/Flutter Dev | 3 days   | Medium     |
| Refactor main UI screens         | UI/Flutter Dev | 4 days   | High       |
| Implement Hover/Overlay card     | Flutter Dev    | 3 days   | High       |
| Mini-widget (draggable overlay)  | Flutter Dev    | 2 days   | Medium     |
| Integrate flutter_tts (audio)    | Flutter Dev    | 2 days   | Low        |
| OCR text capture (ML Kit)        | Flutter Dev    | 3 days   | Medium     |
| Image search API integration     | Flutter Dev    | 2 days   | Low        |
| Module/lesson model & saving     | Fullstack Dev  | 2 days   | Medium     |
| Quiz UI & logic                  | Flutter Dev    | 1 day    | Low        |
| Unit tests (parsing, etc.)       | QA/DevOps      | 2 days   | Medium     |
| Widget tests (UI elements)       | QA/DevOps      | 2 days   | Medium     |
| Integration tests                | QA/DevOps      | 3 days   | High       |
| Setup CI/CD pipelines            | DevOps         | 3 days   | Medium     |
| Beta deployment & release        | DevOps/PM      | 2 days   | Low        |

## Sample Prompts  

- **Summarization Prompt:**  
  *System (Gemini):* *“You are an AI tutor for neurodivergent students. Output JSON with keys title, summary, etc. Summarize very simply.”*  
  *User:* `"Summarize this text: 'Photosynthesis converts sunlight into energy...'"`  

- **Lesson Generation Prompt:**  
  *System:* *(as above)*  
  *User:* `"Teach me about Photosynthesis."`  

The system prompt includes the JSON schema and instructions for output.  

## Notes on Cross-App Overlay (Hover Circle)  
- **iOS Limitation:** iOS apps cannot draw over other apps. The hover/mini features are **in-app only**. We can ensure the mini-widget persists within our app navigation using `Overlay` or a top-level `Stack`.  
- **Android:** It’s possible to create an app overlay (via system alert window), but Flutter does not natively support this without platform-specific code and permissions. Given complexity, we focus on in-app overlay. (An external service or plugin would be needed for true cross-app overlays.)  

## Conclusion  
By combining a well-structured LLM prompting strategy with an accessible Flutter UI, NEUROSPACE can deliver high-quality, tailored learning content. This plan provides the detailed steps, data schemas, code sketches, UI specs, and timelines needed for implementation.  

**Sources:** Gemini API docs【18†L300-L309】【21†L198-L206】; Groq API docs【25†L261-L268】【26†L277-L286】; LLM comparison study【27†L139-L144】【27†L171-L179】; Accessibility typography guidelines【16†L325-L334】【16†L339-L348】; Flutter testing guidelines【31†L125-L133】; Flutter TTS example【9†L128-L136】.