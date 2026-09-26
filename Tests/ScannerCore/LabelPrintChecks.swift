import Foundation
import ScannerCore

private struct PrintTestLock: LibraryLocking {
  func withLock<T>(at url: URL, _ body: () throws -> T) throws -> T { try body() }
}

extension ScannerCoreChecks {
  static func testPrintHistory() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let lock = PrintTestLock()
    let link = "https://example.com/d/synthetic"
    // A manual job is reserved on disk before any printer can receive bytes.
    let manual = try LabelPrintStore.begin(in: root, link: link, lock: lock)
    try require(LabelPrintStore.state(in: root, link: link) == .pending)
    expectFailure { _ = try LabelPrintStore.begin(in: root, link: link, lock: lock) }
    try LabelPrintStore.finish(manual, in: root, submitted: true, mayHavePrinted: true, lock: lock)
    // A later automatic job must not print the same link, including after reload.
    expectFailure { _ = try LabelPrintStore.begin(in: root, link: link, lock: lock) }
    try require(LabelPrintStore.state(in: root, link: link) == .submitted)
    let cancelledReprint = try LabelPrintStore.begin(in: root, link: link, reprint: true, lock: lock)
    try LabelPrintStore.finish(cancelledReprint, in: root, submitted: false, mayHavePrinted: false, lock: lock)
    try require(LabelPrintStore.state(in: root, link: link) == .submitted)
    let reprint = try LabelPrintStore.begin(in: root, link: link, reprint: true, lock: lock)
    try LabelPrintStore.finish(reprint, in: root, submitted: false, mayHavePrinted: true, lock: lock)
    try require(LabelPrintStore.state(in: root, link: link) == .pending)
    expectFailure { _ = try LabelPrintStore.begin(in: root, link: link, lock: lock) }
    try LabelPrintStore.confirmHandled(in: root, link: link, lock: lock)
    try require(LabelPrintStore.state(in: root, link: link) == .submitted)
    // A stale completion cannot overwrite a newer confirmation.
    expectFailure { try LabelPrintStore.finish(reprint, in: root, submitted: false, mayHavePrinted: true, lock: lock) }
    let other = "https://example.com/d/other"
    let cancelled = try LabelPrintStore.begin(in: root, link: other, lock: lock)
    try LabelPrintStore.finish(cancelled, in: root, submitted: false, mayHavePrinted: false, lock: lock)
    try require(LabelPrintStore.state(in: root, link: other) == nil)
    var legacy = CloudUpload(fingerprint: "test", userID: "test", organisationID: "test", file: "test.pdf", name: "test.pdf")
    legacy.complete = true
    legacy.documentID = "legacy"
    legacy.sheetLabelSubmitted = true
    try legacy.save(in: root)
    try require(LabelPrintStore.state(in: root, link: legacy.link!) == .submitted)
    legacy.sheetLabelStarted = true
    try legacy.save(in: root)
    try require(LabelPrintStore.state(in: root, link: legacy.link!) == .pending)
    expectFailure { _ = try LabelPrintStore.begin(in: root, link: legacy.link!, lock: lock) }
    let corrupt = Data("broken print history".utf8)
    try corrupt.write(to: root.appendingPathComponent("label-prints.json"))
    expectFailure { _ = try LabelPrintStore.begin(in: root, link: other, lock: lock) }
    try require(Data(contentsOf: root.appendingPathComponent("label-prints.json")) == corrupt)
    expectFailure { _ = try LabelPrintStore.begin(in: root.appendingPathComponent("missing"), link: other, lock: lock) }
    print("PASS: shared manual/automatic print history; restart; explicit reprint; cancellation; uncertain output; legacy migration; stale completion; corrupt and failed writes")
  }
}
