import Foundation

// Reserve under a cross-process lock. Failed writes can leave gaps, never reused numbers.
public enum ItemReference {
  public static func reserve(in root: URL, letter: Bool, locking: any LibraryLocking) throws -> String {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return try locking.withLock(at: root.appendingPathComponent("item-reference.lock")) {
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
      let number = String(next)
      return (letter ? "LET-" : "DOC-") + String(repeating: "0", count: max(0, 4 - number.count)) + number
    }
  }
}
