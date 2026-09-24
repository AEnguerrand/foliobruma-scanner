import Foundation

// Return a new value. The caller saves it before changing its visible state.
public extension ScanDocument {
  var isSheetBatch: Bool { metadata?.sheetBatch == true }
  var sheetNeedsReview: Bool { !(rejected ?? []).isEmpty }
  var uploadOnFinish: Bool { automation?.upload == true }
  var printOnFinish: Bool { automation?.printLabel == true }

  func pageIndex(for text: String) -> Int? {
    guard let number = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)),
      number > 0, number <= pages.count else { return nil }
    return number - 1
  }

  func rotating(_ page: ScanPage) -> Self? {
    guard let index = pages.firstIndex(where: { $0.id == page.id }) else { return nil }
    var next = self
    next.pages[index].rotation = (page.rotation + 90) % 360
    return next
  }

  func removing(_ page: ScanPage) -> (document: Self, index: Int)? {
    guard let index = pages.firstIndex(where: { $0.id == page.id }) else { return nil }
    var next = self
    next.pages.remove(at: index)
    return (next, index)
  }

  func restoring(_ page: ScanPage, at index: Int) -> Self {
    var next = self
    next.pages.insert(page, at: max(0, min(index, next.pages.count)))
    return next
  }

  func movingPage(id: String, by delta: Int) -> Self? {
    guard let index = pages.firstIndex(where: { $0.id == id }) else { return nil }
    let (destination, overflow) = index.addingReportingOverflow(delta)
    guard !overflow, pages.indices.contains(destination) else { return nil }
    var next = self
    next.pages.swapAt(index, destination)
    return next
  }

  func applyingCapture(_ captured: [ScanPage], replacing id: String?, resolving file: String?) throws -> Self {
    var next = self
    if let id {
      guard captured.count == 1, let index = next.pages.firstIndex(where: { $0.id == id }) else {
        throw CloudFailure(message: "The page to replace is no longer available.")
      }
      var replacement = captured[0]
      replacement.id = id
      next.pages[index] = replacement
    } else {
      next.pages += captured
    }
    if let file { next = next.resolvingRejection(file) }
    return next
  }

  func resolvingRejection(_ file: String) -> Self {
    var next = self
    next.rejected?.removeAll { $0.file == file }
    next.resolvedRejections = Array(Set((next.resolvedRejections ?? []) + [file]))
    return next
  }
}
