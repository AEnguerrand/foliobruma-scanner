# QR labels and printing

[Documentation](README.md) · [Project overview](../README.md)

Open **Document actions → Label…** or **Create label…** in Details.

- **Item link:** paste an existing permanent HTTPS link from `foliobruma.com`.
  **Save item link** stores it in the current record. After upload, the app uses
  the permanent SaaS URL returned by the label API. Manually entered links
  are not checked for access or availability.
- **Custom link:** enter any HTTPS destination independently of the current
  record. Custom label text is not saved with the item metadata. Printed links are kept in the local print history.

Edit the label title and optional second line. The default uses the item title
(or batch name) and its reference. These edits change only the label. Custom links
are limited to 100 UTF-8 bytes to keep the QR compact; long printed text is
shortened, while the QR contains the full link. A short permanent link is best.

The label is **62 × 25 mm** for the **DK-22205** continuous roll, in black on
white. Select **Print with QL-600** for direct USB printing. It needs no Brother
driver or macOS print queue. Connect one QL-600, turn it on, and close its cover.
The app checks the roll before sending data and waits for completion. If the
result is unknown, check the physical label before printing again. It does not
automatically retry a job that might have printed.

The QR is the main element. Its white border includes the physical paper margins,
so the code can fill the printable height without changing the label size. The full SaaS label ID
is beside it, with the title below. The preview and PDF use the same layout.
**Print…** requires a working system queue.
The printed QR must be tested with a phone before a large batch.
Label generation works offline. Opening the SaaS link requires a connection.
Legacy PDF links can use up to 180 bytes; new uploads use short permanent links.
Sign in to Foliobruma on the reading device before opening a private PDF link.

## Prevent repeat labels

Manual printing and printing on finish use the same saved record, for both
USB and system printers. The app records the attempt before it sends a job.
After a label is sent, finishing the item does not send it again. The label
window shows **Reprint…** and asks before it sends another copy of the same QR.
This check uses the label link within the current session. It does not detect
copies printed in another session, another app, or from an exported PDF.

If the result is unknown, check the printer and the sheet. Use **Confirm label
handled** if the correct label is present, or **Reprint…** if it is missing.
A system queue confirms submission, not physical output. A direct USB failure
before any bytes are sent permits a retry. A failure after data may have been
sent stays unresolved until checked.

Print history is stored in `label-prints.json` inside the session folder.
Keep it in backups. Custom links are recorded there for duplicate checks, but
their text is not saved as item metadata. Older automatic print records are
also checked. Older manual jobs have no saved history and cannot be detected.

## QL-600 integration checks

Direct USB printing was checked on macOS 26 with a connected QL-600 and a 62 mm
continuous roll. The printer produced and cut a test label without a driver;
the completion and ready responses were received. Physical QR readability still
needs a check with the reading device. Automated tests decode the packed printer
raster, including the physical paper margins, and cover uncertain print results.

The scanner saves the SaaS reservation request ID before the request. It reuses
that ID on retry, attaches the completed PDF with a revision check, and prints
the permanent `/d/` URL with the full SaaS label code. A lost response is checked
before retrying. A conflicting website edit stops the operation. If an already
labelled item's content changes, replace the PDF on the website to keep its ID;
the scanner does not silently create a second permanent identity.

See [Account connection and uploads](foliobruma.md) for automatic printing
and [Records and batches](batches.md) for sheet workflows.
