import Foundation
import ScannerCore

// This records lock use in single-threaded tests only. It is not a production lock.
private final class RecordingLock: LibraryLocking {
  var paths: [String] = []
  var entered = false
  var fail = false
  func withLock<T>(at url: URL, _ body: () throws -> T) throws -> T {
    paths.append(url.lastPathComponent)
    if fail { throw CloudFailure(message: "Synthetic lock failure") }
    precondition(!entered)
    entered = true
    defer { entered = false }
    return try body()
  }
}

func require(_ value: @autoclosure () throws -> Bool, _ message: String = "Check failed") rethrows {
  let result = try value()
  precondition(result, message)
}

func expectFailure(_ operation: () throws -> Void) {
  do { try operation(); preconditionFailure("Expected operation to fail") } catch { }
}

extension ScannerCoreChecks {
  static func testSharedStorageAndEdits() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let front = ScanPage(file: "Pages/front.jpg", original: "Originals/front.jpg", rotation: 270)
    let back = ScanPage(file: "Pages/back.jpg", original: "Originals/back.jpg")
    var document = ScanDocument(title: "Synthetic sheet", pages: [front, back])
    let store = try SessionStore.create(document, in: root)
    let original = store.folder.appendingPathComponent(front.original)
    let source = Data("Synthetic original".utf8)
    try source.write(to: original)
    precondition(document.rotating(front)!.pages[0].rotation == 0)
    precondition(document.pages[0].rotation == 270, "Edits must return a new value")
    precondition(document.pageIndex(for: " 2 ") == 1 && document.pageIndex(for: "0") == nil)
    precondition(document.movingPage(id: front.id, by: -1) == nil)
    precondition(document.movingPage(id: back.id, by: Int.max) == nil)
    let reordered = document.movingPage(id: front.id, by: 1)!
    precondition(reordered.pages.map(\.id) == [back.id, front.id])
    let removal = document.removing(front)!
    let extra = ScanPage(file: "Pages/extra.jpg", original: "Originals/extra.jpg")
    let later = try removal.document.applyingCapture([extra], replacing: nil, resolving: nil)
    let restored = later.restoring(front, at: removal.index)
    precondition(restored.pages.map(\.id) == [front.id, back.id, extra.id])
    let replacement = ScanPage(file: "Pages/new.jpg", original: "Originals/new.jpg")
    document = try document.applyingCapture([replacement], replacing: front.id, resolving: nil)
    precondition(document.pages[0].id == front.id && document.pages[1].id == back.id)
    expectFailure { _ = try document.applyingCapture([front, back], replacing: front.id, resolving: nil) }
    expectFailure { _ = try document.applyingCapture([front], replacing: "missing", resolving: nil) }
    try store.save(document)
    try require(store.load().pages[0].original == replacement.original)
    try require(Data(contentsOf: original) == source, "Edits must keep old original files")

    let rejected = store.folder.appendingPathComponent("Rejected")
    try FileManager.default.createDirectory(at: rejected, withIntermediateDirectories: true)
    try source.write(to: rejected.appendingPathComponent("old.jpg"))
    try source.write(to: rejected.appendingPathComponent("unseen.JPG"))
    document = document.resolvingRejection("Rejected/old.jpg")
    document = store.recoveringRejections(in: document)
    precondition(document.rejected?.map(\.file) == ["Rejected/unseen.JPG"])
    precondition(store.recoveringRejections(in: document).rejected?.count == 1)
    let entries = SessionStore.list(in: root)
    precondition(entries.count == 1 && entries[0].folder.resolvingSymlinksInPath().path == store.folder.resolvingSymlinksInPath().path)

    let before = try Data(contentsOf: store.manifest)
    let blocker = root.appendingPathComponent("blocker")
    try source.write(to: blocker)
    expectFailure { try SessionStore(folder: blocker).save(document) }
    expectFailure { _ = try SessionStore.create(document, in: blocker) }
    try require(Data(contentsOf: store.manifest) == before)
    let corrupt = Data("Not JSON".utf8)
    try corrupt.write(to: store.manifest)
    expectFailure { _ = try store.loadIfPresent() }
    try require(Data(contentsOf: store.manifest) == corrupt)
    print("PASS: shared page edits, replacement identity, original preservation, session recovery and failed writes")
  }

  static func testSharedReferencesAndGroups() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let lock = RecordingLock()
    try require(ItemReference.reserve(in: root, letter: false, locking: lock) == "DOC-0001")
    let document = ScanDocument(title: "Restored", metadata: ItemMetadata(reference: "LET-0100", sheetBatch: true),
      pages: [ScanPage(file: "Pages/a.jpg", original: "Originals/a.jpg")])
    let session = try SessionStore.create(document, in: root)
    try require(ItemReference.reserve(in: root, letter: true, locking: lock) == "LET-0101")
    precondition(lock.paths == ["item-reference.lock", "item-reference.lock"] && !lock.entered)
    lock.fail = true
    expectFailure { _ = try ItemReference.reserve(in: root, letter: false, locking: lock) }
    lock.fail = false
    try require(ItemReference.reserve(in: root, letter: false, locking: lock) == "DOC-0102")

    var store = try SheetGroupStore.load(in: root)
    var stale = store
    let id = session.folder.lastPathComponent
    let group = SheetGroup(title: "Letter", sheets: [id])
    try store.save(group, in: root, locking: lock)
    precondition(lock.paths.last == "sheet-groups.lock" && !lock.entered)
    expectFailure { try stale.save(SheetGroup(title: "Stale", sheets: []), in: root, locking: lock) }
    expectFailure { try store.save(SheetGroup(title: "Overlap", sheets: [id]), in: root, locking: lock) }
    expectFailure { try store.save(SheetGroup(title: "Invalid", sheets: ["../outside"]), in: root, locking: lock) }
    expectFailure { try store.save(SheetGroup(title: "Duplicate", sheets: [id, id]), in: root, locking: lock) }
    try require(SheetGroupStore.load(in: root).groups == [group])
    try require(SheetRecord.load(in: root).map(\.id) == [id])
    let snapshot = store.snapshot
    let corrupt = Data("Broken groups".utf8)
    try corrupt.write(to: root.appendingPathComponent("sheet-groups.json"))
    expectFailure { try store.save(group, in: root, locking: lock) }
    precondition(store.snapshot == snapshot && store.groups == [group])
    try require(Data(contentsOf: root.appendingPathComponent("sheet-groups.json")) == corrupt)
    print("PASS: shared reference recovery, required locks, stale group and overlap guards, corrupt-store preservation")
  }
}
