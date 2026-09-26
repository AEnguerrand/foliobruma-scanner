# Account connection and uploads

[Documentation](README.md) · [Project overview](../README.md)

## Connect your account

The **Foliobruma** button at the top right shows whether you are signed in.
Click it to connect, select an archive, or change upload and label options.
The same controls are in **Settings → Account**. Camera controls
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
and stops uploads until you reconnect. Session options stay saved. Website logout
does not disconnect the scanner.
Older password-based scanner sessions require a new website sign-in.

This flow requires the matching SaaS pairing endpoints and database migration
to be deployed. Until then, connection attempts fail without changing local scans.

## Automatic upload

Enable **Upload automatically** to send scans to the selected archive.
In the Foliobruma menu, enable **Upload automatically** and **Print a label
when finished** for the current session. Select **Brother QL-600 · USB**.
A finished sheet or book uploads one PDF and prints one label automatically.
The options are saved with this session, not as account-wide settings. They
are off for new sessions. A manual upload has a separate print choice.

1. Scan and review all pages of the letter or book. Rejected photos stay excluded
   unless you choose to keep them.
2. Click **Finish item**. The app saves the session, creates one PDF with the saved
   page order and rotations, and uploads it. A page turn does not finish an item.
3. In a letter batch, **Next letter** finishes and uploads the current letter before
   it starts the next one. The USB **Next document** action also finishes first.
   An upload failure keeps the current document open. **New item…** is a local
   creation action; use **Finish item** before it when you want to upload.
4. The label uses its permanent SaaS URL and full 16-character ID. Sign in on the device that reads the QR
   first. A label does not make the document public. Use **Create label…** to
   print again after checking the result of a failed print.

Upload progress appears in the footer. Uploads accept PDFs up to 500 MiB and use
8 MiB parts. Server storage and membership limits still apply. Metadata stays in
the local session; this API stores the PDF and its filename. No originals or
rejected photos are uploaded. The app must remain open to finish an upload.

## Retry an upload

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

## Manual upload and print options

The Foliobruma account panel groups sign-in and **After scanning** settings.
Enable **Upload automatically** to make **Print a label when finished** available.
The label option runs only after a successful upload and uses this session’s
selected printer. The QL-600 USB option does not open a print dialog.

To upload an item manually, select **Document actions → Upload to Foliobruma**.
Sign in if needed, select the destination archive, and select **Upload now**.
All saved pages are sent as one PDF. This does not enable automatic upload or
start another item. The sheet also lets you choose whether to print a label.

See [QR labels and printing](labels.md) for permanent label IDs and printer checks.
For a test server, see [Developer server](development.md#developer-server).
