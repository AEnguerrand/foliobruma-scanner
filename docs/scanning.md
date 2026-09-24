# Scanning and review

[Documentation](README.md) · [Project overview](../README.md)

## Scan your first document

![Scan setup: a Mac connected to a document camera above paper on a dark surface, with an optional USB button and label printer](../Resources/Brand/scan-setup.png)

Use an Apple Silicon Mac with macOS 14 or later, a USB document camera, and a
contrasting surface with even light. The illustration shows the setup; it is
not an app screenshot. A USB button and label printer are optional. Local
scanning and PDF export need no account or internet connection.

1. Connect the scanner by USB. In **Scan setup**, select a **Camera** and click **Connect camera**. Use the refresh button if you connected the camera after opening the app.
2. Use the document menu to name your document. In Scan setup, choose **Book** or **Single page**.
3. Put the paper on a contrasting surface with even light. Check that all page edges are visible.
4. Check the gold crop outline. For a book, enable **Split into two pages** and adjust **Spine position** to the centre of the spread. You can also drag the gold handle or click **Centre spine**. Use **Preview crop and split** to inspect a camera frame without saving pages.
5. Click **Start auto capture**, then move your hands away. For manual capture, click **Capture page** or press **Space** in Scan mode.
6. Wait for the green **Saved — turn the page** signal and chime before turning the page. Repeat for each page or spread.
7. Choose **Review**. Capture pauses. Select a page in the sidebar, or enter a page number and click **Go**. Zoom and scroll to inspect the text. Use **Rotate**, **Move earlier**, **Move later**, **Remove**, or **Undo removal** as needed.
8. Click **Export PDF**, check the page count and rejected-photo notice, then choose where to save the file. Progress appears at the bottom of the window. Open the result from **Files → Open PDF** or **Show PDF in Finder**.

Use **Documents → New item…** for another book or group of pages. Select **Scan pages** to use the camera. The document title menu also contains **New item…** and **Rename document…**. Use **Documents** to search saved documents and open one by name. **Open session folder…** remains available for sessions stored elsewhere. Closing the app keeps the session. Returning to Scan does not restart automatic capture.

## Capture signals

| Signal | Meaning | What to do |
| --- | --- | --- |
| Green border and saved chime | Page files and the session are saved. | Turn the page. |
| Amber **Already scanned** message and short tone | A recent duplicate was detected. No extra copy was saved. | Turn the page, or use manual capture for an intentional repeat. |
| Small amber warning and soft tone | A hand or missing page edges are blocking automatic capture. | Clear the page and check its position. |
| Red **Rescan needed** message and low tone | The captured photo failed a quality check. It is not in the PDF. | Correct the issue and capture again. |

The speaker switch controls capture sounds. Visual signals remain active when sound is off. A quality rejection pauses automatic capture and opens the rejected-photo review. If a quality check is wrong, inspect the photo before using **Keep this scan anyway**.

Duplicate checks compare image detail with the last four saved captures. Different text pages can pass even when their layout is similar. The check runs again while the page is still; a duplicate warning does not require a page turn to clear. Small shifts or lighting changes can still let a repeat pass. Use manual capture if a different page is blocked.

Automatic capture requires at least 0.55 seconds of a clear, still page. Camera capture, checks, and saving add time. A sustained obstruction produces a warning after 1.5 seconds; brief page-turn movements should not produce a warning tone.

## Review and correct pages

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

## Interface

The app uses the Mac’s appearance and accent colour. The camera and page image
views use a dark background. Gold marks the detected page edges and book spine.
Open **Scanning tips**, **Supported buttons**, or **Print setup** for extra help.
The footer shows rejected scans when photos need review. The Review view has an
**Add scans** button when no page is selected. In Documents, an empty search
result gives a prompt to try another title, reference, or batch name.

Page-number input follows the selected page. An invalid number shows the valid
range. Removing the selected page selects the next page, or the preceding page
when the last page is removed. **Undo removal** restores and selects that page
in Review. Original image files stay on disk.

Document and export panels open the next dialog after the current panel closes.
Document search ignores spaces at the start and end; use **Clear search** to
show all results. Label fields keep their names visible after editing. An invalid
link shows the problem beside the fields. Image and label previews show a loading
state before they show an image or an error.

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

## Related guides

- [USB button setup](usb-button.md)
- [Capture limits and troubleshooting](troubleshooting.md)
- [Saved files and backups](storage.md)
