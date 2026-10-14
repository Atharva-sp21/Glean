# Use Glean

[← Back to Glean](../README.md)

## Share from another app

1. Select a text snippet, image, screenshot or PDF.
2. Open the source app's Share menu and choose **Glean**. Look under **More** if needed.
3. Wait for **Saved to Glean**, tap **Done**, then open Glean.
4. The newest shared item opens for analysis. Older items remain in Inbox.
5. Keep the phone unlocked and Glean in the foreground.

The Share extension saves content; it does not run the model or automatically launch the main app. If the model is missing or another operation is running, the item remains available for later analysis. Share one attachment at a time.

## Paste a message

If an app offers Copy rather than Share, copy the message. In Glean choose **Paste or type text**, paste it into the editor and tap **Add to Inbox**. Open the item and tap **Analyze Locally**. Glean does not poll your clipboard.

## Import an existing image or PDF

Choose **Import a photo or PDF** from the home screen, or use the **+** menu. Select a file, open its inbox item and analyze. Limits include 20 MB input, 10 PDF pages and 12,000 extracted characters; the model also has a 3,072-token input budget. Dense files can reach the token limit before other limits.

## Choose an action

| Action | What you do | What happens |
|---|---|---|
| Add to Calendar | Check title, dates, times and destination; confirm | One calendar event is created |
| Create Reminder | Choose list, edit content and optional due date; confirm | One reminder is created |
| Save Checklist | Review the checklist | A local checklist appears in Saved |
| Save Information | Review title and summary | A local note appears in Saved |
| Draft Reply | Edit, then explicitly copy or share | Text goes to your clipboard or chosen share destination |

Available suggestions vary. Event-classified results always offer calendar review. Other actions depend on validated model suggestions. Nothing is written to Calendar/Reminders just because analysis succeeds. Calendar/Reminder accounts can sync approved content through their own services.

Dates need special care: check the year, timezone, start and end. A summary mentioning “Saturday” is not enough to establish the intended date. Defaults in the form are not proof of extraction accuracy.

## Optional screenshot shortcut

Use [Back Tap setup](SCREENSHOT_SHORTCUT.md) to capture the current screen and hand it to Glean without manually uploading it. It captures all visible content, not only a selected message.

## Storage and privacy

- Original sources are removed after successful analysis. Failed/pending sources expire through startup cleanup after 24 hours; cleanup is not an exact-time background guarantee.
- Saved notes and checklists stay until deleted.
- **Settings → Delete All Local Data** clears app data, action history and measurements. It does not remove calendar events or reminders already created.
- **Delete Selected Model** removes the local model; other data remains.
- Deleting action history also removes the local duplicate-submission guard, so inspect Calendar before repeating an action.

## Current boundaries

Glean does not monitor chats, control WhatsApp, import entire recurring timetables, reconcile existing events or send replies automatically. Inference quality is still under device testing. Keep the app visible during analysis; see [known issues](TROUBLESHOOTING.md).

### WhatsApp and Gmail

Open **Inbox → From WhatsApp or Gmail**, or **Settings → Import from apps → WhatsApp & Gmail**. These are selected-content import flows, not account connections.

- **WhatsApp:** copy a message and paste it into Glean. For photos or documents, use the system share sheet if WhatsApp offers it. Screenshots are another option.
- **Gmail:** copy the relevant email text, including its subject and dates, and paste it into Glean. Share supported attachments or capture a screenshot when text selection is inconvenient.
- **Back Tap:** the setup guide is available from this screen. It requires one-time configuration in Shortcuts and iPhone Settings.

Personal WhatsApp chats are not automatically read. Gmail sign-in and a recent-email picker are available once the developer configures Google OAuth; automatic inbox synchronization is not implemented. See [account setup](ACCOUNT_CONNECTIONS.md).

### Delete individual items

Swipe left on an Inbox or Saved row, tap **Delete**, then confirm. Full-swipe deletion is disabled. The row is removed with an animation only after its local file is deleted successfully; errors leave it visible. Deleting an inbox item keeps separately saved notes. Neither flow deletes previously created calendar events or reminders. Deletion is permanent after confirmation.

## Use Glean without downloading AI

Open an unprocessed item and choose **Read & save without AI**. Review the extracted text, correct any OCR mistakes, and choose **Save note**. This saves source text locally without loading a language model. AI analysis is optional; its model download is separate from the app.

AI output now has a conservative source-excerpt check. Unsupported text is rejected, and unverified people, locations and model-generated timestamps are omitted. This does not guarantee correct interpretation. If analysis fails, use source review instead. Always verify dates and actions before confirming them.
