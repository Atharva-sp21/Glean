# Security model

Core invariant: **untrusted input → model → untrusted output → deterministic validation → user authorization → side effect**. Local inference improves privacy; it does not confer authority or make generated facts trustworthy.

```text
Untrusted shared content
        ↓
Input validator / bounded copy
        ↓
OCR / parser
        ↓
UNTRUSTED DATA
        ↓
Local LLM
        ↓
UNTRUSTED MODEL OUTPUT
        ↓
Schema validation
        ↓
Action allowlist
        ↓
User confirmation
        ↓
Durable duplicate guard
        ↓
iOS privileged API
```

## Reporting a vulnerability

This is a private prototype with no production support guarantee. Report security issues privately to the repository owner through the team's existing private contact channel. If GitHub's private vulnerability reporting is enabled for this repository, use **Security → Report a vulnerability**; do not assume that feature is enabled.

Include the affected commit, a minimal synthetic reproduction, the boundary crossed and the observed impact. Do not send real user documents, screenshots, credentials or private calendar/reminder data. Do not open a public issue with exploit details. The repository owner will coordinate assessment and any fix; no response-time SLA is currently promised.

## Threats and boundaries

- **Prompt injection:** screenshots, PDFs, selected text, names and URLs may contain malicious instructions. The prompt identifies them as data and JSON-escapes delimiters. This is defense in depth, not a guarantee that the model ignores injections. The schema enum excludes deletion, sending, uploading, scripts, file access and URL execution. The model has no references to privileged handlers. Semantic red-team cases run separately from unit tests.
- **Improper output handling:** bounded JSON is decoded into a typed schema, with exact known key sets, collection limits, string limits, canonical Unicode, control/bidi checks, strict dates and one action per type. Unrecognized/malformed output fails closed. One bounded regeneration is permitted; rejected output is not put back into the prompt. Native text controls render content; there is no WebView, HTML interpreter, generated code or link activation.
- **Excessive agency:** only create-calendar-event, create-reminder, local-checklist-save, local-information-save and draft-reply are representable. Calendar/Reminder access is requested only from the review flow. Destination, date and title are shown before confirmation. Copy/share and all app deletion controls require user gestures. There is no “execute all” path. User-reviewed edits are validated again.
- **Sensitive information disclosure:** model-download networking lives in ModelDownloadService, which accepts only bundled model manifests. A separate user-initiated GmailConnection reads selected email content through Google OAuth and Gmail APIs. No prompts or private input are given to the service. Ephemeral sessions have no cache, cookies or credential storage. Inference uses local paths; missing assets fail. OSLog records static lifecycle messages only; exception strings and user content are not logged.
- **Supply chain:** only three reviewed, bundled model repositories exist in the registry, with immutable 40-character revisions, expected byte lengths, per-file SHA-256 and license labels. Downloaded code is never executed. Only safetensors/tokenizer/configuration files are included. All files and the exact directory contents are checked before load. Dependency revisions and notices are committed.
- **Unbounded consumption:** reject oversized content before intake where the platform exposes its size; downsample images; reject PDFs above ten pages; bound prompt and generation; serialize inference; monitor thermal state and available process memory; cancel/unload on backgrounding or memory warnings. Model weight size is not treated as total RAM use.

