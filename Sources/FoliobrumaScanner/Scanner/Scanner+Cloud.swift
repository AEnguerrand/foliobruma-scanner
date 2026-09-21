import AppKit

extension Scanner {
  func finishItem(nextLetter: Bool = false, nextDocument: Bool = false, uploadRequested: Bool = false, printRequested: Bool? = nil, nextSheet: Bool = false) {
    guard !busy, !document.pages.isEmpty else { return }
    let resumeSheetCapture = nextSheet && connected && !reviewing && !metadataWorkspace
    autoCapture = false
    busy = true
    Task { @MainActor in
      let account = CloudAccount.shared
      defer { busy = false; exportProgress = nil; finishPendingReview() }
      do {
        try persist()
        if uploadRequested || (tracksActiveSession && uploadOnFinish) {
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
          let previous = try CloudUpload.load(in: base)
          try previous?.requireServer(account.api)
          if let saved = previous, !saved.complete || saved.fingerprint == fingerprint {
            guard saved.userID == user.id, saved.organisationID == account.organisationID else {
              throw CloudFailure(message: "This item has an upload in another account or archive. Select its original destination to continue.")
            }
            guard saved.fingerprint == fingerprint else {
              throw CloudFailure(message: "The pages changed during an incomplete upload. Clear its upload record before uploading the changed item.")
            }
            upload = saved
          } else {
            if previous?.permanentLabel != nil {
              throw CloudFailure(message: "This item already has a permanent label. Replace its PDF on the website to keep the same label.")
            }
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
            upload.serverOrigin = account.api.baseURL.absoluteString
            try upload.save(in: base)
          }
          status = L10n.text("Reserving permanent label…")
          try await upload.reserveLabel(api: account.api, folder: base, title: document.displayTitle)
          status = L10n.text("Uploading PDF…")
          exportProgress = 0
          try await upload.send(api: account.api, folder: base) { value in
            await MainActor.run { self.exportProgress = value }
          }
          try await upload.attachLabel(api: account.api, folder: base)
          try CloudKeychain.save(account.api.credentials(), origin: account.api.baseURL)
          var saved = document
          var details = saved.metadata ?? ItemMetadata()
          details.webLink = upload.link!
          saved.metadata = details
          try commit(saved)
          status = L10n.text("Uploaded to Foliobruma")
          if (printRequested ?? printOnFinish) && upload.sheetLabelSubmitted != true {
            let label = DocumentLabel(title: document.displayTitle, subtitle: details.reference, link: upload.link!)
            let qr = await Task.detached { label.qrImage() }.value
            guard let qr else { throw CloudFailure(message: "Could not create the QR code.") }
            try await printSessionLabel(label, qr: qr, upload: &upload)
            status = L10n.text(document.automation?.printerName == QL600Printer.destination ? "QL-600 confirmed label printed" : "Label sent to printer")
          }
        } else {
          status = L10n.text("Item saved on this Mac")
        }
        busy = false
        if nextSheet { try createNextSheet(resumeCapture: resumeSheetCapture && !pendingReview) }
        else if nextLetter { createNextLetter() }
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
