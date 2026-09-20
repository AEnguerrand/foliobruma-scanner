import Foundation

struct ScanPage: Codable, Identifiable {
  var id: String = UUID().uuidString
  var file: String
  var original: String
  var rotation: Int = 0
}
