# USB button setup

[Documentation](README.md) · [Project overview](../README.md)

Open **Settings → USB button**. Select the device, select an action, then click
**Learn button** and press the physical button once. Learning stays active until
you press or click **Cancel**. **Signals received** shows input from the selected
device, even before learning. Press it again to check the
**Test presses** counter. Enable **Enable button action**, close Settings, and
select the document window. The setting is saved on this Mac.

| Action | Suggested use |
| --- | --- |
| **Capture page** | Recommended for a scanner button or foot control. Uses manual capture with the normal quality checks. |
| **Start or pause auto capture** | Start or stop a scanning run without the keyboard. |
| **Next document** | Save the current document and start an empty document. Requires at least one saved page. |
| **New item…** | Open the form for a new document or metadata record. |
| **Next letter** | Start the next letter in the current batch, with shared batch details. |
| **Finish sheet** | Save the front and optional back, upload and print when enabled, then prepare the next sheet in a sheet batch. |
| **Review pages** | Pause capture and inspect saved pages. |
| **Export PDF** | Open the export summary. You still choose the file location. |

One device and one learned signal can be assigned at a time. Actions run only
in the active document window. They are blocked in Settings, dialogs, and while
the app is busy. Reports less than 0.6 seconds apart are treated as one press;
wait at least 0.6 seconds between presses. Device removal stops input. Reconnect
to the same USB port if the device has no serial number, or select and learn it
again. A disconnected saved device remains in the selector.

The IRIScan button with USB ID `2e5a:2015` sent a repeatable signal during a local
test. Other USB HID button or vendor controls can be learned if they send the
same report for each press. Keyboards, mice, and devices with changing report
counters are not supported by this setting. Test the counter before enabling
an action: a release or an idle report must not count as another press. This
feature does not change camera detection, capture quality checks, or saved files.

See [Records and batches](batches.md) for letter and sheet actions.
