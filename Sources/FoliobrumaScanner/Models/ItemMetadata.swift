import Foundation
import Darwin

struct ItemMetadata: Codable, Equatable {
  var sheetBatch: Bool?
  var reference: String
  var batchID: String?
  var batchName: String
  var kind: String
  var author: String
  var period: String
  var location: String
  var tags: String
  var notes: String
  var webLink: String

  init(reference: String = "", batchID: String? = nil, batchName: String = "",
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

  var nextLetter: ItemMetadata {
    ItemMetadata(batchID: batchID, batchName: batchName, kind: sheetBatch == true ? "Sheet" : "Letter",
                 location: location, tags: tags, sheetBatch: sheetBatch)
  }
}

// The counter is local to this library, not a public URL or an access token.
// Reserve before creating a record. Failed writes can leave gaps, never reused numbers.
enum ItemReference {
  static func reserve(in root: URL, letter: Bool) throws -> String {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let lockURL = root.appendingPathComponent("item-reference.lock")
    let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else { throw POSIXError(.EIO) }
    defer { close(descriptor) }
    guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
    defer { flock(descriptor, LOCK_UN) }
    let counterURL = root.appendingPathComponent("item-reference.json")
    var last = 0
    if FileManager.default.fileExists(atPath: counterURL.path) {
      last = try JSONDecoder().decode(Int.self, from: Data(contentsOf: counterURL))
    }
    // Also recover the highest number from sessions restored from a backup.
    let sessions = root.appendingPathComponent("Sessions")
    if FileManager.default.fileExists(atPath: sessions.path) {
      for folder in try FileManager.default.contentsOfDirectory(at: sessions, includingPropertiesForKeys: nil) {
        let manifest = folder.appendingPathComponent("session.json")
        guard FileManager.default.fileExists(atPath: manifest.path) else { continue }
        let doc = try JSONDecoder().decode(ScanDocument.self, from: Data(contentsOf: manifest))
        if let reference = doc.metadata?.reference,
           reference.hasPrefix("LET-") || reference.hasPrefix("DOC-"),
           let number = Int(reference.dropFirst(4)) {
          last = max(last, number)
        }
      }
    }
    guard last >= 0, last < Int.max else { throw POSIXError(.EOVERFLOW) }
    let next = last + 1
    try JSONEncoder().encode(next).write(to: counterURL, options: .atomic)
    return String(format: letter ? "LET-%04ld" : "DOC-%04ld", next)
  }
}
