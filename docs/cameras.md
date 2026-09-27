# Camera compatibility

[Documentation](README.md) · [Project overview](../README.md) · [Présentation en français](../README.fr.md)

The app requires an Apple Silicon Mac with macOS 14 or later. Camera capture
and a camera's physical USB button are separate features. A working preview
does not prove that the button, automatic capture, or every resolution works.

## Recorded results

This table collects the results already recorded in the project documentation.
It was compiled on 27 September 2026. This is not a new hardware test date.
No complete hardware test record for v0.4.0 is available here.

| Camera or control | Evidence status | Capture result | USB button result | macOS / app version | Test date |
| --- | --- | --- | --- | --- | --- |
| IRIScan Desk 6 Pro | Prior project test; partial record | Received video frames at 4160 × 3120, 8 fps. Full capture and warning sequence not recorded. | See the separate control row below. | Not recorded | Not recorded |
| IRIScan USB control, ID `2e5a:2015` | Prior local signal test; partial record | Not a camera image test. | Repeatable input signal received. This does not verify each assigned action. | Not recorded | Not recorded |
| Other USB document cameras | Unverified | No recorded hardware result. | No recorded hardware result. | — | — |
| Built-in Mac cameras | Unverified | The app has a still-photo path; no recorded hardware result in this table. | Not applicable | — | — |

Sources: [capture resolution and limits](troubleshooting.md#automatic-capture-and-crop-limits)
and [USB signal test](usb-button.md). Do not use these partial records as a
purchase guarantee. Test your own camera before a large scanning job.

## Check your camera

Use blank or synthetic paper, even light, and a contrasting surface.

1. Connect the camera. In **Scan setup**, select it and click **Connect camera**.
   Note the resolution shown by the app.
2. Use **Capture page**. Check that the saved page is complete and readable.
3. Start automatic capture. Check a stable page and then a page turn.
4. Move a hand into and out of the frame. Record the warnings and saved pages.
5. Present the same page again. Then change the lighting. Record both missed
   captures and unwanted duplicates. Detection is approximate.
6. Review the pages and export a PDF. Check page order, crop, and rotation.
7. If the camera has a button, follow [USB button setup](usb-button.md). Check
   the signal counter, then the assigned action with Settings closed.

## Report a result

[Open a camera test issue](https://github.com/AEnguerrand/foliobruma-scanner/issues/new?title=Camera%20test%3A%20)
and copy this form. Report failed and partial tests as well as successful ones.
A user report stays marked as a user report unless a maintainer repeats it.

```text
Camera make and exact model:
Mac model and chip:
macOS version:
Foliobruma version:
Test date (YYYY-MM-DD):
Connection (direct USB / hub and model):
Resolution shown in Scan setup:
Manual capture and saved image:
Automatic capture: stable page / page turn:
Hand entering / leaving the frame:
Duplicate page / lighting change:
PDF export, page order, crop, and rotation:
USB button ID, signal counter, and assigned action (if tested):
What did not work or was not tested:
```

Do not attach private documents, session folders, account details, or device
serial numbers. If an image is needed, use synthetic test material.
