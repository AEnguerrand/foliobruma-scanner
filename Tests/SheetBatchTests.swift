#if SCANNER_TESTS
import Foundation

extension SessionTests {
 static func testSheetBatches() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("sheet-test-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let scanner = Scanner(storageRoot: root)
  let legacy = try JSONDecoder().decode(ItemMetadata.self, from: JSONEncoder().encode(ItemMetadata()))
  precondition(legacy.sheetBatch == nil)
  let details = ItemMetadata(batchID: UUID().uuidString, batchName: "Mixed papers", kind: "Sheet",
    author: "Synthetic sender", location: "Folio 1", tags: "Test", notes: "First sheet only", sheetBatch: true)
  try scanner.createItem(title: "", metadata: details, scanPages: true)
  precondition(scanner.isSheetBatch && !scanner.book && !scanner.split && !scanner.metadataWorkspace)
  let empty = scanner.folder
  scanner.performUSBAction(.finishSheet)
  precondition(scanner.folder == empty && !scanner.busy, "Ignore completion of an empty sheet")
  let front = ScanPage(file: "Pages/front.jpg", original: "Originals/front.jpg")
  let back = ScanPage(file: "Pages/back.jpg", original: "Originals/back.jpg")
  try Data("synthetic original".utf8).write(to: scanner.folder.appendingPathComponent(front.original))
  try scanner.applyCapture([front], replacing: nil, resolving: nil)
  scanner.connected = true
  scanner.autoCapture = true
  scanner.queue.sync {
    scanner.recentPrints = [CaptureCheck.Fingerprint(pixels: [13], aspect: 1)]
    scanner.recentPreviewPrints = [CaptureCheck.Fingerprint(pixels: [14], aspect: 1)]
  }
  let firstReference = scanner.document.metadata!.reference
  scanner.performUSBAction(.finishSheet)
  waitForWork(scanner)
  precondition(scanner.error == nil && scanner.folder != empty && scanner.document.pages.isEmpty)
  precondition(scanner.autoCapture && scanner.document.metadata?.reference != firstReference)
  precondition(scanner.document.metadata?.sheetBatch == true && scanner.document.metadata?.location == details.location)
  precondition(scanner.document.metadata?.notes == "" && scanner.document.metadata?.webLink == "")
  scanner.queue.sync {
    precondition(scanner.recentPrints.first?.pixels == [13] && scanner.recentPreviewPrints.first?.pixels == [14],
      "Keep duplicate history when the finished sheet is still under the camera")
  }
  let savedFront = try JSONDecoder().decode(ScanDocument.self, from: readData(empty.appendingPathComponent("session.json")))
  precondition(savedFront.pages.map(\.id) == [front.id])
  precondition(readData(empty.appendingPathComponent(front.original)) == Data("synthetic original".utf8))

  try scanner.applyCapture([front], replacing: nil, resolving: nil)
  try scanner.applyCapture([back], replacing: nil, resolving: nil)
  precondition(scanner.sheetIsFull && !scanner.autoCapture, "Two sides pause capture until explicit completion")
  let both = scanner.folder
  let fullBytes = readData(both.appendingPathComponent("session.json"))
  do { try scanner.applyCapture([back], replacing: nil, resolving: nil); preconditionFailure("Do not append a third side") }
  catch { }
  precondition(readData(both.appendingPathComponent("session.json")) == fullBytes)
  scanner.performUSBAction(.autoCapture)
  scanner.capture()
  precondition(!scanner.autoCapture && !scanner.busy, "A full sheet cannot restart or capture a third side")
  scanner.beginReview()
  precondition(!scanner.canMergeWithNextPage, "Front and back must remain separate pages")
  try scanner.applyCapture([ScanPage(file: "Pages/replacement.jpg", original: "Originals/replacement.jpg")],
    replacing: front.id, resolving: nil)
  precondition(scanner.document.pages.count == 2 && scanner.document.pages[0].id == front.id)
  scanner.remove(scanner.document.pages[1])
  try scanner.applyCapture([back], replacing: nil, resolving: nil)
  scanner.undo()
  precondition(scanner.error != nil && scanner.document.pages.count == 2,
    "Undo must not add a third side after a new capture fills the sheet")
  scanner.error = nil
  scanner.showCamera()
  scanner.performUSBAction(.nextDocument)
  waitForWork(scanner)
  precondition(scanner.error == nil && scanner.folder != both && scanner.autoCapture)
  let savedBoth = try JSONDecoder().decode(ScanDocument.self, from: readData(both.appendingPathComponent("session.json")))
  precondition(savedBoth.pages.map(\.id) == [front.id, back.id])

  try scanner.applyCapture([front], replacing: nil, resolving: nil)
  let pending = RejectedScan(file: "Rejected/test.jpg", reason: "Test", quad: nil, split: false, divider: 0.5)
  scanner.document.rejected = [pending]
  let rejectedFolder = scanner.folder
  scanner.finishSheet()
  precondition(scanner.folder == rejectedFolder && scanner.showRejected && !scanner.autoCapture)
  scanner.dismissRejected(pending)
  scanner.showRejected = false
  scanner.showCamera()
  scanner.showSheetGroups = true
  scanner.performUSBAction(.finishSheet)
  precondition(scanner.folder == rejectedFolder && !scanner.busy)
  scanner.showSheetGroups = false
  let blocker = root.appendingPathComponent("blocker")
  try Data("blocked".utf8).write(to: blocker)
  scanner.root = blocker
  scanner.finishSheet()
  waitForWork(scanner)
  precondition(scanner.error != nil && scanner.folder == rejectedFolder && !scanner.autoCapture,
    "Failed next-sheet writes must leave the saved sheet open and capture paused")
  scanner.root = root
  scanner.error = nil
  scanner.openSession(at: both)
  precondition(scanner.isSheetBatch && scanner.sheetIsFull && !scanner.autoCapture)
  print("PASS: one- and two-sided sheets; USB completion; side limit; duplicate history; replacement; rejected and modal guards; failed-write recovery; reload")
 }

