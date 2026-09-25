import Foundation
import ScannerCore

// Display text is supplied by the Mac app, not the shared data model.
extension ScanDocument {
  init(pages: [ScanPage] = []) {
    self.init(title: L10n.text("Untitled document"), pages: pages)
  }

  var displayTitle: String {
    let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let base = name.isEmpty ? (metadata?.reference ?? L10n.text("Untitled document")) : name
    let prefix = metadata?.namePrefix?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return prefix.isEmpty ? base : prefix + " " + base
  }
}
