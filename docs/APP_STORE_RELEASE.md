# Glean release preparation

Status: development candidate; not submitted to App Review.

## Product description draft

Turn everyday information into something useful. Share text, images or PDFs to Glean, review the extracted text, and save a note on your iPhone. An optional local AI download helps identify information and suggest actions. Review every detail before adding a calendar event, reminder or checklist.

Your shared content is processed locally. The AI model is a separate download of approximately 984 MB. Reading and saving source text does not require the model. Back Tap is optional and requires the user's Shortcuts and Accessibility setup. Glean does not monitor other apps or read a personal WhatsApp inbox.

## Release gates still open

- Paid Apple Developer Program enrollment and App Store Connect access confirmed by the owner.
- Distribution bundle identifiers, App Groups and signing profiles registered to that team; current development identifiers are not a distribution configuration.
- Public support and privacy-policy URLs, store screenshots, age rating, export-compliance answers and privacy disclosures completed and verified against the shipped binary.
- iPhone acceptance tests: clean install with no model, share text/image/PDF, source-only save, optional model download/removal, AI refusal/recovery, confirmed Calendar/Reminders writes, cancellation, screen lock, backgrounding and interrupted downloads.
- Held-out accuracy evaluation and manual review. Extractive validation reduces unsupported prose but cannot prove correct interpretation, category, intent or completeness. A passed unit test is not an accuracy result.
- Gmail OAuth client and callback configuration, consent/verification requirements and end-to-end sign-in tested before advertising Gmail account connection. Personal WhatsApp remains user-initiated sharing, not an account integration.
- TestFlight build uploaded and exercised before public submission. App Review approval is controlled by Apple.

## Storage

The approximately 1 GB footprint is primarily optional model weights, not an allocation for notes. A development app bundle measured about 60 MiB; App Store compressed/download size must be measured from a distribution build. The smaller 351 MB model failed quality checks and remains excluded from the shipping registry. Do not advertise it as a tested replacement.

## Reviewer notes draft

Glean can read and save shared source text without an account or an AI download. To test AI, install the optional local model in Settings, then share synthetic content into Glean and analyze it while keeping the app in the foreground. Proposed actions require review and confirmation. Back Tap is configured through the system Shortcuts and Accessibility features; it is not automatically enabled by the app.

## Owner submission sequence

1. Complete the open gates above and choose the final supported feature set.
2. Archive the Release scheme using the paid distribution team, validate in Xcode Organizer and upload to App Store Connect.
3. Complete a TestFlight pass on physical devices and record defects and results.
4. Attach the tested build, verified metadata, screenshots and reviewer instructions, then submit for App Review.
5. Release only the approved build. No upload, approval or publication is implied by a successful local build.
