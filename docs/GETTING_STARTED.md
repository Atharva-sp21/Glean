# Get Glean onto your iPhone

[← Back to Glean](../README.md)

This guide installs the source build from Xcode. There is no App Store or TestFlight release in this repository.

## 1. Prepare your Mac

Install full **Xcode** from Apple. Open it and complete its initial setup, including the iOS platform components. Use an Xcode version that supports your iPhone's iOS version and the pinned Swift dependencies. Recent development builds used Xcode 26.6.

If Xcode asks for **Metal Toolchain**, choose **Download & Install**. MLX needs it to compile GPU code. For a real iPhone you do not need to download a simulator runtime solely to install the app.

In **Xcode → Settings → Apple Accounts**, add your Apple Account. Enter passwords only into Apple's dialogs, never into source code or GitHub.

## 2. Download and open the project

Clone the private repository with an authorized GitHub account, or download and extract its ZIP. Open **PrivateAction.xcodeproj** inside the project folder.

If navigation is confusing, in Finder press **⌘⇧G**, paste the path to your downloaded project folder, and open `PrivateAction.xcodeproj`. Do not open your home folder or `.bash_history`.

Wait for Package Dependencies to resolve and indexing to finish. Keep the committed dependency versions.

## 3. Understand the three Xcode selectors

| Control | Where it is | What it changes |
|---|---|---|
| Project | Blue PrivateAction icon in the far-left sidebar | Opens project settings |
| Target | Middle column under TARGETS | Signing/settings for app, extension or tests |
| Scheme and device | Very top toolbar | What Xcode runs and where |

For installation, the top toolbar must show **PrivateAction → your iPhone**, not PrivateActionShare. Running the extension scheme asks you to choose a host app.

## 4. Set up signing

Click the blue project icon. Under **TARGETS**, select **PrivateAction → Signing & Capabilities**.

1. Enable **Automatically manage signing**.
2. Select your team from **Team**. Use Add Account if none is available.
3. Choose a unique bundle identifier, such as `com.yourname.Glean`.
4. Repeat for **PrivateActionShare**, using the same team and a child identifier such as `com.yourname.Glean.Share`.
5. Select the same team for **PrivateActionTests**, using an appropriate test identifier such as `com.yourname.Glean.Tests`.

### App Group: the app and extension must agree

Both components need the same shared storage container.

1. Under the project's **Build Settings**, choose **All**, search `PRIVATE_ACTION_APP_GROUP`, and set it to an App Group registered to your team, for example `group.com.yourname.Glean`.
2. Under **Signing & Capabilities → App Groups**, register/select that exact group for both PrivateAction and PrivateActionShare.
3. Ensure both entitlement files match that group or use `$(PRIVATE_ACTION_APP_GROUP)`. Both Info.plists use the build setting to locate shared storage.

Do not leave different groups in the two targets. Signing availability depends on your team; if Xcode rejects a capability, read the exact error rather than assuming account sign-in alone enables it. Do not buy a membership solely on the basis of this guide.

## 5. Connect the phone

1. Connect your iPhone directly with a cable that supports data.
2. Unlock the phone and keep it awake.
3. Accept **Allow accessory to connect** on the Mac if shown.
4. On the iPhone, tap **Trust This Computer** and enter its passcode.
5. Confirm the iPhone appears in Finder under **Locations**.
6. In Xcode, open **Window → Devices and Simulators** if the phone is not yet available in the toolbar. Allow pairing/device preparation to complete.

Charging does not prove a data connection. If Finder cannot see the phone, try another cable or USB port.

## 6. Enable Developer Mode and run

On your iPhone, open **Settings → Privacy & Security → Developer Mode**. Enable it, restart if prompted, then unlock and confirm **Turn On**.

In Xcode choose **PrivateAction → your iPhone**, then press **⌘R**. Allow the initial build to finish.

- **codesign keychain prompt:** enter the Mac login-keychain password (normally your Mac login password). Allow grants access for this request; Always Allow persists access for future signing.
- **Untrusted Developer on iPhone:** open **Settings → General → VPN & Device Management**, select your own development account, and trust it. Follow any verification/restart prompts and keep an internet connection for verification.

Glean should launch. Signing credentials and provisioning profiles are local; never commit private keys.

## 7. Save source text or install the optional local model

To read and save without a model, open an inbox item and choose **Read & save without AI**. To try AI analysis, inside **Glean on the iPhone**, tap **Settings → Download Local AI Model**. This is not Xcode's Build Settings or the iPhone Settings app.

Use the default **Qwen3 1.7B 4-bit**. Its pinned files total 984,013,244 bytes, about 984 MB. Allow additional space for installation and app data. Prefer Wi-Fi and keep Glean open until the download finishes. Do not select a larger experimental model for initial testing.

## 8. Your first analysis

Choose **Paste or type text** in Glean, enter a short note, add it to Inbox, open it and tap **Analyze Locally**.

For a calendar test, use a future date relevant to you:

> Project review on 10 October 2026, from 7 PM to 8 PM India Standard Time.

Review the extracted facts. For an Event result, choose **Add to Calendar**, grant permission, select a writable calendar, set/check start and end, enable **I checked the date and time**, and confirm. Open Apple Calendar to verify exactly one event. Do not assume a successful analysis means an event was saved.

[Everyday use →](USING_GLEAN.md) · [Back Tap →](SCREENSHOT_SHORTCUT.md) · [Troubleshooting →](TROUBLESHOOTING.md)
