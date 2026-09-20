import Foundation

struct RejectedScan: Codable, Identifiable {
  var id: String { file }
  var file: String
  var reason: String
  var quad: Quad?
  var split: Bool
  var divider: Double
  var replacementID: String?
}

struct SavedSession: Identifiable {
  var id: URL { folder }
  var folder: URL
  var title: String
  var pageCount: Int
  var modified: Date
  var reference: String?
  var batchName: String?
}
