import Foundation

// The platform supplies the folder. This store never deletes image files.
public struct SessionStore {
  public let folder: URL
  public init(folder: URL) { self.folder = folder }
  public var manifest: URL { folder.appendingPathComponent("session.json") }

  public func prepare() throws {
    for name in ["Originals", "Pages"] {
      try FileManager.default.createDirectory(at: folder.appendingPathComponent(name),
                                            withIntermediateDirectories: true)
    }
  }

  public func load() throws -> ScanDocument {
    try JSONDecoder().decode(ScanDocument.self, from: Data(contentsOf: manifest))
  }

  public func loadIfPresent() throws -> ScanDocument? {
    guard FileManager.default.fileExists(atPath: manifest.path) else { return nil }
    return try load()
  }

  public func save(_ document: ScanDocument) throws {
    try JSONEncoder().encode(document).write(to: manifest, options: .atomic)
  }

  public static func create(_ document: ScanDocument, in root: URL) throws -> Self {
    let store = Self(folder: root.appendingPathComponent("Sessions/" + UUID().uuidString))
    try store.prepare()
    try store.save(document)
    return store
  }

  public func recoveringRejections(in document: ScanDocument) -> ScanDocument {
    let urls = (try? FileManager.default.contentsOfDirectory(
      at: folder.appendingPathComponent("Rejected"), includingPropertiesForKeys: nil)) ?? []
    let rejected = document.rejected ?? []
    let known = Set(rejected.map(\.file) + (document.resolvedRejections ?? []))
    let recovered = urls.filter {
      $0.pathExtension.lowercased() == "jpg" && !known.contains("Rejected/" + $0.lastPathComponent)
    }.map {
      RejectedScan(file: "Rejected/" + $0.lastPathComponent,
        reason: "Recovered photo. Check it before keeping it. Earlier crop settings may be unavailable.",
        split: false, divider: 0.5)
    }
    var next = document
    next.rejected = rejected + recovered
    return next
  }

  public static func list(in root: URL) -> [SessionRecord] {
    let folders = (try? FileManager.default.contentsOfDirectory(
      at: root.appendingPathComponent("Sessions"), includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    return folders.compactMap { folder in
      let store = Self(folder: folder)
      guard let document = try? store.load() else { return nil }
      let modified = (try? store.manifest.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate ?? .distantPast
      return SessionRecord(folder: folder, document: document, modified: modified)
    }.sorted { $0.modified > $1.modified }
  }
}

public struct SessionRecord {
  public let folder: URL
  public let document: ScanDocument
  public let modified: Date
}
