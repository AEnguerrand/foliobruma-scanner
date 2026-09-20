# Foliobruma Scanner

![Foliobruma Scanner — old letters under a document camera](Resources/Brand/README-logo.png)

**Turn books, letters, and paper documents into PDFs on your Mac.**

Foliobruma is a free, open-source document camera app. Place a page under the camera, let it capture, then turn the page after the saved signal. Your scans stay on your Mac. No account or internet connection is required.

> Early version for Apple Silicon Macs. Tested with the **IRIScan Desk 6 Pro**. Use a release download when available, or build from source below. Releases have no Apple Developer ID signature or notarization. Automatic updates are not available.

## What it does

- **Automatic capture:** waits for a clear, still page and checks for movement, hands, and recent duplicate scans.
- **Automatic crop:** detects paper edges and corrects perspective.
- **Book mode:** splits a spread into two pages, with an adjustable spine position.
- **Capture feedback:** uses sounds and visual signals for saved pages, duplicates, obstructions, and rejected scans.
- **Page review:** browse a page sidebar, zoom, rotate, reorder, merge two pages, crop from the original, replace a page, or undo the last removal.
- **Saved sessions:** browse documents by name, page count, and edit date. Original images stay on your Mac.
- **PDF export:** save the pages in the current document to a local PDF.

There is no OCR, cloud upload, QR code generation, or telemetry in this version. Exported PDFs contain page images, without a searchable text layer.

## Download and install

