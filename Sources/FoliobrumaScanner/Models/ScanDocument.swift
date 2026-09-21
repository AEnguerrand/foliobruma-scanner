import Foundation

struct ScanDocument: Codable {
  var title = L10n.text("Untitled document")
  var metadata: ItemMetadata?
  var automation: SessionAutomation?
  var pages: [ScanPage] = []
  var rejected: [RejectedScan]? = []
  var resolvedRejections: [String]? = []

  var displayTitle: String {
    let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !name.isEmpty { return name }
    return metadata?.reference ?? L10n.text("Untitled document")
  }
}

// Optional on old sessions. New sessions keep automation off until configured.
struct SessionAutomation: Codable, Equatable {
  var upload = false
  var printLabel = false
  var printerName = ""
}