 static func testSheetGroups() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("sheet-groups-test-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  var store = try SheetGroupStore.load(in: root)
  var stale = store
  let ids = (0..<2000).map { _ in UUID().uuidString }
  var sheet = ScanDocument()
  sheet.metadata = ItemMetadata(reference: "LET-0001", sheetBatch: true)
  sheet.pages = [ScanPage(file: "Pages/test.jpg", original: "Originals/test.jpg")]
  let manifest = try JSONEncoder().encode(sheet)
  let sheetFolder = root.appendingPathComponent("Sessions/" + ids[0])
  try FileManager.default.createDirectory(at: sheetFolder, withIntermediateDirectories: true)
  try manifest.write(to: sheetFolder.appendingPathComponent("session.json"))
  let records = try SheetRecord.load(in: root)
  precondition(records.count == 1 && records[0].id == ids[0] && records[0].document.pages.count == 1)
  let fingerprint = try CloudUpload.fingerprint(sheet)
  let group = SheetGroup(title: "Mixed archive", sheets: ids)
  try store.save(group, in: root)
  precondition(try! SheetGroupStore.load(in: root).groups == [group])
  do { try stale.save(SheetGroup(title: "Stale", sheets: [UUID().uuidString]), in: root); preconditionFailure("Reject stale writes") }
  catch { }
  do { try store.save(SheetGroup(title: "Overlap", sheets: [ids[0]]), in: root); preconditionFailure("Reject overlapping groups") }
  catch { }
  var changed = group
  changed.sheets.reverse()
  changed.sheets.removeLast()
  try store.save(changed, in: root)
  precondition(try! SheetGroupStore.load(in: root).groups == [changed])
  let other = SheetGroup(title: "Another letter", sheets: [ids[0]])
  try store.save(other, in: root)
  var invalid = other
  invalid.sheets = ["../outside"]
  do { try store.save(invalid, in: root); preconditionFailure("Reject invalid identifiers") } catch { }
  invalid.sheets = [ids[0], ids[0]]
  do { try store.save(invalid, in: root); preconditionFailure("Reject duplicate membership") } catch { }
  changed.sheets = []
  try store.save(changed, in: root)
  precondition(try! SheetGroupStore.load(in: root).groups == [other])
  precondition(readData(sheetFolder.appendingPathComponent("session.json")) == manifest,
    "Linking and unlinking must not change individual sheet manifests")
  let reloaded = try SheetRecord.load(in: root)[0].document
  precondition(try! CloudUpload.fingerprint(reloaded) == fingerprint,
    "Grouping must not trigger another sheet upload or invalidate its label")
  let corrupt = Data("invalid group store".utf8)
  try corrupt.write(to: root.appendingPathComponent("sheet-groups.json"))
  do { _ = try SheetGroupStore.load(in: root); preconditionFailure("Do not erase an unreadable store") } catch { }
  do { try store.save(other, in: root); preconditionFailure("Do not overwrite an unreadable store") } catch { }
  precondition(readData(root.appendingPathComponent("sheet-groups.json")) == corrupt)
  print("PASS: 2,000 ordered sheet links; reload; reorder and unlink; independent groups; stale-write and overlap guards; corrupt-store preservation")
 }

 static func testSheetLabelRetry() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("sheet-label-test-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  var upload = CloudUpload(fingerprint: "test", userID: "test", organisationID: UUID().uuidString,
    file: "test.pdf", name: "test.pdf")
  var jobs = 0
  do {
    try upload.submitSheetLabel(in: root) {
      jobs += 1
      precondition(try! CloudUpload.load(in: root)!.sheetLabelStarted == true)
      return false
    }
    preconditionFailure("Cancelled print must keep the sheet open")
  } catch { }
  upload = try CloudUpload.load(in: root)!
  precondition(upload.sheetLabelSubmitted == false && upload.sheetLabelStarted == false)
  try upload.submitSheetLabel(in: root) { jobs += 1; return true }
  upload = try CloudUpload.load(in: root)!
  try upload.submitSheetLabel(in: root) { jobs += 1; return true }
  precondition(jobs == 2 && upload.sheetLabelSubmitted == true, "Submitted labels must not repeat on retry")
  upload.sheetLabelSubmitted = false
  upload.sheetLabelStarted = true
  try upload.save(in: root)
  do { try upload.submitSheetLabel(in: root) { jobs += 1; return true }; preconditionFailure("Reject an unknown print result") }
  catch { }
  precondition(jobs == 2)
  print("PASS: label cancellation retry; persisted print intent; no repeated submitted labels; unknown print result blocks submission")
 }
}
#endif
