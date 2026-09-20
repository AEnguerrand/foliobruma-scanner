import AppKit
import PDFKit
import UniformTypeIdentifiers

extension Scanner {
  func exportPDF() {
    guard !document.pages.isEmpty, !busy else { return }
    autoCapture = false
    showExport = false
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.pdf]
    panel.nameFieldStringValue = document.title + ".pdf"
    panel.canCreateDirectories = true
    guard panel.runModal() == .OK, let destination = panel.url else { return }
    writePDF(to: destination)
  }
  func writePDF(to destination: URL) {
    guard !busy, !document.pages.isEmpty else { return }
    autoCapture = false
    busy = true
    exportProgress = 0
    status = L10n.text("Creating PDF…")
    let snapshot = document.pages
    let base = folder
    DispatchQueue.global(qos: .userInitiated).async {
      let pdf = PDFDocument()
      for (index, p) in snapshot.enumerated() {
        guard let image = NSImage(contentsOf: base.appendingPathComponent(p.file)),
          let page = PDFPage(image: image)
        else {
          DispatchQueue.main.async {
            self.busy = false
            self.exportProgress = nil
            self.finishPendingReview()
            self.error = L10n.text("A page image is missing. PDF export stopped.")
          }
          return
        }
        page.rotation = p.rotation
        pdf.insert(page, at: pdf.pageCount)
        DispatchQueue.main.async {
          self.exportProgress = Double(index + 1) / Double(snapshot.count)
          self.status = L10n.format("Creating PDF · Page %ld of %ld", index + 1, snapshot.count)
        }
      }
      do {
        guard let data = pdf.dataRepresentation() else { throw NSError(domain: "Scanner", code: 4) }
        try data.write(to: destination, options: .atomic)
        DispatchQueue.main.async {
          self.busy = false
          self.exportProgress = nil
          self.finishPendingReview()
          self.lastPDF = destination
          self.pdfIsCurrent = true
          self.status = L10n.format("PDF saved · Pages: %ld", snapshot.count)
        }
      } catch {
        DispatchQueue.main.async {
          self.busy = false
          self.exportProgress = nil
          self.finishPendingReview()
          self.error = error.localizedDescription
        }
      }
    }
  }
}
