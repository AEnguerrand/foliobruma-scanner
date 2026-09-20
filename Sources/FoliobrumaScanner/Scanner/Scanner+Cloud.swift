import AppKit

extension Scanner {
  func finishItem(nextLetter: Bool = false, nextDocument: Bool = false, uploadRequested: Bool = false) {
    guard !busy, !document.pages.isEmpty else { return }
    autoCapture = false
    busy = true
    Task { @MainActor in
      let account = CloudAccount.shared
      defer { busy = false; exportProgress = nil; finishPendingReview() }
      do {
        try persist()
        if uploadRequested || account.automatic {
          await account.restore()
          guard account.ready, let user = account.user else {
            throw CloudFailure(message: "Sign in and select an upload archive in Settings. Your scan is saved on this Mac.")
          }
          guard !account.working else { throw CloudFailure(message: "An account operation is in progress. Try again when it finishes.") }
          account.working = true
          defer { account.working = false }
          let base = folder
          let snapshot = document
          let fingerprint = try CloudUpload.fingerprint(snapshot)
          var upload: CloudUpload
          if let saved = try CloudUpload.load(in: base), !saved.complete || saved.fingerprint == fingerprint {
            guard saved.userID == user.id, saved.organisationID == account.organisationID else {
              throw CloudFailure(message: "This item has an upload in another account or archive. Select its original destination to continue.")
            }
            guard saved.fingerprint == fingerprint else {
              throw CloudFailure(message: "The pages changed during an incomplete upload. Clear its upload record before uploading the changed item.")
            }
            upload = saved
          } else {
            status = L10n.text("Creating PDF…")
            let file = "upload-" + UUID().uuidString + ".pdf"
            try await Task.detached(priority: .userInitiated) {
              try CloudUpload.makePDF(snapshot, in: base, file: file)
            }.value
            let safeTitle = String(snapshot.displayTitle.unicodeScalars.filter {
              !CharacterSet.controlCharacters.contains($0) && $0 != "/" && $0 != "\\"
            }.map(String.init).joined().prefix(110))
            upload = CloudUpload(fingerprint: fingerprint, userID: user.id,
                                 organisationID: account.organisationID, file: file, name: safeTitle + ".pdf")
            try upload.save(in: base)
          }
          status = L10n.text("Uploading PDF…")
          exportProgress = 0
          try await upload.send(api: account.api, folder: base) { value in
            await MainActor.run { self.exportProgress = value }
          }
          try CloudKeychain.save(account.api.credentials())
          var saved = document
          var details = saved.metadata ?? ItemMetadata()
          details.webLink = upload.link!
          saved.metadata = details
          try commit(saved)
          status = L10n.text("Uploaded to Foliobruma")
          if account.printLabel && !upload.labelOffered {
            let label = DocumentLabel(title: document.displayTitle, subtitle: details.reference, link: upload.link!)
            let qr = await Task.detached { label.qrImage() }.value
            guard let qr else { throw CloudFailure(message: "Could not create the QR code.") }
            // Record before opening the print panel. Retry must not print another label.
            upload.labelOffered = true
            try upload.save(in: base)
            DocumentLabelView(label: label, qr: qr).printLabel()
          }
        } else {
          status = L10n.text("Item saved on this Mac")
        }
        busy = false
        if nextLetter { createNextLetter() }
        else if nextDocument { newDocumentLocally() }
      } catch { self.error = error.localizedDescription }
    }
  }

  func clearCloudUpload() {
    guard !busy else { return }
    let panel = NSAlert()
    panel.messageText = L10n.text("Clear upload record?")
    panel.informativeText = L10n.text("First check the archive on the website. Remove any incomplete upload there. This clears only the local retry record. The next upload can create another copy. Local scans and PDFs are kept.")
    panel.addButton(withTitle: L10n.text("Clear upload record"))
    panel.addButton(withTitle: L10n.text("Cancel"))
    guard panel.runModal() == .alertFirstButtonReturn else { return }
    do {
      let url = folder.appendingPathComponent("cloud-upload.json")
      if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    } catch { self.error = error.localizedDescription }
  }
}
