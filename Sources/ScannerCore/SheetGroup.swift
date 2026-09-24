import Foundation

public struct SheetGroup: Codable, Identifiable, Equatable {
  public var id = UUID().uuidString
  public var title: String
  // Stable session folder IDs, in reading order. Images and labels stay in place.
  public var sheets: [String]
  public init(id: String = UUID().uuidString, title: String, sheets: [String]) {
    self.id = id
    self.title = title
    self.sheets = sheets
  }
}
