import AppKit
import PDFKit
import UniformTypeIdentifiers

extension Scanner {
  func exportPDF() {
    guard !document.pages.isEmpty, !busy else { return }
    autoCapture = false
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.pdf]
    panel.nameFieldStringValue = document.title + ".pdf"
    panel.canCreateDirectories = true
    guard panel.runModal() == .OK, let destination = panel.url else { return }
    busy = true
    status = "Creating PDF…"
    let snapshot = document.pages
    let base = folder
    DispatchQueue.global(qos: .userInitiated).async {
      let pdf = PDFDocument()
      for p in snapshot {
        guard let image = NSImage(contentsOf: base.appendingPathComponent(p.file)),
          let page = PDFPage(image: image)
        else {
          DispatchQueue.main.async {
            self.busy = false
            self.error = "A page image is missing. PDF export stopped."
          }
          return
        }
        page.rotation = p.rotation
        pdf.insert(page, at: pdf.pageCount)
      }
      do {
        guard let data = pdf.dataRepresentation() else { throw NSError(domain: "Scanner", code: 4) }
        try data.write(to: destination, options: .atomic)
        DispatchQueue.main.async {
          self.busy = false
          self.lastPDF = destination
          self.status = "PDF saved · \(snapshot.count) pages"
        }
      } catch {
        DispatchQueue.main.async {
          self.busy = false
          self.error = error.localizedDescription
        }
      }
    }
  }
}
