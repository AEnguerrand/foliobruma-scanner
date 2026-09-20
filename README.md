# Foliobruma Scanner

![Foliobruma Scanner — old letters under a document camera](Resources/Brand/README-logo.png)

**Turn books, letters, and paper documents into PDFs on your Mac.**

Foliobruma is a free, open-source document camera app. Place a page under the camera, let it capture, then turn the page after the saved signal. Your scans stay on your Mac. Local scanning needs no account or internet connection. Optional upload connects to your Foliobruma account.

> Early version for Apple Silicon Macs. Tested with the **IRIScan Desk 6 Pro**. Use a release download when available, or build from source below. Releases have no Apple Developer ID signature or notarization. Automatic updates are not available.

## What it does

- **Automatic capture:** waits for a clear, still page and checks for movement, hands, and recent duplicate scans.
- **Automatic crop:** detects paper edges and corrects perspective.
- **Book mode:** splits a spread into two pages, with an adjustable spine position.
- **Capture feedback:** uses sounds and visual signals for saved pages, duplicates, obstructions, and rejected scans.
- **Page review:** browse a page sidebar, zoom, rotate, reorder, merge two pages, crop from the original, replace a page, or undo the last removal.
- **Saved sessions:** browse documents by name, page count, and edit date. Original images stay on your Mac.
- **PDF export:** save the pages in the current document to a local PDF.
- **Metadata records and letter batches:** save details without a scan. Use automatic references and shared batch details.
- **QR labels:** preview, export, and print a compact label with an existing HTTPS link. QR codes are generated on your Mac.

There is no OCR or telemetry in this version. Cloud upload is optional and off by default. Exported PDFs contain page images, without a searchable text layer.

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

The top row contains Documents, the document title menu, Settings, and the
Foliobruma account control. The second row contains Details, Scan, Review, and
completion actions. In Details, use Add scans to start adding pages. Rejected
scans and Undo removal appear in the footer only when available.

## Scan your first document

1. Connect the scanner by USB. In **Scan setup**, select a **Camera** and click **Connect camera**. Use the refresh button if you connected the camera after opening the app.
2. Use the document menu to name your document. In Scan setup, choose **Book** or **Single page**.
3. Put the paper on a contrasting surface with even light. Check that all page edges are visible.
4. Check the gold crop outline. For a book, enable **Split into two pages** and adjust **Spine position** to the centre of the spread. You can also drag the gold handle or click **Centre spine**. Use **Preview crop and split** to inspect a camera frame without saving pages.
5. Click **Start auto capture**, then move your hands away. For manual capture, click **Capture page** or press **Space** in Scan mode.
6. Wait for the green **Saved — turn the page** signal and chime before turning the page. Repeat for each page or spread.
7. Click **Review pages** or choose **Review**. Capture pauses. Select a page in the sidebar, or enter a page number and click **Go**. Zoom and scroll to inspect the text. Use **Rotate**, **Move earlier**, **Move later**, **Remove**, or **Undo removal** as needed.
8. Click **Export PDF**, check the page count and rejected-photo notice, then choose where to save the file. Progress appears at the bottom of the window. Open the result from **Files → Open PDF** or **Show PDF in Finder**.

Use **Documents → New item…** for another book or group of pages. Select **Scan pages** to use the camera. The document title menu also contains **New item…** and **Rename document…**. Use **Documents** to search saved documents and open one by name. **Open session folder…** remains available for sessions stored elsewhere. Closing the app keeps the session. Returning to Scan does not restart automatic capture.

### Metadata records and letter batches

Open the document title menu and select **New item…** (⌘N). Select **Metadata
only** to record a physical item without a camera, or **Scan pages** to start
with scanning. The title is optional. An empty title uses the automatic
reference. Type, author or sender, date or period, physical location, tags, and
notes are optional details. Use **Details → Edit details** to change them later.
Use **Add scans** to add pages to the same record.

For a batch of letters, enable **Start a letter batch**. Enter the batch name,
location, and tags once. Each letter gets a reference such as `LET-0001`.
**Next letter** saves a new, empty record and copies those three batch fields.
It clears the title, author, date, notes, and web link. It pauses automatic
capture and selects single-page scanning. Start capture again when ready.
All pages of a letter stay in the same record until you select **Next letter**.
A page turn does not create another letter. Editing batch fields affects the
current letter and later letters created from it, not earlier records.

References are unique within this Mac's library, not across devices. Other
items use `DOC-` references and share the same counter. Gaps are possible after
a failed write. References do not change when you rename an item. Documents
can be searched by title, reference, or batch name.

### Sign in, upload, and print

The **Foliobruma** button at the top right shows whether you are signed in.
Click it to connect, select an archive, or change upload and label options.
The same controls are in **Settings → Foliobruma account**. Camera controls
remain in **Scan setup**.

Select **Connect on website**. Your normal browser opens Foliobruma. Sign in on
the website, compare its code with the code in the Mac app, then select
**Connect this scanner**. Return to the app and select the destination archive.
The app checks for approval every three seconds. Requests expire after ten
minutes; **Cancel sign-in** stops waiting. Use **Open sign-in page** to reopen
the request while it is pending.

The app stores a separate, limited scanner credential in Keychain. It does not
read browser cookies or ask for your password. Access expires after seven days.
Use **Connected scanners → Disconnect** on the website to revoke it. Sign out
in the app removes the local credential, revokes scanner access when reachable,
and disables automatic upload. Website logout does not disconnect the scanner.
Older password-based scanner sessions require a new website sign-in.

