# Saved files and backups

[Documentation](README.md) · [Project overview](../README.md)

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

## Batch and upload files

Sheet groups are saved in `sheet-groups.json`, beside the `Sessions` folder.
Include this file in backups. See [Records and batches](batches.md) for group limits.

Optional uploads add `cloud-upload.json` and retained `upload-<id>.pdf` files
to the session folder. See [Retry an upload](foliobruma.md#retry-an-upload)
before clearing an upload record.
