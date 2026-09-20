import Foundation

struct ScanDocument: Codable {
  var title = L10n.text("Untitled document")
  var pages: [ScanPage] = []
  var rejected: [RejectedScan]? = []
  var resolvedRejections: [String]? = []
}
