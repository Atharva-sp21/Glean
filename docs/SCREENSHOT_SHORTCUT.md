# Screenshot to Glean

Install the current build on your iPhone and open Glean once. Download its local model before using automatic analysis.

## Create the shortcut

1. Open Apple's **Shortcuts** app and tap **+**.
2. Name the shortcut **Glean Screenshot**.
3. Add the **Take Screenshot** action.
4. Add **Analyze Screenshot in Glean** (search Glean in the actions list).
5. Set its **Screenshot** parameter to the output of **Take Screenshot**.
6. Save the shortcut and run it once to complete any system permission prompts.

Do not add Save to Photo Album: the shortcut can pass the image directly to Glean.

## Assign Back Tap

On your iPhone, open **Settings → Accessibility → Touch → Back Tap → Double Tap** (or Triple Tap), then choose **Glean Screenshot**.

While the message is visible, trigger Back Tap. Glean opens the imported screenshot and starts local analysis. Keep Glean visible and your phone unlocked during inference. Review the suggested action and confirm its date, time and destination before saving.

## Behavior and limits

- The shortcut captures everything visible, potentially including surrounding messages. It does not read WhatsApp history or monitor notifications.
- The screenshot is validated, downsampled and re-encoded before entering the existing protected inbox.
- If no model is installed, the item remains available and Glean prompts you to install one.
- If another operation is running, the screenshot is saved for manual analysis.
- No calendar or reminder is created by the shortcut itself. Existing review and authorization checks still apply.
- Existing model-output failures can still occur; this shortcut changes capture and navigation, not inference reliability.
- Back Tap and actual-device shortcut execution require device testing. An iOS build alone does not establish that the complete flow works.

## Connect the Screenshot parameter

If the second action displays **Screenshot: Choose**, touch and hold **Choose**. Select **Select Variable** or **Select Magic Variable**, then select the output beneath **Take Screenshot**. The field should display that Screenshot variable rather than a fixed file. Labels can vary with iOS version.

## Test Back Tap

1. Display a short test meeting note in Notes.
2. Double- or triple-tap the back of the unlocked phone, matching your assignment.
3. Confirm Glean opens the captured image and begins analysis.
4. Check the extracted facts before approving anything.

If nothing happens, run the shortcut once directly in Shortcuts and complete the system prompts, then try Back Tap again. If Glean opens but analysis fails, the capture handoff worked; troubleshoot inference separately. Do not test only from the shortcut editor, which would capture the editor itself.

If **Analyze Screenshot in Glean** is missing, install the latest build, open Glean once, reopen Shortcuts and search again. Double-clicking the power button is not the trigger configured by this guide.

[← Everyday use](USING_GLEAN.md) · [Troubleshooting](TROUBLESHOOTING.md)
