#if SCANNER_TESTS
import Foundation
import ScannerCore

private actor LabelTestSender {
  var count = 0
  func send(_ data: Data) { precondition(!data.isEmpty); count += 1 }
}

extension SessionTests {
  @MainActor static func runLocationLabelChecks() throws {
    var finished = false
    var failure: Error?
    Task { @MainActor in
      do { try await testLocationLabelPrinting() } catch { failure = error }
      finished = true
    }
    let deadline = Date().addingTimeInterval(30)
    while !finished && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    precondition(finished, "Location print test timed out")
    if let failure { throw failure }
  }

  @MainActor static func testLocationLabelPrinting() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("location-label-test-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = URL(string: "foliobruma-scanner://label?v=1&title=Box+12&url=https%3A%2F%2Ffoliobruma.com%2Fl%2F1234567890abcdef")!
    let request = LocationLabelRequest(url: url)!
    let sender = LabelTestSender()
    let model = LocationLabelPrinter(folder: root) { await sender.send($0) }
    model.prepare(request)
    precondition(model.qr != nil && model.failure == nil && model.state == nil)
    let before = await sender.count
    precondition(before == 0, "Opening a handoff must never print")
    await model.printLabel()
    precondition(model.printed && model.state == .submitted)
    model.prepare(request)
    await model.printLabel()
    let once = await sender.count
    precondition(once == 1 && model.failure != nil, "Duplicate requests must not send a second job")
    model.retryPreparation()
    await model.printLabel(reprint: true)
    let twice = await sender.count
    precondition(twice == 2 && model.printed)
    let failedRoot = root.appendingPathComponent("uncertain")
    let failed = LocationLabelPrinter(folder: failedRoot) { _ in throw QL600Failure(message: "Test failure", sent: true) }
    failed.prepare(request)
    await failed.printLabel()
    precondition(failed.state == .pending && failed.failure != nil)
    let reopened = LocationLabelPrinter(folder: failedRoot) { await sender.send($0) }
    reopened.prepare(request)
    precondition(reopened.state == .pending)
    await reopened.printLabel()
    let after = await sender.count
    precondition(after == 2 && reopened.failure != nil, "Unknown print results survive reopening")
    let unsent = LocationLabelPrinter(folder: root.appendingPathComponent("unsent")) { _ in throw QL600Failure(message: "Test unplugged", sent: false) }
    unsent.prepare(request)
    await unsent.printLabel()
    precondition(unsent.state == nil && unsent.failure != nil)
    print("PASS: handoff preview does not print, explicit USB print, reprint guard, persistent uncertain outcomes")
  }
}
#endif
