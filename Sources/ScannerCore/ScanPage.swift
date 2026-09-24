import Foundation

public struct ScanPage: Codable, Identifiable {
  public var id: String = UUID().uuidString
  public var file: String
  public var original: String
  public var rotation: Int = 0
  // Keep the source records when two pages become one. Older sessions omit this field.
  public var mergedSources: [ScanPage]?
  public init(id: String = UUID().uuidString, file: String, original: String,
              rotation: Int = 0, mergedSources: [ScanPage]? = nil) {
    self.id = id
    self.file = file
    self.original = original
    self.rotation = rotation
    self.mergedSources = mergedSources
  }
}
