import AVFoundation
import AppKit
import CoreImage

extension Scanner {
  func refreshCameras() {
    guard !busy else { return }
    devices =
      AVCaptureDevice.DiscoverySession(
        deviceTypes: [.external, .builtInWideAngleCamera],
        mediaType: .video, position: .unspecified
      ).devices
    if !devices.contains(where: { $0.uniqueID == deviceID }) {
      deviceID = devices.first?.uniqueID ?? ""
      connected = false
      autoCapture = false
    }
  }
  func previewFraming() {
    guard !busy, connected else { return }
    autoCapture = false
    let crop = autoCrop ? quad : nil
    if autoCrop && crop == nil {
      error = L10n.text("No page edges found. Turn off Auto crop to preview the full frame.")
      return
    }
    let shouldSplit = book && split && replacementID == nil
    let spine = divider
    busy = true
    framingImages = []
    showFraming = true
    queue.async {
      guard var output = self.latest else {
        DispatchQueue.main.async {
          self.busy = false
          self.showFraming = false
          self.error = L10n.text("No camera frame is available.")
        }
        return
      }
      if let q = crop {
        let extent = output.extent
        func v(_ point: CGPoint) -> CIVector {
          CIVector(
            x: extent.minX + point.x * extent.width, y: extent.minY + point.y * extent.height)
        }
        output = output.applyingFilter(
          "CIPerspectiveCorrection",
          parameters: [
            "inputTopLeft": v(q.tl), "inputTopRight": v(q.tr),
            "inputBottomLeft": v(q.bl), "inputBottomRight": v(q.br),
          ])
      }
      var images: [CGImage] = []
      for index in 0..<(shouldSplit ? 2 : 1) {
        var area = output.extent
        if shouldSplit {
          let left = area.width * spine
          if index == 0 {
            area.size.width = left
          } else {
            area.origin.x += left
            area.size.width -= left
          }
        }
        if let image = self.context.createCGImage(output, from: area) { images.append(image) }
      }
      DispatchQueue.main.async {
        self.framingImages = images.map { NSImage(cgImage: $0, size: .zero) }
        self.busy = false
        if images.isEmpty { self.error = L10n.text("Could not create the framing preview.") }
      }
    }
  }
  func cropSelectedPage(to normalized: CGRect) {
    guard !busy, let page = selectedPage,
      normalized.minX >= 0, normalized.minY >= 0,
      normalized.maxX <= 1, normalized.maxY <= 1,
      normalized.width >= 0.02, normalized.height >= 0.02
    else { return }
    autoCapture = false
    busy = true
    let base = folder
    queue.async {
      do {
        guard let source = CIImage(contentsOf: base.appendingPathComponent(page.original)) else {
          throw NSError(
            domain: "Scanner", code: 11,
            userInfo: [NSLocalizedDescriptionKey: L10n.text("The original image is missing.")])
        }
        let extent = source.extent
        let area = CGRect(
          x: extent.minX + normalized.minX * extent.width,
          y: extent.minY + normalized.minY * extent.height,
          width: normalized.width * extent.width, height: normalized.height * extent.height)
        guard let image = self.context.createCGImage(source, from: area),
          let data = NSBitmapImageRep(cgImage: image).representation(
            using: .jpeg, properties: [.compressionFactor: 0.96])
        else {
          throw NSError(
            domain: "Scanner", code: 12,
            userInfo: [NSLocalizedDescriptionKey: L10n.text("The crop could not be created.")])
        }
        let file = "Pages/" + UUID().uuidString + "-crop.jpg"
        try data.write(to: base.appendingPathComponent(file), options: .atomic)
        DispatchQueue.main.async {
          var next = self.document
          guard let index = next.pages.firstIndex(where: { $0.id == page.id }) else {
            self.busy = false
            return
          }
          next.pages[index].file = file
          do {
            try self.commit(next)
            self.showCrop = false
            self.status = L10n.text("Crop saved · Original image kept")
          } catch { self.error = error.localizedDescription }
          self.busy = false
        }
      } catch {
        DispatchQueue.main.async {
          self.busy = false
          self.error = error.localizedDescription
        }
      }
    }
  }
}
