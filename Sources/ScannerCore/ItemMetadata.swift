import Foundation

public struct ItemMetadata: Codable, Equatable {
  public var sheetBatch: Bool?
  public var reference: String
  public var batchID: String?
  public var batchName: String
  public var kind: String
  public var author: String
  public var period: String
  public var location: String
  public var tags: String
  public var notes: String
  public var webLink: String

  public init(reference: String = "", batchID: String? = nil, batchName: String = "",
       kind: String = "Document", author: String = "", period: String = "",
       location: String = "", tags: String = "", notes: String = "", webLink: String = "", sheetBatch: Bool? = nil) {
    self.sheetBatch = sheetBatch
    self.reference = reference
    self.batchID = batchID
    self.batchName = batchName
    self.kind = kind
    self.author = author
    self.period = period
    self.location = location
    self.tags = tags
    self.notes = notes
    self.webLink = webLink
  }

  public var nextLetter: ItemMetadata {
    ItemMetadata(batchID: batchID, batchName: batchName, kind: sheetBatch == true ? "Sheet" : "Letter",
                 location: location, tags: tags, sheetBatch: sheetBatch)
  }
}
