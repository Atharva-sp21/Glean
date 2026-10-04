# Get unstuck

[← Back to Glean](../README.md)

| What you see | What to try |
|---|---|
| Home folder or `.bash_history` in Xcode | Open the repository's `PrivateAction.xcodeproj` file |
| Can't find TARGETS | Click the blue project icon in the far-left sidebar; TARGETS appears in the middle column |
| “Choose an app to run” | Cancel. In the top toolbar select the **PrivateAction** scheme, not PrivateActionShare |
| Invalid local package repository | Use **File → Packages → Reset Package Caches**, then **Resolve Package Versions**; let downloads finish |
| Metal Toolchain required | Choose **Download & Install**, wait, then run again |
| Signing requires a development team | Select your team in each target's Signing & Capabilities |
| No devices available for provisioning | Connect/unlock/trust the phone and select it in the toolbar, then retry |
| Phone charges but isn't visible | Check Finder → Locations; try a data-capable cable and another port |
| Developer Mode disabled | Enable on the iPhone under Settings → Privacy & Security, restart and confirm |
| Untrusted Developer | Trust your own development account in Settings → General → VPN & Device Management |
| Storage setup/App Group error | Match the app/extension entitlements and `PRIVATE_ACTION_APP_GROUP`; rebuild and unlock the phone |
| Analyze disabled | Download the model inside Glean's Settings; wait for other operations to finish |
| Missing shortcut action | Install latest build, open Glean, then reopen Shortcuts |

## “Local AI returned an invalid result”

The app rejected model output; this is not proof that your file is corrupt. Known device failures include missing or extra JSON fields. Omitted list fields can normalize to empty arrays, while required fields and unknown keys remain checked.

Open **Glean → Settings → Developer → Benchmark → Measured local runs**. Share a screenshot showing the diagnostic and token counts. You do not need to run the synthetic suite just to see ordinary analysis measurements.

| Diagnostic | Meaning |
|---|---|
| `top_level_keys missing=[…] extra_count=…` | Missing required fields or unexpected fields |
| `field_type_or_enum` | Wrong value type or unsupported category/action |
| `field_constraint` | JSON decoded but a validation constraint failed |
| `markdown_wrapper` / `thinking_markup` | Extra formatting instead of the expected JSON object |
| `token_limit_invalid_json` | Output reached its cap and was not valid JSON |
| `empty_output` / `invalid_json` | Empty response or malformed JSON |

Diagnostics do not retain document text or arbitrary model-generated key names. A separate failure entry can show zero token counts because generation metrics were unavailable; zero there does not prove the model generated nothing.

If you still see “Detailed timing unavailable,” install the current build with **⌘R**. Changing code on the Mac does not update an already-installed app automatically.

## Crash or pause in Xcode

- **SIGKILL:** the process was terminated; this label alone does not identify the cause. Note whether it occurred at launch, during analysis or after closing the app.
- **Metal BackgroundExecutionNotPermitted / SIGABRT:** GPU work was attempted while backgrounded. Keep Glean visible and unlocked. A background GPU crash has been observed; lifecycle hardening is still a release gate.
- Click Stop and run again after capturing the error. Do not delete your app or model as the first troubleshooting step.

For useful reports, include the device/iOS version, input type, action taken, diagnostic and relevant Xcode console error. **⌘⇧Y** shows the debug area. Review logs for personal information before sharing. Never send passwords, signing keys or an entire unrelated console history.
