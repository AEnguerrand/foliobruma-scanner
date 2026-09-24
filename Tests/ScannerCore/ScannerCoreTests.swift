import Foundation
import ScannerCore

// A plain executable keeps these checks usable with Command Line Tools alone.
private func expectEqual<T: Equatable>(_ actual: T, _ expected: T) {
  precondition(actual == expected, "Expected \(expected), received \(actual)")
}
private func expectTrue(_ value: Bool) { precondition(value) }
private func expectFalse(_ value: Bool) { precondition(!value) }
private func expectNil<T>(_ value: T?) { precondition(value == nil) }

@main struct ScannerCoreChecks {
  static func main() async throws {
    try testSharedStorageAndEdits()
    try testSharedReferencesAndGroups()
    try await testSharedArchiveWorkflows()
    try testSharedPrinterRules()
    try testLegacySessionDecoding()
    try testSessionWireFormatAndOriginals()
    try testBatchDefaultsAndGroupOrder()
    testCaptureGateResetsForEachBlockingCondition()
    testWarningsRemainOneShotUntilReset()
    print("PASS: shared session compatibility, batch defaults, capture gates, and warning resets")
  }
  static func testLegacySessionDecoding() throws {
    let data = Data(#"{"title":"Old book","pages":[{"id":"page-1","file":"Pages/1.jpg","original":"Originals/1.jpg","rotation":90}]}"#.utf8)
    let document = try JSONDecoder().decode(ScanDocument.self, from: data)
    expectEqual(document.title, "Old book")
    expectEqual(document.pages[0].rotation, 90)
    expectNil(document.pages[0].mergedSources)
    expectNil(document.metadata)
    expectNil(document.automation)
    expectNil(document.rejected)
    expectNil(document.resolvedRejections)
  }

  static func testSessionWireFormatAndOriginals() throws {
    // Synthetic fixture uses the existing CGPoint array encoding and session keys.
    let data = Data(#"{"title":"Letter","pages":[{"id":"merged","file":"Pages/merged.jpg","original":"Originals/merged.jpg","rotation":180,"mergedSources":[{"id":"source","file":"Pages/source.jpg","original":"Originals/source.jpg","rotation":90}]}],"rejected":[{"file":"Rejected/1.jpg","reason":"Test","quad":{"tl":[0,1],"tr":[1,1],"br":[1,0],"bl":[0,0]},"split":true,"divider":0.4,"replacementID":"source"}],"resolvedRejections":["Rejected/old.jpg"],"automation":{"upload":false,"printLabel":false,"printerName":""}}"#.utf8)
    let document = try JSONDecoder().decode(ScanDocument.self, from: data)
    expectEqual(document.pages[0].mergedSources?[0].original, "Originals/source.jpg")
    expectEqual(document.rejected?[0].quad?.area, 1)
    let encoded = try JSONEncoder().encode(document)
    expectEqual(try JSONSerialization.jsonObject(with: encoded) as? NSDictionary,
                   try JSONSerialization.jsonObject(with: data) as? NSDictionary)
  }

  static func testBatchDefaultsAndGroupOrder() throws {
    let metadata = ItemMetadata(reference: "DOC-0001", batchID: "batch", batchName: "Archive",
      kind: "Sheet", author: "Sender", period: "1900", location: "Folio 1", tags: "Letters",
      notes: "Private note", webLink: "https://example.com", sheetBatch: true)
    let next = metadata.nextLetter
    expectEqual(next.batchID, "batch")
    expectEqual(next.batchName, "Archive")
    expectEqual(next.location, "Folio 1")
    expectEqual(next.tags, "Letters")
    expectEqual(next.kind, "Sheet")
    expectEqual(next.sheetBatch, true)
    expectEqual([next.reference, next.author, next.period, next.notes, next.webLink], Array(repeating: "", count: 5))
    let group = SheetGroup(title: "Letter", sheets: ["third", "first", "second"])
    expectEqual(try JSONDecoder().decode(SheetGroup.self, from: JSONEncoder().encode(group)), group)
    let automation = SessionAutomation()
    expectFalse(automation.upload)
    expectFalse(automation.printLabel)
  }

  static func testCaptureGateResetsForEachBlockingCondition() {
    for condition in 0..<4 {
      var gate = AutoCaptureGate()
      expectFalse(gate.ready(at: 0, moving: false, blocked: false, duplicate: false, hasPage: true))
      expectFalse(gate.ready(at: 0.54, moving: false, blocked: false, duplicate: false, hasPage: true))
      expectTrue(gate.ready(at: 0.56, moving: false, blocked: false, duplicate: false, hasPage: true))
      expectFalse(gate.ready(at: 1, moving: condition == 0, blocked: condition == 1,
                                duplicate: condition == 2, hasPage: condition != 3))
      expectFalse(gate.ready(at: 2, moving: false, blocked: false, duplicate: false, hasPage: true))
      expectTrue(gate.ready(at: 2.56, moving: false, blocked: false, duplicate: false, hasPage: true))
      gate.captured(at: 3)
      expectFalse(gate.ready(at: 3.7, moving: false, blocked: false, duplicate: false, hasPage: true))
      expectFalse(gate.ready(at: 3.9, moving: false, blocked: false, duplicate: false, hasPage: true))
      expectTrue(gate.ready(at: 4.5, moving: false, blocked: false, duplicate: false, hasPage: true))
    }
  }

  static func testWarningsRemainOneShotUntilReset() {
    var warning = PreflightFeedbackGate()
    expectFalse(warning.observe("Hand", at: 0))
    expectFalse(warning.observe("Hand", at: 1.4))
    expectTrue(warning.observe("Hand", at: 1.5))
    expectFalse(warning.observe("Hand", at: 3))
    expectFalse(warning.observe(nil, at: 4))
    expectFalse(warning.observe("Hand", at: 5))
    expectTrue(warning.observe("Hand", at: 6.5))
    var duplicate = DuplicateFeedbackGate()
    expectTrue(duplicate.notify())
    expectFalse(duplicate.notify())
    duplicate.reset()
    expectTrue(duplicate.notify())
  }
}
