import Foundation

struct SavedSession: Identifiable {
  var referenceLabel: String { reference ?? "" }
  var reviewOrder: Int { needsReview ? 1 : 0 }
  var id: URL { folder }
  var folder: URL
  var title: String
  var pageCount: Int
  var modified: Date
  var reference: String?
  var batchName: String?
  var batchID: String?
  var needsReview: Bool = false
}
