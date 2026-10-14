# Gmail and WhatsApp account connections

Status: Gmail read-only OAuth and a recent-email picker are implemented, but live sign-in requires a registered Google iOS client. No client was found for Glean in the project. WhatsApp remains a selected-content import flow.

## Gmail setup for the app owner

1. Open [Google Cloud Console](https://console.cloud.google.com/) and create or select a project for Glean.
2. In APIs & Services → Library, enable Gmail API.
3. In Google Auth Platform → Branding, configure Glean's app name and contact email.
4. Choose External audience for personal Gmail accounts. Keep the app in Testing and add your Gmail address as a test user.
5. Under Data Access, add `https://www.googleapis.com/auth/gmail.readonly`. This permits reading email; it does not permit sending or deleting it. The scope covers the mailbox even if Glean's UI imports only selected messages.
6. Under Clients, create an OAuth client of type iOS. Use the app target's exact Bundle Identifier from Xcode → PrivateAction target → Signing & Capabilities. The checked-in default is `com.example.PrivateAction`; use your actual value if you changed it.
7. Provide the iOS client ID and its registered bundle ID to configure Glean. No password or client secret is needed. The reversed client ID becomes the callback URL scheme.

The flow is explicit Google sign-in, a picker of the 20 latest inbox messages, email preview, and Add to Glean. Open the imported item in Inbox to analyze it. HTML-only emails and bodies exceeding 12,000 characters require copying relevant text instead. Reading mail requires internet access to Google; local AI processing remains on the phone. Account disconnection clears in-memory credentials and temporary email previews, while imported items remain under Glean's existing deletion controls.

Gmail read access is a restricted scope. Public distribution requires meeting Google's applicable verification requirements; a developer test setup is not production approval.

References: [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios/start-integrating), [OAuth consent](https://developers.google.com/workspace/guides/configure-oauth-consent), [Gmail scopes](https://developers.google.com/workspace/gmail/api/auth/scopes).

## WhatsApp: choose the account type first

Personal WhatsApp chats are not exposed as a mailbox through the official WhatsApp Business Platform. Continue using Share, Copy, or a screenshot for those chats.

A Business integration is a separate feature: messages addressed to a configured WhatsApp Business number can arrive through Meta's API and webhooks. It needs a Meta app, WhatsApp Business account/number, and a hosted webhook backend. Business API tokens belong on the backend, not in the iPhone app or repository. This also changes the data path: incoming messages pass through that backend before Glean can import them. Do not present it as direct access to a user's personal chat history.

Before implementation, choose whether this Business-number workflow is actually wanted. No backend or Meta account has been configured by these instructions.


## Wire the client into a build

Set these user-defined build settings on the app target (Debug and Release):

- `GLEAN_GOOGLE_CLIENT_ID`: the real iOS OAuth client ID.
- `GLEAN_GOOGLE_REVERSED_CLIENT_ID`: the same ID with dot-separated components reversed.

`Configuration/App-Info.plist` reads those values. The OAuth redirect is `<reversed-client-id>:/oauth2redirect`. No client secret belongs in this native app. Authentication uses the system browser with PKCE and state validation. Tokens are memory-only; leaving the Gmail screen or relaunching requires signing in again. Disconnecting clears local access but does not revoke Google's account grant; revoke that through your Google Account's third-party connections if desired.

Live sign-in and Gmail retrieval have not yet been verified with an OAuth client. No external account changes have been made.
