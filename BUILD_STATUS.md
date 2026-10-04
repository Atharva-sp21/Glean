# Glean · verification record

Updated 4 October 2026. This distinguishes compilation, deterministic tests and actual device observations.

| Check | Evidence and limits |
|---|---|
| Full iOS app and Share extension build | Local unsigned builds passed with Xcode 26.6, including the shortcut, sharing and event-review changes |
| Core XCTest | 26 tests passed at the latest action-review update |
| Deterministic security harness | 48 checks passed at the output-handling update |
| Repository and boundary checks | Passed; rerun for each documentation/code update |
| Physical iPhone installation | User installed, trusted and launched the app |
| Real local inference | User screenshots show successful event classification/summary and earlier invalid-output failures; not a broad accuracy pass |
| Calendar review option | Implemented and unit-tested to require date confirmation; actual Calendar write not yet confirmed by evidence |
| Back Tap | App Intent compiles and appears in the user's Shortcuts editor; complete capture-to-analysis acceptance remains unconfirmed |
| Share-to-analysis handoff | Implemented; complete physical-device acceptance remains pending |
| Background GPU behavior | A Metal background-execution crash was observed; not resolved by documentation or successful builds |
| Performance, battery, thermal, offline/network acceptance | No controlled results published |
| Simulator UI, accessibility and release archive | No complete acceptance record published |

The [initial core CI run](https://github.com/Atharva-sp21/private-action/actions/runs/37121429541) passed for the original implementation. That historical run does not establish the current device feature status.

## Before a release

- Validate extraction against representative screenshots, messages and PDFs, including ambiguous dates and malicious instructions.
- Verify a calendar event/reminder is created exactly once, with permission-denied behavior and correct timezone handling.
- Exercise Share Sheet, cold/warm launch, Back Tap, missing models, busy state and interruption recovery.
- Fix and test safe handling of app inactivity during GPU work.
- Measure memory and thermal behavior on the intended iPhone 15 baseline; verify offline inference and network boundaries.
- Complete accessibility, privacy, licensing and distribution review.

Passing unit tests and builds is not equivalent to passing these device gates. See [BENCHMARKING.md](BENCHMARKING.md).
