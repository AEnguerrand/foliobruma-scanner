import ScannerCore
import AppKit

extension Scanner {
  var isSheetBatch: Bool { document.isSheetBatch }
  var sheetCapturePrompt: String {
    switch document.pages.count {
    case 0: return L10n.text("Place the front of the next sheet under the camera.")
    default: return L10n.format("Captures saved: %ld · Scan another side or finish this sheet.", document.pages.count)
    }
  }

  func finishSheet() {
    guard isSheetBatch, !busy, !document.pages.isEmpty else { return }
    guard !document.sheetNeedsReview else {
      beginReview()
      showRejected = true
      return
    }
    finishItem(nextSheet: true)
  }

  func createNextSheet(resumeCapture: Bool) throws {
    guard let details = document.metadata, isSheetBatch else { return }
    let automation = document.automation
    try createItem(title: "", metadata: details.nextLetter, scanPages: true,
                   preserveCaptureHistory: true, automation: automation)
    // Keep the recent fingerprints across the boundary. The finished sheet may
    // still be under the camera while its label is attached.
    autoCapture = resumeCapture && connected
    status = sheetCapturePrompt
  }

  func prepareSheetGroups() {
    guard !busy else { return }
    beginReview()
    showSheetGroups = true
  }

  var uploadOnFinish: Bool { document.uploadOnFinish }
  var printOnFinish: Bool { document.printOnFinish }

  func setSessionAutomation(_ value: SessionAutomation) {
    guard !busy else { return }
    do {
      var next = document
      next.automation = value
      let wasCurrent = pdfIsCurrent
      try commit(next)
      pdfIsCurrent = wasCurrent
    } catch { self.error = L10n.text(error.localizedDescription) }
  }

  @MainActor func printSessionLabel(_ label: DocumentLabel, qr: NSImage, upload: inout CloudUpload) async throws -> Bool {
    let name = document.automation?.printerName ?? ""
    let alreadySent = try LabelPrintStore.state(in: folder, link: label.link) == .submitted
    if !alreadySent {
      try await printTrackedLabel(label, qr: qr, printerName: name, showPanel: false)
    }
    // Keep the legacy record readable by previous app versions.
    upload.sheetLabelStarted = false
    upload.sheetLabelSubmitted = true
    try upload.save(in: folder)
    return !alreadySent
  }

  @MainActor func printTrackedLabel(_ label: DocumentLabel, qr: NSImage,
                                    printerName: String, showPanel: Bool,
                                    reprint: Bool = false) async throws {
    let base = folder
    let direct = printerName == QL600Printer.destination
    let info = DocumentLabelView.labelPrintInfo()
    if !direct && !showPanel {
      guard !printerName.isEmpty, NSPrinter.printerNames.contains(printerName),
            let printer = NSPrinter(name: printerName) else {
        throw CloudFailure(message: "Select an available label printer in the Foliobruma session settings. The item is still open.")
      }
      info.printer = printer
    }
    // Prepare the image before recording intent; raster errors send no data.
    let job = direct ? try QL600Printer.raster(QL600Printer.bitmap(label)) : nil
    let ticket = try LabelPrintStore.begin(in: base, link: label.link, reprint: reprint, lock: MacLibraryLock())
    if let job {
      do {
        try await Task.detached(priority: .userInitiated) { try QL600Printer.send(job) }.value
      } catch {
        try LabelPrintStore.finish(ticket, in: base, submitted: false,
          mayHavePrinted: (error as? QL600Failure)?.sent ?? true, lock: MacLibraryLock())
        throw error
      }
      try LabelPrintStore.finish(ticket, in: base, submitted: true, mayHavePrinted: true, lock: MacLibraryLock())
    } else {
      let submitted = DocumentLabelView(label: label, qr: qr).printLabel(info: info, showPanel: showPanel)
      try LabelPrintStore.finish(ticket, in: base, submitted: submitted,
        mayHavePrinted: false, lock: MacLibraryLock())
      guard submitted else {
        throw CloudFailure(message: "Label printing stopped. Check the printer before trying again.")
      }
    }
    if var upload = try CloudUpload.load(in: base), upload.link == label.link {
      upload.sheetLabelStarted = false
      upload.sheetLabelSubmitted = true
      try upload.save(in: base)
    }
  }

  func confirmSheetLabelHandled() {
    guard !busy else { return }
    autoCapture = false
    let panel = NSAlert()
    panel.messageText = L10n.text("Confirm label handled?")
    panel.informativeText = L10n.text("Check that this sheet has its correct label. This clears an unknown print result without sending another print job.")
    panel.addButton(withTitle: L10n.text("Confirm label handled"))
    panel.addButton(withTitle: L10n.text("Cancel"))
    guard panel.runModal() == .alertFirstButtonReturn else { return }
    do {
      guard let link = document.metadata?.webLink, !link.isEmpty else { return }
      try LabelPrintStore.confirmHandled(in: folder, link: link, lock: MacLibraryLock())
      if var upload = try CloudUpload.load(in: folder), upload.link == link {
        upload.sheetLabelStarted = false
        upload.sheetLabelSubmitted = true
        try upload.save(in: folder)
      }
    } catch { self.error = L10n.text(error.localizedDescription) }
  }
}
