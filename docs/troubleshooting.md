# Troubleshooting and limits

[Documentation](README.md) · [Project overview](../README.md)

## Troubleshooting

| Problem | Try this |
| --- | --- |
| No camera preview | Check the USB connection and selected camera. Allow the app under **System Settings → Privacy & Security → Camera**, then reopen it. |
| Automatic capture does not start | Check the page edges, remove your hands, and hold the paper still. Review any warning. Use manual capture if needed. |
| An intentional repeat is blocked | Use **Capture page** or **Space** in Scan mode. Manual capture bypasses duplicate detection; quality checks still apply. |
| A good scan is rejected | Review it, then use **Keep this scan anyway** if it is complete and readable. |
| A scan repeats after a lighting change | Pause automatic capture, remove the extra page, and keep the lighting steady. |

## Current limits

- **Check the crop outline.** Detection works best with clear edges and bright paper against a darker surface. Turn **Auto crop** off if the outline is wrong.
- **Curved pages stay curved.** Perspective correction is supported; curved-book dewarping is not. The spine split is a straight line.
- **Detection can miss problems.** Hand and duplicate checks are approximate. Similar pages can be mistaken for duplicates, and lighting changes can cause duplicates to pass.
- **Review image quality.** Checks cover hands, very dark images, heavy blur, and detected page edges at the camera boundary. They do not reliably detect glare, shadows, missing text, or fine-detail blur.
- **Hardware support is limited.** Other cameras may work, but only the IRIScan Desk 6 Pro has been tested. Live warning timing and sound playback need more hardware testing.

## Automatic capture and crop limits

Automatic duplicate checks compare the paper content as well as the full frame.
A hand, label, or lighting change outside the paper should not count as a page
turn. Paper comparison reduces camera noise and aligns small position changes.
Similar pages, or a page with only a small new note, can need manual capture;
detection is approximate.
External document cameras use video frames at the selected format’s full size,
without a still-photo output that can force a lower stream resolution. The
IRIScan Desk 6 Pro was verified at 4160 × 3120 (8 fps). Built-in cameras retain
the still-photo output.
The resolution shown in Scan setup and the crop outline use the dimensions of
the frames actually received.
The scanner uses the full-resolution camera frame when the still-photo output
has less detail or a different aspect ratio, so it does not cut off the preview.
Auto crop finds edges again on the captured photo because the photo and preview
can have different framing. It keeps a small outer margin and uses the paper
mask when a rectangle would cut into it. Original photos stay in the session;
use **Crop from original** to adjust a saved page.