Open [Releases](https://github.com/AEnguerrand/foliobruma-scanner/releases/latest)
and download the **macOS-arm64.dmg** file for the required version. Open it,
then drag **Foliobruma Scanner** to **Applications**. Eject the disk image and
open the app from Applications. You need an Apple Silicon Mac with macOS 14
or later. Xcode and Command Line Tools are not required for release downloads.
A ZIP download is also available.

The app has an ad-hoc signature, but no Apple Developer ID signature or
notarization. If macOS blocks it and you trust the download, try to open it,
then use **System Settings → Privacy & Security → Open Anyway**. Follow the
[Apple instructions](https://support.apple.com/en-us/102445). A managed Mac can
prevent this exception. Allow camera access when asked.

To update, quit the app and replace it in Applications. Saved sessions remain
in their current folder. See [release install instructions](RELEASE-INSTALL.txt)
for checksums and backup steps. If no release exists yet, build from source.

## Build and open

You need an Apple Silicon Mac, macOS 14 or later, and Apple Command Line Tools with a macOS 14 or newer SDK. Intel builds are not supported by the current scripts.

Install the tools if needed, then wait for the installation to finish:

```sh
xcode-select --install
```

Clone the repository and build the app:

```sh
git clone https://github.com/AEnguerrand/foliobruma-scanner.git
cd foliobruma-scanner
./build.sh
open "build/Foliobruma Scanner.app"
```

Allow camera access when macOS asks. The build uses Apple frameworks and needs no third-party packages or Xcode project. To use a full Xcode installation, set `DEVELOPER_DIR` to its `Contents/Developer` directory when you run the scripts.

The app is signed locally for development. It is not notarized. A rebuild can cause macOS to ask for camera access again.

## Language

The interface supports English and French. On first use, the app follows the
macOS language preference. It uses English when the preferred languages are not
supported.

Open **Foliobruma Scanner → Settings…** (⌘,) or click the gear button in the
toolbar. Select **System language**, **English**, or **Français**. Quit and reopen
the app to apply the change. The selection applies only to this app. Document
names and session files do not change. This setting does not translate scanned
text or add OCR.

## Scan your first document

1. Connect the scanner by USB. In **Scan setup**, select a **Camera** and click **Connect camera**. Use the refresh button if you connected the camera after opening the app.
2. Use the document menu to name your document. In Scan setup, choose **Book** or **Single page**.
3. Put the paper on a contrasting surface with even light. Check that all page edges are visible.
4. Check the gold crop outline. For a book, enable **Split into two pages** and adjust **Spine position** to the centre of the spread. You can also drag the gold handle or click **Centre spine**. Use **Preview crop and split** to inspect a camera frame without saving pages.
5. Click **Start auto capture**, then move your hands away. For manual capture, click **Capture page** or press **Space** in Scan mode.
6. Wait for the green **Saved — turn the page** signal and chime before turning the page. Repeat for each page or spread.
7. Click **Review pages** or choose **Review**. Capture pauses. Select a page in the sidebar, or enter a page number and click **Go**. Zoom and scroll to inspect the text. Use **Rotate**, **Move earlier**, **Move later**, **Remove**, or **Undo removal** as needed.
8. Click **Export PDF**, check the page count and rejected-photo notice, then choose where to save the file. Progress appears at the bottom of the window. Open the result from **Files → Open PDF** or **Show PDF in Finder**.

Use **Documents → New document** for another book or group of pages. The document title menu also contains **New document** and **Rename document…**. Use **Documents** to search saved documents and open one by name. **Open session folder…** remains available for sessions stored elsewhere. Closing the app keeps the session. Returning to Scan does not restart automatic capture.

### Review and correct pages

- **Merge with next page…** joins the selected page (left) and the next page (right) into one page. Use **Move earlier** or **Move later** to put the two pages in order first. The merge uses their current crops and rotations, matches their heights without changing their proportions, and replaces them with one page at the same position. Export again to include the merged page in the PDF. Source images and source page records are kept. **Crop from original…** on a merged page uses the full merged image. The merge does not align overlapping map details or remove a seam. **Undo removal** does not undo a merge.

- **Replace…** returns to Scan to capture one replacement page. A successful save keeps the page position and page identity. The old image and original remain on disk. Split capture is disabled for a replacement. A rejected or failed replacement leaves the existing page in the document.
- **Crop from original…** shows the full original image. Adjust the four edge sliders and save the selected rectangle. For a book spread, select only the required side. This manual crop does not apply perspective correction; the existing page rotation is kept. The original and earlier processed image are retained.
- **Rejected** opens photos that are excluded from the PDF. Inspect the image with zoom before using **Keep this scan anyway**. **Rescan** returns to the camera, but keeps the rejected photo in the review list until you keep or dismiss it. **Dismiss from review** keeps its image file and removes the review entry.
- The footer distinguishes the saved session from the exported PDF. After an edit, **PDF needs export** means that the earlier PDF has not changed. Export again to include the edit. PDF export status applies to the current app session.

Keyboard controls: **⌘O** opens Documents, **⌘N** creates a document, **⌘E** opens the export summary, **← / →** changes the selected review page, **⌘⇧← / ⌘⇧→** moves that page earlier or later, **⌘R** rotates it, and **⌘Z** undoes the last removal. **Space** captures a page in Scan mode. Use Tab to move between controls.

### Review shortcuts

| Shortcut | Action |
| --- | --- |
| **← / →** | Select the previous or next page. |
| **⌘⇧← / ⌘⇧→** | Move the selected page earlier or later. |
| **⌘R** | Rotate the selected page. |
| **⌘⌫** | Remove the selected page, or dismiss the current rejected photo. Image files are kept. |
| **⌘Z** | Undo the last page removal. This does not undo dismissal of a rejected photo. |
| **⌘⇧C** | Open Crop from original. |
| **⌘⇧R** | Replace the selected page, or rescan the current rejected photo. |
| **⌘0** | Fit the review image to the window. |
| **⌘Return** | Keep the current rejected scan, or save the crop in the crop editor. |
| **Escape** | Close rejected-photo review, or cancel the crop editor. |

Saved pages are already included in PDF export. They do not need approval.
Use **Keep this scan anyway** only after you check a rejected photo. Shortcuts
for page changes are disabled while a save or other operation is in progress.

### Capture signals

| Signal | Meaning | What to do |
| --- | --- | --- |
| Green border and saved chime | Page files and the session are saved. | Turn the page. |
| Amber **Already scanned** message and short tone | A recent duplicate was detected. No extra copy was saved. | Turn the page, or use manual capture for an intentional repeat. |
| Small amber warning and soft tone | A hand or missing page edges are blocking automatic capture. | Clear the page and check its position. |
| Red **Rescan needed** message and low tone | The captured photo failed a quality check. It is not in the PDF. | Correct the issue and capture again. |

The speaker switch controls capture sounds. Visual signals remain active when sound is off. A quality rejection pauses automatic capture and opens the rejected-photo review. If a quality check is wrong, inspect the photo before using **Keep this scan anyway**.

Duplicate checks compare image detail with the last four saved captures. Different text pages can pass even when their layout is similar. The check runs again while the page is still; a duplicate warning does not require a page turn to clear. Small shifts or lighting changes can still let a repeat pass. Use manual capture if a different page is blocked.

Automatic capture requires at least 0.55 seconds of a clear, still page. Camera capture, checks, and saving add time. A sustained obstruction produces a warning after 1.5 seconds; brief page-turn movements should not produce a warning tone.

## Your files

Click **Files → Originals and session** to open the current session folder. Sessions are stored at:

```text
~/Library/Application Support/Sovenelia Scanner/Sessions/
```

The old `Sovenelia Scanner` folder name and app identifier are retained to keep existing scans and preferences available.

```text
<session-id>/
├── Originals/    Original captures
├── Pages/        Processed page images
├── Rejected/     Photos rejected by quality checks, when present
└── session.json  Document name, page order, rotations, and rejected-photo review records
```

Removing a page removes it from the document, but keeps its image files. Replacement and crop operations also keep previous image files. Older sessions remain readable. Rejected photos with no saved review record are recovered for inspection; their earlier crop settings may be unavailable. Rejected photos are excluded from PDF export unless you keep them. Exported PDFs are separate files. Back up the whole session folder if you want to retain the originals and continue editing later.

## Current limits

- **Check the crop outline.** Detection works best with clear edges and bright paper against a darker surface. Turn **Auto crop** off if the outline is wrong.
- **Curved pages stay curved.** Perspective correction is supported; curved-book dewarping is not. The spine split is a straight line.
- **Detection can miss problems.** Hand and duplicate checks are approximate. Similar pages can be mistaken for duplicates, and lighting changes can cause duplicates to pass.
- **Review image quality.** Checks cover hands, very dark images, heavy blur, and detected page edges at the camera boundary. They do not reliably detect glare, shadows, missing text, or fine-detail blur.
- **Hardware support is limited.** Other cameras may work, but only the IRIScan Desk 6 Pro has been tested. Live warning timing and sound playback need more hardware testing.

## Troubleshooting

| Problem | Try this |
| --- | --- |
| No camera preview | Check the USB connection and selected camera. Allow the app under **System Settings → Privacy & Security → Camera**, then reopen it. |
| Automatic capture does not start | Check the page edges, remove your hands, and hold the paper still. Review any warning. Use manual capture if needed. |
| An intentional repeat is blocked | Use **Capture page** or **Space** in Scan mode. Manual capture bypasses duplicate detection; quality checks still apply. |
| A good scan is rejected | Review it, then use **Keep this scan anyway** if it is complete and readable. |
| A scan repeats after a lighting change | Pause automatic capture, remove the extra page, and keep the lighting steady. |

## Development

Run the regression tests without connecting a scanner:

```sh
./test.sh
```

Tests use temporary sessions and do not request camera access. They cover session persistence, failed-write recovery, page operations, crop coordinates, capture gates, warning gates, quality rejection with manual override, review capture exclusion, page replacement, original-image preservation, old session decoding, saved-document discovery, and PDF export failure recovery.

Source files are grouped by purpose under `Sources/FoliobrumaScanner/`: app setup,
models, scanner operations, capture gates, image checks, and views. The build and
test scripts include all Swift files in these folders.

GitHub Actions uses separate workflows. **Build** tests and builds branch
pushes, pull requests, and manual runs. **Release** tests, packages, and
publishes only when a version tag (`vX.Y.Z`) is pushed.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the source layout, checks, release steps, and bug report guidance.

## License

[MIT](LICENSE). You can use, modify, and distribute the app, including for commercial use, under the license terms.
