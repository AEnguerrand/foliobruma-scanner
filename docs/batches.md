# Records and batches

[Documentation](README.md) · [Project overview](../README.md)

## Metadata records and letter batches

Click **New item…** (+ or ⌘N). Choose **One document** to scan, or **Details
only** to record a physical item without a camera. The title is optional. An empty title uses the automatic
reference. Type, author or sender, date or period, physical location, tags, and
notes are optional details. Use **Details → Edit details** to change them later.
Use **Add scans** to add pages to the same record.

For a batch of letters, choose **Batch of letters**. Enter the batch name,
location, and tags once. Each letter gets a reference such as `LET-0001`.
**Next letter** saves a new, empty record and copies those three batch fields.
It clears the title, author, date, notes, and web link. It pauses automatic
capture and selects single-page scanning. Start capture again when ready.
All pages of a letter stay in the same record until you select **Next letter**.
A page turn does not create another letter. Editing batch fields affects the
current letter and later letters created from it, not earlier records.

For letter and sheet batches, set **Name prefix (optional)** to put text before
all new document names. For example, `Family` gives `Family LET-0001` when the
title is empty, or `Family Letter from June` when a title is set. The app adds a
space between the prefix and the name. **Name preview** shows an example; a new
item uses the next available reference when saved. The prefix is used in the
library, PDF export name, upload name, and default label title. Change or clear
it in **Details → Edit details**. The change applies to the current item and
later items made from it. Earlier items and their references do not change.

References are unique within this Mac's library, not across devices. Other
items use `DOC-` references and share the same counter. Gaps are possible after
a failed write. References do not change when you rename an item. Documents
can be searched by title, reference, or batch name.

## Mixed papers: one label per physical sheet

For an unsorted box of letters and papers, open **New item…** and choose
**Batch of sheets**. Enter a batch name and physical location, such as a
folio number. Each physical sheet gets its own reference, session, PDF upload,
and label. Capture each side or folded panel in reading order. A folded sheet
can contain more than two captures, with one PDF and one label for the sheet.
Related sheets do not need to be together during scanning.

1. In **Foliobruma**, select an archive and enable **Upload automatically** and
   **Print a label when finished**. With upload off, sheets are saved locally and
   no label prints automatically.
2. In **Settings → USB button**, select **Finish sheet** and enable the learned
   button. The existing **Next document** and **Next letter** button actions also
   finish the sheet when a sheet batch is open.
3. Connect the camera and start automatic capture. Place the front under the
   camera. Wait for the saved signal. Turn or unfold the sheet to show the next
   side or panel. Repeat until all required content is saved.
4. After the last saved side, press the USB button or click **Finish sheet**.
   A single-sided sheet needs only one capture. Capture continues after two
   sides, so folded sheets can have three, four, or more captures. Finish the
   current sheet before you place a different sheet under the camera. Replacement
   remains available in Review. Resolve rejected photos before finishing.
5. The app saves the sheet, uploads its PDF when enabled, and submits its label
   when enabled. In the Foliobruma menu, select **Brother QL-600 · USB** as the
   label printer. No driver, print queue, or print dialog is needed. The printer
   must have a 62 mm continuous DK-22205 roll.
6. Attach the correct label to the sheet sleeve and put it in the folio. The app
   prepares the next sheet and resumes automatic capture when you finish from
   Scan with a connected camera. Recent duplicate checks stay active across the
   sheet boundary. They remain approximate; check the saved reference and image.

An upload error or a cancelled or failed print keeps the current sheet open
and pauses capture. Check the problem and press **Finish sheet** again. A
completed upload is reused. A submitted label does not print again on retry.
Direct USB printing waits for the QL-600 to report completion and return to its
ready state. For a macOS queue, success means that macOS accepted the job.
Check the physical label before filing.
If the app stops with an unknown print result, check the printer and use
**Document actions → Label… → Reprint…** if a label is missing. If the correct
label is already on the sheet, use **Confirm label handled** in the label window
and finish the sheet. This confirmation sends no print job.
Session options are saved and copied to the next sheet or letter in the batch.
A new, unrelated session starts with automatic upload and printing off.

In **Review → Group sheets…**, select sheets from any batch and give the group
a letter or document name. Select a sheet to inspect its saved sides and panels. Use
**Reading order** to move or unlink sheets, then select **Save group**. A sheet
can belong to one group. To move it to another group, unlink it and save first.
An empty group is removed on save. Sheet references, individual PDF links,
images, and session folders do not change. To change the reading order, use the
normal page order controls in Review. Image merging is disabled for sheet
batches so the saved sides and panels remain separate pages.

Groups are saved only on this Mac in `sheet-groups.json`, beside the `Sessions`
folder. Include this file in backups. Group changes do not create a combined
PDF or sync to the website. Website grouping needs a separate API and interface
change; this scanner version uploads each sheet as an independent PDF.
Automated tests cover 2,000 ordered sheet links, save conflicts, capture state,
and print retry records. They do not verify a 2,000-sheet camera run or physical
printer output.

## Find a sheet in a large batch

**Documents** opens a table with references, page counts, and review status.
The current batch filter is on when a batch is open. Clear it to see all
sessions. Use **Needs review** to find rejected photos or unknown print results for the
saved item link.
Search by title, reference, or batch name. Click a column heading to sort. Select a row and press Return, click
**Open**, or double-click the row. The library loads in the background.

Automated checks load and reopen a synthetic 1,000-sheet library. They do not
measure a continuous 1,000-sheet camera or printer run.

## Related guides

- [Account connection and uploads](foliobruma.md)
- [QR labels and printing](labels.md)
- [USB button setup](usb-button.md)
- [Saved files and backups](storage.md)
