import Foundation
import ScannerCore

// Display text is supplied by the Mac app, not the shared data model.
extension ScanDocument {
  init(pages: [ScanPage] = []) {
    self.init(title: L10n.text("Untitled document"), pages: pages)
  }

  var displayTitle: String {
    let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !name.isEmpty { return name }
    return metadata?.reference ?? L10n.text("Untitled document")
  }
}
