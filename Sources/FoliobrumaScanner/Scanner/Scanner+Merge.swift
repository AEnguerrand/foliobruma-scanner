import ScannerCore
import AppKit
import CoreImage

extension Scanner {
  var canMergeWithNextPage: Bool {
    guard reviewing, !busy, !isSheetBatch, let index = selectedIndex else { return false }
    return document.pages.indices.contains(index + 1)
  }

  func mergeWithNextPage() {
    guard canMergeWithNextPage, let index = selectedIndex else { return }
    autoCapture = false
    busy = true
    error = nil
    status = L10n.text("Merging pages…")
    let sources = Array(document.pages[index...index + 1])
    let base = folder
    var next = document
    queue.async {
      do {
        let image = try Self.joinPages(sources, in: base)
        let file = "Pages/" + UUID().uuidString + "-merged.png"
        let url = base.appendingPathComponent(file)
        guard let data = self.context.pngRepresentation(
          of: image, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()) else {
          throw Self.mergeError()
        }
        try data.write(to: url, options: .atomic)
        // Crop from original uses the full merged image. Both source records and files remain.
        let merged = ScanPage(file: file, original: file, mergedSources: sources)
        next.pages.replaceSubrange(index...index + 1, with: [merged])
        let savedDocument = next
        DispatchQueue.main.async {
          do {
            try self.commit(savedDocument)
            self.selected = merged.id
            self.status = L10n.text("Pages merged · Original files kept")
          } catch {
            self.error = error.localizedDescription
            self.status = L10n.text("Merge failed · Pages unchanged")
          }
          self.busy = false
          self.finishPendingReview()
        }
      } catch {
        DispatchQueue.main.async {
          self.error = error.localizedDescription
          self.status = L10n.text("Merge failed · Pages unchanged")
          self.busy = false
          self.finishPendingReview()
        }
      }
    }
  }

  static func mergeError() -> NSError {
    NSError(domain: "Scanner", code: 13, userInfo: [
      NSLocalizedDescriptionKey: L10n.text("The pages could not be merged. Check the image files and their size.")
    ])
  }

  static func joinPages(_ pages: [ScanPage], in base: URL) throws -> CIImage {
    guard pages.count == 2 else { throw mergeError() }
    let images = try pages.map { page -> CIImage in
      guard let image = CIImage(contentsOf: base.appendingPathComponent(page.file)) else {
        throw mergeError()
      }
      // Review and PDF rotation are clockwise. Core Image uses an upward y axis.
      let orientation: Int32
      switch ((page.rotation % 360) + 360) % 360 {
      case 90: orientation = 6
      case 180: orientation = 3
      case 270: orientation = 8
      default: orientation = 1
      }
      let rotated = image.oriented(forExifOrientation: orientation)
      return rotated.transformed(by: CGAffineTransform(
        translationX: -rotated.extent.minX, y: -rotated.extent.minY))
    }
    let height = images.map { $0.extent.height }.max()!
    var offset: CGFloat = 0
    let fitted = try images.map { image -> CIImage in
      guard image.extent.height > 0 else { throw mergeError() }
      let scale = height / image.extent.height
      let width = (image.extent.width * scale).rounded()
      guard width.isFinite, height.isFinite, width > 0, height > 0,
        (offset + width) * height <= 100_000_000 else { throw mergeError() }
      let result = image.transformed(by: CGAffineTransform(
        scaleX: width / image.extent.width, y: scale))
        .transformed(by: CGAffineTransform(translationX: offset, y: 0))
      offset += width
      return result
    }
    return fitted[1].composited(over: fitted[0]).cropped(
      to: CGRect(x: 0, y: 0, width: offset, height: height))
  }
}