These defenses follow the risk areas in the [OWASP GenAI security project](https://genai.owasp.org/llm-top-10/): prompt injection, disclosure, supply chain, improper output handling, excessive agency and unbounded consumption. They are not a claim of OWASP certification or comprehensive penetration testing.

## Local-data protection

Sensitive files and staging directories use `NSFileProtectionComplete`, atomic writes and backup exclusion. App Group access is limited by signing/entitlements. No credentials are stored; adding secrets in the future requires Keychain. Original image metadata is removed by re-encoding. PDF metadata is retained temporarily with the PDF but is not passed as executable instructions or uploaded.

Successful analysis removes its original source after the result is durable. Pending/failed sources older than 24 hours are removed during startup recovery. Hidden incomplete imports older than an hour are removed. Saved structured content persists until the user deletes it. “Delete All Local Data” removes app content and its journal/measurements; model deletion is separate. Deletion is normal file removal, not a promise of forensic secure erasure on flash storage.

## Network policy

User-initiated model installation and optional Gmail access need network. Gmail uses fixed Google OAuth/Gmail endpoints, read-only scope, ephemeral sessions, PKCE, state checks and memory-only tokens. API redirects are refused and responses are capped at 2 MB. Email previews are not logged or persisted unless imported. Initial requests go to `huggingface.co`; redirects require HTTPS and a Hugging Face domain (`huggingface.co`, subdomains, or `.hf.co` CDN hosts). Redirect URLs are never displayed or logged. Received byte counts are capped and each completed asset is hashed. A refused CDN redirect produces a retryable installation failure, never a broader network fallback.

No inference network API, webpage fetcher, remote OCR, analytics or arbitrary HTTP tool is implemented. The pinned dependency's local model/tokenizer code path was inspected. A physical-device Instruments trace is still required to verify zero inference traffic. Calendar/Reminders and explicit draft sharing may cause the chosen destination app/account to sync reviewed content; the review screen discloses this.

## Model updates

1. Review upstream model provenance, architecture, safetensors layout, tokenizer template and license.
2. Resolve a specific immutable commit. Obtain large-file SHA-256 from repository LFS metadata; independently hash all small configuration/tokenizer assets. For stronger release assurance, independently download/hash weights in controlled CI and sign the catalog.
3. Review the manifest diff, including added files and exact size changes. Never update a pin automatically at application launch.
4. Run core checks, Xcode tests, malformed-asset tests and synthetic/adversarial benchmarks.
5. Repeat iPhone 15 online/offline memory, thermal, cancellation and network-trace acceptance. Upgrade dependency pins only with equivalent checks.
6. Ship the catalog with the signed application. Existing downloaded revisions are not silently replaced.

## Known limitations / release gates

- No iOS build, physical inference or real permission-sheet testing was possible on the build host. See BUILD_STATUS.md.
- Token-level grammar-constrained generation is not implemented in the pinned MLX release. Malformed output can fail even for ordinary inputs. Validation/authorization remain mandatory after any future grammar upgrade.
- Deterministic validation cannot establish factual truth or guarantee that adversarial text does not influence a suggestion. The human must inspect reviewed content. Benchmark keyword checks are deliberately modest semantic checks.
- Cancellation/deadline checks occur between model tokens. Synchronous prefill, GPU work, OCR and PDFKit calls cannot always be preempted immediately. Input limits reduce this exposure; they are not a hard real-time sandbox.
- Available-memory checks are advisory and cannot guarantee freedom from jetsam. Peak MLX memory is not total process RSS. Larger developer models may be refused on iPhone 15.
- Share Extension v1 accepts one attachment; some host providers may not expose the preferred file representation. Safari accessible page text is not implemented. File picker import is available in the main app.
- Two processes can race on aggregate inbox quota checks even though item publication is atomic. No private content is overwritten, but a strict cross-process global quota would need locking for a commercial release.
- OS suspension delays expiry cleanup. App Group protection relies on device lock protection, not independent user authentication. Screenshots, keyboards and compromised/jailbroken systems are outside this app's guarantees.
- At-most-once action reservation trades retry convenience for duplicate prevention after ambiguous failures. EventKit is not transactionally coordinated with the local journal.
- Hashes anchor assets to the bundled catalog; they do not prove the original publisher was uncompromised. Model catalogs are not separately signed in this prototype.
- The privacy manifest and bundled dependency required-reason declarations need the normal Xcode archive/App Store review before distribution.

## Verification distinction

Unit/harness tests validate malicious output rejection, delimiter handling, size/date/Unicode policy, asset corruption, no-model/error handling, cancellation and denied-permission routing with fakes. They do **not** claim the actual model passed the screenshot attacks. The model benchmark screen and device acceptance checklist exist to measure that separately.
