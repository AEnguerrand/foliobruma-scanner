# Foliobruma Scanner for macOS

A local-only Mac app for scanning family books, letters, and documents. The dark-and-gold interface uses SwiftUI. Camera capture uses AVFoundation; cropping uses Vision and local paper segmentation; PDF export uses PDFKit. No accounts, uploads, QR codes, OCR services, telemetry, or external runtime dependencies.

## Build and run

Apple Silicon, macOS 14 or later. Install Apple's Command Line Tools, then run `./build.sh`. Open `build/Foliobruma Scanner.app` and allow camera access. The script uses the installed Command Line Tools SDK; no Xcode project is required.

This development build is ad-hoc signed, not notarized. A rebuilt binary can require camera permission again. Public distribution requires proper signing and notarization.

## Use

1. Connect the IRIScan by USB. The app selects it when present.
2. Choose Book or Letters. Enable Split pages for a book spread.
3. Check the gold crop outline. The Spine slider adjusts the split position.
4. Press Capture or Space. Auto capture waits for a stable changed page. Automatic capture requires at least 0.55 seconds of a clear, still page. It checks for hands, movement in small image regions, and similarity to the four most recent saved spreads. Capture and saving add time. Manual Capture can save an intentional repeat.
5. Wait for the chime and green “Saved — turn the page” signal before turning the page. They confirm that page files and the session are saved. A low tone indicates an error: check the screen. Use Capture sounds to mute the sounds; visual feedback stays on.
   After capture, the app checks for hands, heavy blur, a very dark image, and detected page edges at the camera boundary. A red rescan message and a low tone indicate a rejected photo. It stays in `Rejected/` and is excluded from the PDF. Use “Keep this scan anyway” if the check is wrong. An already scanned page shows an amber message and plays a distinct tone once. It does not add an extra copy. A new saved page or restarting auto capture enables the next duplicate tone.
   Before automatic capture, a hand that stays in view or missing page edges produces a small warning and a soft tone after 1.5 seconds. The tone sounds once until the obstruction clears.
6. Select a thumbnail to review, rotate, or remove a page. Removed image files are kept; Undo removal restores the most recently removed page.
7. Save PDF chooses a real local destination. Originals & session opens the source images and session folder.
8. The document menu creates a new document or opens an earlier session. Closing the app keeps the current session.

## Storage

Sessions are in `~/Library/Application Support/Sovenelia Scanner/Sessions/`. Each session has `Originals/`, `Pages/`, and `session.json`. Original JPEG capture data is saved before derived page images. New documents keep earlier sessions. Exported PDFs are separate from session files.

## Current limits

Automatic cropping depends on visible edges or bright paper against a darker surface. Always check the outline; switch Auto crop off when detection fails. Perspective correction is supported, but curved-book dewarping is not. The spine is a straight adjustable split. Hand detection and page similarity checks are approximate. Very similar pages or missed hand detections can need manual Capture; keep hands clear of the page. Quality checks cannot find every defect. Glare, shadows, missing text, and book curvature still need visual review. Blur checks use a reduced image and can miss fine-detail blur. Lighting changes can defeat duplicate detection. This is an early v1, not a bulk archive certification. Keep normal backups of your archive.

## Hardware test status

Verified with the connected IRIScan Desk 6 Pro and a handwritten ring-bound book: real 4160 × 3120 capture, corrected automatic crop, two-page split, native PDF export, page review, rotation, removal, Undo, new document, reopening saved sessions, and recovery after restart. Automatic capture saved one stable spread and did not repeat while it stayed unchanged. Exported PDF pages were rendered and visually checked. Test scans are private and are not included in this repository. Live warning timing and sound playback still need further hardware testing.

## Local regression tests

Run `./test.sh`. It compiles the real scanner model with a separate test entry point. Tests use a temporary session root and do not request camera access. They check page-order undo, rotation persistence, failed-write rollback, session isolation, failed new-document recovery, blank-image crop rejection, off-center crop coordinate conversion, capture and warning gates, and quality rejection with a manual override.

## Name compatibility

The app is now Foliobruma Scanner. This development build retains the existing bundle identifier and session directory so existing scans and preferences remain available. The source currently uses the MIT license.

## License

[MIT](LICENSE). Commercial use is permitted under the license terms.
