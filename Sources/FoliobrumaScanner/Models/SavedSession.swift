import Foundation

struct SavedSession: Identifiable {
  var id: URL { folder }
  var folder: URL
  var title: String
  var pageCount: Int
  var modified: Date
  var reference: String?
  var batchName: String?
}
