import AVFoundation
import CoreImage
import Foundation
import Vision

extension Scanner: AVCaptureVideoDataOutputSampleBufferDelegate {
  func connect() {
    guard !busy else { return }
    autoCapture = false
    status = L10n.text("Requesting camera access…")
    AVCaptureDevice.requestAccess(for: .video) { allowed in
      guard allowed else {
        DispatchQueue.main.async {
          self.error =
            L10n.text("Camera access is off. Enable Foliobruma Scanner in System Settings → Privacy & Security → Camera.")
        }
        return
      }
      self.report(L10n.text("Opening scanner…"))
      self.queue.async { self.configure() }
    }
  }
  func configure() {
    guard let device = devices.first(where: { $0.uniqueID == deviceID }) else {
      report(L10n.text("Select a camera first"))
      return
    }
    session.stopRunning()
    session.beginConfiguration()
    var configurationOpen = true
    if let old = input { session.removeInput(old) }
    do {
      let next = try AVCaptureDeviceInput(device: device)
      guard session.canAddInput(next) else {
        throw NSError(
          domain: "Scanner", code: 1,
          userInfo: [NSLocalizedDescriptionKey: L10n.text("This camera cannot be opened.")])
      }
      session.addInput(next)
      input = next
      if session.canSetSessionPreset(.photo) {
        session.sessionPreset = .photo
      } else {
        session.sessionPreset = .high
      }
      if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
        session.addOutput(photoOutput)
      }
      if !session.outputs.contains(videoOutput), session.canAddOutput(videoOutput) {
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(videoOutput)
      }
      try device.lockForConfiguration()
      if let best = device.formats.max(by: { a, b in
        let x = CMVideoFormatDescriptionGetDimensions(a.formatDescription)
        let y = CMVideoFormatDescriptionGetDimensions(b.formatDescription)
        return Int(x.width) * Int(x.height) < Int(y.width) * Int(y.height)
      }) {
        device.activeFormat = best
        if let dims = best.supportedMaxPhotoDimensions.max(by: {
          Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
        }) {
          photoOutput.maxPhotoDimensions = dims
        }
      }
      device.unlockForConfiguration()
      session.commitConfiguration()
      configurationOpen = false
      session.startRunning()
      try device.lockForConfiguration()
      if let best = device.formats.max(by: { a, b in
        let x = CMVideoFormatDescriptionGetDimensions(a.formatDescription)
        let y = CMVideoFormatDescriptionGetDimensions(b.formatDescription)
        return Int(x.width) * Int(x.height) < Int(y.width) * Int(y.height)
      }) {
        device.activeFormat = best
        let fps = best.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 8
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(fps.rounded()))
        device.activeVideoMaxFrameDuration = device.activeVideoMinFrameDuration
      }
      device.unlockForConfiguration()
      let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
      DispatchQueue.main.async {
        self.connected = true
        self.resolution = "\(dims.width) × \(dims.height)"
        self.status = L10n.text("Ready to capture")
        self.quad = nil
      }
    } catch {
      if configurationOpen { session.commitConfiguration() }
      DispatchQueue.main.async {
        self.connected = false
        self.error = error.localizedDescription
      }
    }
  }
  func captureOutput(
    _ output: AVCaptureOutput, didOutput sample: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let buffer = CMSampleBufferGetImageBuffer(sample) else { return }
    latest = CIImage(cvPixelBuffer: buffer)
    let now = Date.timeIntervalSinceReferenceDate
    guard now - lastTick > 0.18, let image = latest else { return }
    lastTick = now
    let small = image.transformed(
      by: CGAffineTransform(scaleX: 64 / image.extent.width, y: 48 / image.extent.height))
    var bytes = [UInt8](repeating: 0, count: 64 * 48 * 4)
    context.render(
      small, toBitmap: &bytes, rowBytes: 64 * 4, bounds: CGRect(x: 0, y: 0, width: 64, height: 48),
      format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
    let moving = previous.map { CaptureCheck.motion(bytes, $0) } ?? true
    previous = bytes
    var detected: Quad? = PaperDetector.detect(image, context: context, book: self.book)
    let request = VNDetectRectanglesRequest()
    request.maximumObservations = 8
    request.minimumConfidence = 0.65
    request.minimumAspectRatio = 0.25
    request.maximumAspectRatio = 1
    request.minimumSize = 0.18
    request.quadratureTolerance = 35
    do {
      let reduced = image.transformed(
        by: CGAffineTransform(scaleX: 1000 / image.extent.width, y: 1000 / image.extent.width))
      try VNImageRequestHandler(ciImage: reduced, options: [:]).perform([request])
      if let r = request.results?.max(by: {
        $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
      }) {
        let area = r.boundingBox.width * r.boundingBox.height
        let maskArea = detected.map { abs(($0.tr.x - $0.tl.x) * ($0.tl.y - $0.bl.y)) } ?? 0
        if area >= maskArea * 0.85 {
          detected = Quad(tl: r.topLeft, tr: r.topRight, br: r.bottomRight, bl: r.bottomLeft)
        }
      }
    } catch {}
    func display(_ message: String) {
      DispatchQueue.main.async {
        if self.autoCrop { self.quad = detected }
        if self.autoCapture && !self.busy { self.status = message }
      }
    }
    guard autoEnabled, !captureInFlight else {
      display(L10n.text("Ready to capture"))
      return
    }
    if let held = heldFrame {
      if !CaptureCheck.motion(bytes, held) {
        display(heldReason)
        let warning = heldPreflightWarning
        DispatchQueue.main.async { self.updatePreflight(warning) }
        return
      }
      heldFrame = nil
      heldPreflightWarning = nil
      gate.reset()
    }
    if moving || detected == nil {
      DispatchQueue.main.async { self.duplicateWarning = false }
    }
    let warning =
      detected == nil && !moving ? L10n.text("Page edges not found · Place the page inside the view") : nil
    DispatchQueue.main.async { self.updatePreflight(warning) }
    guard
      gate.ready(
        at: now, moving: moving, blocked: false, duplicate: false, hasPage: detected != nil)
    else {
      display(
        detected == nil
          ? L10n.text("Looking for page edges…")
          : (moving ? L10n.text("Hold the page still…") : L10n.text("Checking the next page…")))
      return
    }
    do {
      let hands = try CaptureCheck.hasHands(image, context: context)
      guard !hands else {
        heldFrame = bytes
        heldPreflightWarning = L10n.text("Hand in view · Move your hands away")
        DispatchQueue.main.async { self.updatePreflight(L10n.text("Hand in view · Move your hands away")) }
        heldReason = L10n.text("Move your hands away…")
        gate.reset()
        display(heldReason)
        return
      }
      guard let print = CaptureCheck.fingerprint(image, context: context) else {
        gate.reset()
        display(L10n.text("Could not check the page · Try Capture"))
        return
      }
      if CaptureCheck.duplicate(print, of: recentPrints + recentPreviewPrints) {
        heldReason = L10n.text("Page already saved · Turn the page")
        gate.reset()
        display(heldReason)
        DispatchQueue.main.async { self.showDuplicate() }
        return
      }
    } catch {
      gate.reset()
      display(L10n.text("Could not check the page · Try Capture"))
      return
    }
    DispatchQueue.main.async { self.duplicateWarning = false }
    gate.captured(at: Date.timeIntervalSinceReferenceDate)
    captureInFlight = true
    DispatchQueue.main.async {
      if self.autoCrop { self.quad = detected }
      if self.autoCapture && !self.busy {
        self.capture(automatic: true)
      } else {
        self.queue.async {
          self.captureInFlight = false
          self.gate.reset()
        }
      }
    }
  }
  func seedRecentPages() {
    let base = folder
    var names: [String] = []
    for p in document.pages.reversed() where !names.contains(p.original) {
      names.append(p.original)
      if names.count == 4 { break }
    }
    queue.async {
      self.gate = AutoCaptureGate()
      self.previous = nil
      self.heldFrame = nil
      self.recentPreviewPrints = []
      self.capturePreviewPrint = nil
      self.recentPrints = names.compactMap { name in
        guard let image = CIImage(contentsOf: base.appendingPathComponent(name)) else { return nil }
        return CaptureCheck.fingerprint(image, context: self.context)
      }
    }
  }
}
