# Interface review

This review covers the local document workflow. The app uses native Mac controls,
keeps original images, and separates rejected photos from PDF pages. The work
below improves text, layout, feedback, and movement between screens.

## Findings and changes

| Step | Screen or action | Finding | Change and status |
| --- | --- | --- | --- |
| 1 | Document and Details | Repeated headings, local-storage messages, and Next letter actions competed with the item content. | Keep one title, one storage status, and one Next letter action. Use the system appearance and accent colour. Add a tooltip for long document titles. Checked in English and French. |
| 2 | New item and Edit details | One long field group and two nested scroll areas made the form hard to scan. | Use one native form with Document, Description, and Filing sections. Keep the save and cancel actions visible. The French form and transition from Documents were checked. |
| 3 | Scan | The disconnected screen repeated the connection instruction and app branding. | Use one camera symbol and instruction. Put extra help under Scanning tips. Keep gold camera guides. The disconnected screen was checked in both languages; live capture was not tested. |
| 4 | Documents | Empty results moved the header. Search included accidental outer spaces. Opening another dialog used a fixed delay or left the current sheet open. | Keep a fixed content area, trim outer search spaces, add Clear search, and open the next dialog after dismissal. Search, clearing, New item, and the folder chooser were checked in French. |
| 5 | Review | Invalid page numbers had no feedback and could overflow during index calculation. The field did not follow selection. Removing a page cleared selection. | Validate before index calculation, show the valid range, keep the number in sync, select the adjacent page after removal, and select the restored page after undo. Regression tests cover boundaries, busy state, failed saves, removal, and undo. Manual checks use a synthetic three-page session. |
| 6 | Image and crop preview | A loading image could look unavailable, and a preceding rejected photo could remain visible while another loaded. | Show a loading state before an image or error. Give each reviewed page its own view identity. Keep text on the dark image canvas readable. The crop controls were checked in the first pass; live camera framing remains untested. |
| 7 | Export and rejected photos | Export described how to find rejected scans instead of providing an action. Dialog transitions used a fixed delay. | Add Review rejected scans and open it after export closes. Keep the excluded count and non-searchable-text notice. The transition and both French panels were checked with a synthetic document. |
| 8 | Labels | Filled fields lost their names. Invalid links disabled actions without specific feedback. The French PDF button was truncated. | Add permanent field names, explain invalid HTTPS and overlong links, show loading and failure states, and use Save PDF in this panel. Add an accessible text value for the label preview. Invalid-to-valid link recovery was checked in French without saving a link or printing. |
| 9 | Settings and help | Routine instructions made Settings dense. | Shorten the restart instruction and put USB compatibility details in expandable help. Language settings were used for the French checks and restored to System language. |

## Validation

The required checks passed on the final code state (nine test groups):

```sh
./test.sh
./build.sh
git diff --check
```

Tests use temporary sessions. They cover page input boundaries, selection after
removal and undo, failed-write recovery, URL validation messages, language
resources, session and page operations, PDF export, and capture guards. The
existing tests also check that original images are retained.

Manual checks use synthetic page images. No private scan, generated app bundle,
or test session belongs in the PR. The storage format, session directory, bundle
identifier, capture thresholds, and offline operation are unchanged.

## Limits

- Screenshots could be displayed during the review, but the screenshot tool
  could not save them in this session. This document is a review record, not the
  Product Design skill's complete saved screenshot report.
- Live camera capture, sound timing, physical printing, and image quality were
  not tested. No scanner was connected during the later interface checks.
- The visual checks cover the current dark appearance in English and French.
  A full light-appearance and window-size matrix was not completed.
- Control labels and accessibility-tree output were inspected. Full VoiceOver
  navigation, contrast compliance, and keyboard coverage were not established.
- The app is signed locally for development. It is not notarized.