This flow requires the matching SaaS pairing endpoints and database migration
to be deployed. Until then, connection attempts fail without changing local scans.

Enable **Upload when I finish an item** to send scans to the selected archive.
Enable **Print a label after upload** to open the macOS print dialog after a
successful upload. Both options are off by default. Choose the printer and
confirm printing in the dialog. With the label option off, no print dialog opens.

1. Scan and review all pages of the letter or book. Rejected photos stay excluded
   unless you choose to keep them.
2. Click **Finish item**. The app saves the session, creates one PDF with the saved
   page order and rotations, and uploads it. A page turn does not finish an item.
3. In a letter batch, **Next letter** finishes and uploads the current letter before
   it starts the next one. The USB **Next document** action also finishes first.
   An upload failure keeps the current document open. **New item…** is a local
   creation action; use **Finish item** before it when you want to upload.
4. The label uses the private PDF link. Sign in on the device that reads the QR
   first. A label does not make the document public. Use **Create label…** to
   print again or to print after cancelling the first print dialog.

Upload progress appears in the footer. Uploads accept PDFs up to 500 MiB and use
8 MiB parts. Server storage and membership limits still apply. Metadata stays in
the local session; this API stores the PDF and its filename. No originals or
rejected photos are uploaded. The app must remain open to finish an upload.

After a connection failure, click **Finish item** again. The app reuses the saved
PDF and upload ID. It checks for a completed upload before sending parts again.
A completed, unchanged item does not upload or prompt for printing twice. Editing
an uploaded item and finishing it creates a new PDF version in the archive;
it does not replace or delete the earlier version.

The retry record is `cloud-upload.json` in the session folder. Upload PDFs use
`upload-<id>.pdf` and are retained locally. If an upload start was not confirmed,
or the pages changed during a pending upload, the app stops. Check the archive
on the website and remove any incomplete entry before using the document menu's
**Clear upload record…** action. Clearing the record can cause another copy on
retry. It does not delete local scans or remote files.

Without automatic upload, **Finish item** saves locally and needs no connection.
PDF export remains available without signing in. Account and upload tests use a
mock server, with separate local SaaS integration tests. Production browser sign-in,
Keychain access, network uploads, and physical
label printing require an end-to-end check on the target Mac.

### Compact QR labels

Open **Create label…** from the document title menu or the Details view.

- **Item link:** paste an existing permanent HTTPS link from `foliobruma.com`.
  **Save item link** stores it in the current record. After upload, the app uses
  the private PDF endpoint returned by the upload API. Manually entered links
  are not checked for access or availability.
- **Custom link:** enter any HTTPS destination independently of the current
  record. Custom label text and links are not saved with the record.

Edit the label title and optional second line. The default uses the item title
(or batch name) and its reference. These edits change only the label. Custom links
are limited to 100 UTF-8 bytes to keep the QR compact; long printed text is
shortened, while the QR contains the full link. A short permanent link is best.

The layout is **62 × 25 mm** for the **DK-22205** continuous roll, in black on
white. Use **Save label PDF…** or **Print…**. In the macOS print dialog, select
the Brother QL-600, the correct paper size, and 100% scale. Printing requires
a working macOS printer queue and driver. Exporting the label PDF does not.
The QR has a white border. Test a printed label with a phone before a batch;
physical print quality and QL-600 feed/cutter behaviour are not yet verified.
Label generation works offline. Opening the SaaS link requires a connection.
Private uploaded PDF links can use up to 180 bytes; these produce denser QR codes.
Sign in to Foliobruma on the reading device before opening a private PDF link.

### Review and correct pages

- **Merge with next page…** joins the selected page (left) and the next page (right) into one page. Use **Move earlier** or **Move later** to put the two pages in order first. The merge uses their current crops and rotations, matches their heights without changing their proportions, and replaces them with one page at the same position. Export again to include the merged page in the PDF. Source images and source page records are kept. **Crop from original…** on a merged page uses the full merged image. The merge does not align overlapping map details or remove a seam. **Undo removal** does not undo a merge.

- **Replace…** returns to Scan to capture one replacement page. A successful save keeps the page position and page identity. The old image and original remain on disk. Split capture is disabled for a replacement. A rejected or failed replacement leaves the existing page in the document.
- **Crop from original…** shows the full original image. Adjust the four edge sliders and save the selected rectangle. For a book spread, select only the required side. This manual crop does not apply perspective correction; the existing page rotation is kept. The original and earlier processed image are retained.
- **Rejected** opens photos that are excluded from the PDF. Inspect the image with zoom before using **Keep this scan anyway**. **Rescan** returns to the camera, but keeps the rejected photo in the review list until you keep or dismiss it. **Dismiss from review** keeps its image file and removes the review entry.
- The footer distinguishes the saved session from the exported PDF. After an edit, **PDF needs export** means that the earlier PDF has not changed. Export again to include the edit. PDF export status applies to the current app session.

Keyboard controls: **⌘O** opens Documents, **⌘N** opens New item, **⌘E** opens the export summary, **← / →** changes the selected review page, **⌘⇧← / ⌘⇧→** moves that page earlier or later, **⌘R** rotates it, and **⌘Z** undoes the last removal. **Space** captures a page in Scan mode. Use Tab to move between controls.

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

### Physical USB button

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
└── session.json  Document name, optional metadata, page order, rotations, and rejected-photo review records
```

Metadata is stored in `session.json`; older sessions remain readable. The local
reference counter and lock file are in `~/Library/Application Support/Sovenelia Scanner/`.
Back up this folder with Sessions to retain the counter. If the counter is
missing, the app checks saved records before assigning another reference.

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
