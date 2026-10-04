<p align="center">
  <img src="docs/assets/glean-logo.png" alt="Glean — emerald light on midnight blue" width="220" />
</p>
<h1 align="center">Glean</h1>
<p align="center"><strong>A little context. A clear next step.</strong><br />Turn shared messages, screenshots and documents into useful actions—on your iPhone.</p>
<p align="center">
  <a href="docs/GETTING_STARTED.md">Install on iPhone</a> ·
  <a href="docs/USING_GLEAN.md">Use Glean</a> ·
  <a href="docs/SCREENSHOT_SHORTCUT.md">Set up Back Tap</a> ·
  <a href="docs/TROUBLESHOOTING.md">Get unstuck</a>
</p>

---

## Less collecting. More doing.

A meeting buried in a message. A task in a screenshot. A PDF worth remembering.

**Share → Understand → Review → Act.** Glean extracts context locally and helps you turn it into a calendar event, reminder, checklist or saved note. You decide what gets saved.

| Give Glean | Get a starting point |
|---|---|
| A meeting invitation | An editable calendar event with date/time review |
| A task or deadline | A suggested reminder, when produced by the model |
| A screenshot or photo | Text extracted with Apple Vision, then analyzed locally |
| A PDF | A summary and relevant actions |
| A text selection | Structured information without writing a prompt |
| A shared website link | Analysis of supplied metadata; the webpage is not fetched |

> **Working prototype, still being tested.** The app builds for iOS and has run on a physical iPhone. Real-device analysis has produced both successful results and schema failures. Calendar writes, Back Tap handoff, background handling and extraction quality still need full device acceptance testing. See the honest [verification record](BUILD_STATUS.md).

## Three ways in

### 1. Share to Glean · the everyday route

In another app, choose **Share → Glean**. Wait for **Saved to Glean**, tap **Done**, then open Glean. The newest shared item opens and begins analysis when Glean is ready. Review the result before taking an action.

Source apps offer different sharing options. If WhatsApp only offers Copy for your message, paste the text into Glean instead.

### 2. Paste or import · always available

Open Glean and choose **Paste or type text**, or **Import a photo or PDF**. Open the resulting inbox item and tap **Analyze Locally**.

### 3. Back Tap · optional convenience

Use an Apple Shortcut to connect **Take Screenshot → Analyze Screenshot in Glean**, then assign it to Back Tap. Glean opens and starts analysis automatically. No manual photo upload is needed. [Step-by-step setup →](docs/SCREENSHOT_SHORTCUT.md)

## Put Glean on your iPhone

You need a Mac with full Xcode, an Apple Account, a compatible physical iPhone and a data-capable cable. The project targets iOS 17 or later; actual model performance depends on the device. Standard iPhone 15 is the intended baseline.

1. Clone this private repository using an authorized GitHub account.
2. Open **PrivateAction.xcodeproj** in Xcode and let packages resolve.
3. Select your signing team and configure the same App Group for the app and extension.
4. Connect and trust your iPhone; enable Developer Mode when prompted.
5. Select **PrivateAction → your iPhone** in the top toolbar and press **⌘R**.
6. Inside Glean, open **Settings → Download Local AI Model**.

**New to Xcode?** Follow the [complete iPhone setup guide](docs/GETTING_STARTED.md). It explains project versus target versus scheme, signing, device trust, model installation and your first test.

The product is **Glean**. Internal names such as `PrivateAction.xcodeproj`, `PrivateActionCore` and the `PrivateAction` scheme remain unchanged so existing installations and development workflows continue to work.

## Local intelligence. Explicit actions.

- **On-device processing:** SwiftUI, Vision OCR, PDFKit and MLX Swift. No cloud AI endpoint or analytics.
- **One model download:** Qwen3 1.7B 4-bit, approximately 984 MB; pinned revisions and SHA-256 verification. Apple Intelligence is not required.
- **Review before writing:** Calendar and Reminders require permission, a destination and explicit confirmation. Event results offer a calendar review option even if the model omits that suggestion.
- **Untrusted output:** schema validation, bounded retries and action allowlists. Missing list fields may normalize to empty arrays; unknown fields remain rejected.
- **Protected intake:** images are re-encoded, originals are removed after successful analysis, and stale source cleanup runs at startup. Saved results remain until deleted.

Calendar/Reminder accounts may sync the content you approve. Explicitly sharing a reply draft passes it to the chosen app. Read the [security model](SECURITY.md) for boundaries and limitations.

## What Glean does not do yet

It does not silently read WhatsApp, float over other apps, automatically send messages, fetch webpages, or import an entire recurring timetable. It creates individual reviewed calendar events; it does not reconcile existing schedules. Background GPU execution is not supported—keep Glean visible and your iPhone unlocked while analyzing. Model output can still fail validation.

## For builders

```sh
git clone https://github.com/Atharva-sp21/private-action.git
cd private-action
open PrivateAction.xcodeproj
```

The generated project is included; XcodeGen is optional. `project.yml` is its source. Regenerating may reset local signing choices, so preserve them before running XcodeGen.

```sh
swift test --package-path Core
swift run --package-path Core SecurityChecks
python3 Scripts/check_boundaries.py
python3 Scripts/check_repository.py
```

| Folder | Responsibility |
|---|---|
| `App/`, `Views/` | Lifecycle, shortcut handoff and native UI |
| `ShareExtension/`, `Processing/` | Share Sheet intake, OCR and PDF extraction |
| `AI/` | Local inference, verified downloads and benchmark cases |
| `Actions/`, `Core/` | Executors, validation, authorization and storage |
| `Configuration/`, `Resources/` | Signing configuration, model catalog and artwork |
| `Tests/iOS/`, `Scripts/`, `.github/` | Tests, policy checks and CI |

## Read more

[Architecture](ARCHITECTURE.md) · [Security](SECURITY.md) · [Device testing](BENCHMARKING.md) · [Build status](BUILD_STATUS.md) · [Roadmap](docs/ROADMAP.md) · [Contributing](CONTRIBUTING.md) · [Model licenses](MODEL_LICENSES.md) · [Original brief](SPECIFICATION.md)

Private prototype. No open-source license has been selected for original app code. Third-party code and model weights retain their own licenses. User-supplied brand artwork is included as the project logo; no independent rights clearance is claimed.
