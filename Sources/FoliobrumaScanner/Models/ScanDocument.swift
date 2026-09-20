import Foundation

struct ScanDocument: Codable {
  var title = L10n.text("Untitled document")
  var metadata: ItemMetadata?
  var pages: [ScanPage] = []
  var rejected: [RejectedScan]? = []
  var resolvedRejections: [String]? = []

  var displayTitle: String {
    let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !name.isEmpty { return name }
    return metadata?.reference ?? L10n.text("Untitled document")
  }
}
