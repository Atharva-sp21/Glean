# Getting started

Build and install Glean on a physical iPhone. This is a source prototype; see the [verification status](../BUILD_STATUS.md) before testing.

## Open and run

1. Install full Xcode (16.3 or newer, with an iOS SDK supporting your device). Select it in Xcode Settings → Locations → Command Line Tools.
2. Open **PrivateAction.xcodeproj**. Use the `PrivateAction` scheme.
3. In both app and Share Extension targets, set your Apple Developer team and unique bundle identifiers. Replace `PRIVATE_ACTION_APP_GROUP` in project build settings with an App Group registered to your team, for example `group.com.yourcompany.PrivateAction.privateaction`. Enable that same group for both targets. The two entitlements and Info.plists already reference the shared build setting.
4. Resolve packages using the committed `Package.resolved`. If a newer Xcode offers dependency upgrades, keep the pins until you explicitly review them.
5. Select your physical **standard iPhone 15**. Build and run. The deployment floor is iOS 17; device support depends on your installed Xcode. Simulator use is for UI/intake tests, not MLX performance claims.
6. Open Settings → Download Local AI Model. The default download is **984,013,244 bytes** across all pinned model/tokenizer files (about 984 MB decimal). No weights are bundled in this source deliverable.
7. Add text from the inbox, or share one screenshot/image, PDF, text selection or website address from another app. In the Share Extension, tap Done and open Glean from the Home Screen. Open the inbox item and tap Analyze Locally.
8. Review a suggested action. For Calendar/Reminders, explicitly grant access, choose a writable destination, review/edit fields, confirm the date if present, then tap Add.

The Share Extension intentionally uses the supported manual handoff. It does not use responder-chain tricks, private selectors or an unsupported automatic app launch. Safari webpages are not fetched. URL metadata support is limited to the address, supplied title and any text provided by the host in v1; no Safari page-text preprocessing JavaScript is installed.

## What is implemented

- Native SwiftUI Inbox, Analysis, Saved, Settings, Developer and Benchmark screens.
- App Group inbox with atomic publication, complete file protection, backup exclusion, source expiry and post-analysis source deletion.
- One shared attachment at a time; image metadata stripped via bounded re-encoding; Vision OCR; native PDF extraction with per-page OCR fallback; URL metadata only.
- Qwen3 1.7B 4-bit by default; the requested 1.7B 8-bit and 4B 4-bit variants are session-only developer choices. Only the selected model downloads.
- Pinned model revisions, per-file size and SHA-256 verification, bounded downloads, progress, cancellation/retry and model deletion. Interrupted files restart; completed verified files are reused.
- Model abstraction, one generation at a time, thinking disabled, greedy decoding, 3,072-token input, 512-token output, token-boundary cancellation/deadlines, thermal/memory checks and cache release.
- Strict typed output validation, bounded retry, allowlisted actions, user-edited approvals and a durable duplicate-action guard.
- Calendar and Reminder creation, local saved information/checklists, editable reply drafts with explicit copy/share. No delete-event, send-message, arbitrary URL, file-upload or code-execution capability is exposed to the model.
- A 20-case synthetic benchmark suite and content-free local metrics. Semantic checks are heuristics, not proof against prompt injection.

MLX LM is pinned to **2.29.3** for the Swift 6.1-compatible integration. This release has no `MLXGuidedGeneration` product. Generation uses a hardened schema prompt plus strict validation and at most one retry, **not token-level grammar constraints**. Upgrading to a newer guided-generation dependency is a documented next step after compilation and tokenizer/device validation; it must not weaken the validator or approval boundary.

## Checks

From this directory:

```sh
swift build --package-path Core
swift run --package-path Core SecurityChecks
python3 Scripts/check_boundaries.py
```

The standalone harness uses deterministic fakes for the model and privileged executors. It runs without downloading weights or contacting the network. It does not establish real offline MLX behavior.

With full Xcode installed:

```sh
swift test --package-path Core
xcodebuild -project PrivateAction.xcodeproj -scheme PrivateAction \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Choose an installed simulator name. The XCTest sources cover core policy and lifecycle; the app-hosted tests add image/PDF handling and model-manifest checks. For hardware validation follow [BENCHMARKING.md](../BENCHMARKING.md), including the two supplied screenshot acceptance cases.

`project.yml` is the source for the generated project. With XcodeGen 2.46.0, regenerate using `xcodegen generate`; preserve/commit the dependency lockfile afterward. No XcodeGen installation is needed to open the included project.

## Privacy and action semantics

Content stays in the app/App Group until you approve a platform action or explicitly share a draft. Calendar and Reminders may sync through the destination account you select; that is visible in the review UI. Copies to the clipboard use local-only, two-minute expiry. The app does not read the clipboard automatically.

Delete All Local Data clears inbox, saved items, action journal and benchmark records. Delete Selected Model removes the selected model and its partial download. Local-data deletion does not remove events or reminders already added to iOS.

Raw sources expire after 24 hours when the app next performs startup cleanup. iOS may suspend the app, so deletion is not guaranteed at the exact expiry time. Encryption is iOS Data Protection; this is not a separate app vault with its own key. Saved content is excluded from backup, but no app can promise to control screenshots or all OS behavior.

See [ARCHITECTURE.md](../ARCHITECTURE.md), [SECURITY.md](../SECURITY.md), [MODEL_LICENSES.md](../MODEL_LICENSES.md) and [BUILD_STATUS.md](../BUILD_STATUS.md).
