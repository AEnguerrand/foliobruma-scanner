import Foundation
import Darwin
import ScannerCore

struct SheetGroupStore {
  var groups: [SheetGroup]
  var snapshot: Data?

  static func load(in root: URL) throws -> Self {
    let url = root.appendingPathComponent("sheet-groups.json")
    let data = FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
    return Self(groups: try data.map { try JSONDecoder().decode([SheetGroup].self, from: $0) } ?? [],
                snapshot: data)
  }

  mutating func save(_ group: SheetGroup, in root: URL) throws {
    guard UUID(uuidString: group.id) != nil,
      group.sheets.allSatisfy({ UUID(uuidString: $0) != nil }),
      Set(group.sheets).count == group.sheets.count,
      group.sheets.isEmpty || !group.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { throw CloudFailure(message: "Enter a group name and select each sheet only once.") }
    let descriptor = open(root.appendingPathComponent("sheet-groups.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else { throw POSIXError(.EIO) }
    defer { close(descriptor) }
    guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
    defer { flock(descriptor, LOCK_UN) }
    let current = try Self.load(in: root)
    guard current.snapshot == snapshot else {
      throw CloudFailure(message: "Groups changed in another window. Close and reopen Group sheets before saving.")
    }
    let selected = Set(group.sheets)
    guard !current.groups.contains(where: { $0.id != group.id && !selected.isDisjoint(with: $0.sheets) }) else {
      throw CloudFailure(message: "A selected sheet belongs to another group. Remove it from that group first.")
    }
    var next = current.groups.filter { $0.id != group.id }
    if !group.sheets.isEmpty { next.append(group) }
    let data = try JSONEncoder().encode(next)
    try data.write(to: root.appendingPathComponent("sheet-groups.json"), options: .atomic)
    groups = next
    snapshot = data
  }
}

struct SheetRecord: Identifiable {
  let id: String
  let folder: URL
  let document: ScanDocument

  static func load(in root: URL) throws -> [Self] {
    let folders = try FileManager.default.contentsOfDirectory(
      at: root.appendingPathComponent("Sessions"), includingPropertiesForKeys: nil)
    return folders.compactMap { folder in
      guard UUID(uuidString: folder.lastPathComponent) != nil,
        let data = try? Data(contentsOf: folder.appendingPathComponent("session.json")),
        let document = try? JSONDecoder().decode(ScanDocument.self, from: data),
        document.metadata?.sheetBatch == true, !document.pages.isEmpty else { return nil }
      return Self(id: folder.lastPathComponent, folder: folder, document: document)
    }.sorted { ($0.document.metadata?.reference ?? $0.id).localizedStandardCompare(
      $1.document.metadata?.reference ?? $1.id) == .orderedAscending }
  }
}
