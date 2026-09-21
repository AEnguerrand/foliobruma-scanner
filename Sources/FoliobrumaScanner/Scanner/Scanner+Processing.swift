import AppKit
import CoreImage

extension Scanner {
  func process(_ source: CIImage, originalData: Data?, overrideQuality: Bool = false) {
    report(L10n.text("Checking scan quality…"))
    let options = captureOptions ?? (nil, false, 0.5, false)
    do {
      let print = CaptureCheck.fingerprint(source, context: context)
      let previewPrint = overrideQuality ? nil : capturePreviewPrint
      if !overrideQuality {
        if try CaptureCheck.hasHands(source, context: context) {
          try rejectCapture(
            "Hand in the scan · Move your hands away", source: source, data: originalData)
          return
        }
        if options.automatic {
          guard let print = print else {
            try rejectCapture(
              "Could not check this scan · Try again", source: source, data: originalData)
            return
          }
          if CaptureCheck.duplicate(print, of: recentPrints) {
            captureInFlight = false
            gate.reset()
            heldReason = L10n.text("Page already saved · Turn the page")
            DispatchQueue.main.async {
              self.busy = false
              self.showDuplicate()
            }
            return
          }
        }
        if options.quad != nil,
          let edges = PaperDetector.detect(source, context: context, book: options.split),
          PageQuality.touchesFrame(edges)
        {
          try rejectCapture(
            "Page may be cut off · Move it inside the camera view", source: source,
            data: originalData)
          return
        }
      }
      let id = UUID().uuidString
      let original = "Originals/\(id).jpg"
      let data =
        originalData ?? context.jpegRepresentation(
          of: source, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:])!
      var output = source
      if let q = options.quad {
        func v(_ p: CGPoint) -> CIVector {
          CIVector(
            x: source.extent.minX + p.x * source.extent.width,
            y: source.extent.minY + p.y * source.extent.height)
        }
        output = source.applyingFilter(
          "CIPerspectiveCorrection",
          parameters: [
            "inputTopLeft": v(q.tl), "inputTopRight": v(q.tr), "inputBottomRight": v(q.br),
            "inputBottomLeft": v(q.bl),
          ])
      }
      if !overrideQuality, let reason = PageQuality.measure(output, context: context).reason {
        try rejectCapture(reason, source: source, data: originalData)
        return
      }
      try data.write(to: folder.appendingPathComponent(original), options: .atomic)
      var results: [ScanPage] = []
      for i in 0..<(options.split ? 2 : 1) {
        var area = output.extent
        if options.split {
          let left = area.width * options.divider
          if i == 0 {
            area.size.width = left
          } else {
            area.origin.x += left
            area.size.width -= left
          }
        }
        guard let cg = context.createCGImage(output, from: area) else {
          throw NSError(
            domain: "Scanner", code: 2,
            userInfo: [NSLocalizedDescriptionKey: L10n.text("Image processing failed")])
        }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.96])
        else { throw NSError(domain: "Scanner", code: 3) }
        let file = "Pages/\(id)-\(i+1).jpg"
        try jpeg.write(to: folder.appendingPathComponent(file), options: .atomic)
        results.append(ScanPage(file: file, original: original))
      }
      DispatchQueue.main.async {
        let replacement = self.captureReplacementID
        var saved = false
        do {
          try self.applyCapture(results, replacing: replacement, resolving: self.keptRejection)
          self.keptRejection = nil
          self.replacementID = nil
          self.qualityWarning = nil
          self.rejectedURL = nil
          saved = true
          self.status =
            L10n.format(
              results.count == 1 ? "One page saved · Turn the page" : "%ld pages saved · Turn the page",
              results.count)
          if self.isSheetBatch { self.status = self.sheetCapturePrompt }
          self.confirmCapture()
          if let print = print {
            self.queue.async {
              self.recentPrints.append(print)
              self.recentPrints = Array(self.recentPrints.suffix(4))
              if let previewPrint = previewPrint {
                self.recentPreviewPrints.append(previewPrint)
                self.recentPreviewPrints = Array(self.recentPreviewPrints.suffix(4))
              }
            }
          }
        } catch { self.error = L10n.format("Could not save session: %@", error.localizedDescription) }
        self.queue.async {
          self.captureInFlight = false
          self.gate.reset()
          self.heldFrame = nil
          self.heldReason = L10n.text("Page already saved · Turn the page")
        }
        self.busy = false
        if saved, let replacement = replacement { self.beginReview(replacement) }
        self.finishPendingReview()
        self.resolution = "\(Int(source.extent.width)) × \(Int(source.extent.height))"
      }
    } catch {
      captureInFlight = false
      DispatchQueue.main.async {
        self.busy = false
        self.error = error.localizedDescription
        self.finishPendingReview()
      }
    }
  }
  func rejectCapture(_ reason: String, source: CIImage, data: Data?) throws {
    let directory = folder.appendingPathComponent("Rejected", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(UUID().uuidString + ".jpg")
    guard
      let bytes = data
        ?? context.jpegRepresentation(
          of: source, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:])
    else { throw NSError(domain: "Scanner", code: 5) }
    try bytes.write(to: url, options: .atomic)
    captureInFlight = false
    gate.reset()
    heldFrame = previous
    heldReason = L10n.format("Rescan · %@", L10n.text(reason))
    DispatchQueue.main.async {
      self.busy = false
      self.autoCapture = false
      let options = self.captureOptions ?? (nil, false, 0.5, false)
      var next = self.document
      var rejected = next.rejected ?? []
      rejected.append(
        RejectedScan(
          file: "Rejected/" + url.lastPathComponent, reason: reason,
          quad: options.quad, split: options.split, divider: options.divider,
          replacementID: self.captureReplacementID))
      next.rejected = rejected
      do { try self.commit(next) } catch {
        self.document.rejected = rejected
        self.sessionSaved = false
        self.error =
          L10n.format("The rejected photo is saved, but its session record could not be saved: %@", error.localizedDescription)
      }
      self.showRejected = true
      self.captureSaved = false
      self.duplicateWarning = false
      self.qualityWarning = L10n.text(reason)
      self.rejectedURL = url
      self.status = L10n.text("Rescan needed")
      if self.soundEnabled && self.tracksActiveSession { NSSound(named: "Basso")?.play() }
    }
  }
  func keepRejected() {
    guard !busy, let url = rejectedURL else { return }
    autoCapture = false
    busy = true
    keptRejection = "Rejected/" + url.lastPathComponent
    queue.async {
      self.captureInFlight = true
      do {
        let data = try Data(contentsOf: url)
        guard let image = CIImage(data: data) else { throw NSError(domain: "Scanner", code: 6) }
        self.process(image, originalData: data, overrideQuality: true)
      } catch {
        self.captureInFlight = false
        DispatchQueue.main.async {
          self.busy = false
          self.error = error.localizedDescription
          self.finishPendingReview()
        }
      }
    }
  }
}
