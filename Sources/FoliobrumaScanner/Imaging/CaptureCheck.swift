import CoreImage
import ImageIO
import Vision

enum CaptureCheck {
  static func preferPreview(photo: CGSize, preview: CGSize) -> Bool {
    guard photo.width > 0, photo.height > 0, preview.width > 0, preview.height > 0 else { return false }
    return abs(photo.width / photo.height - preview.width / preview.height) > 0.02
      || preview.width * preview.height > photo.width * photo.height
  }
  static func reduced(_ image: CIImage) -> CIImage {
    image.transformed(
      by: CGAffineTransform(scaleX: 640 / image.extent.width, y: 640 / image.extent.width))
  }
  // Keep page detail. A general image feature print can match different text pages.
  struct Fingerprint {
    let pixels: [UInt8]
    let aspect: Double
  }
  // Compare the paper itself: a hand or a label on the desk is not a page turn.
  static func pageFingerprint(_ image: CIImage, context: CIContext, book: Bool) -> Fingerprint? {
    guard let q = PaperDetector.page(image, context: context, book: book) else { return nil }
    let paper = PaperDetector.crop(image, to: q)
    let content = paper.cropped(to: paper.extent.insetBy(
      dx: paper.extent.width * 0.04, dy: paper.extent.height * 0.04))
    return fingerprint(content, context: context, smooth: true)
  }
  static func fingerprint(_ image: CIImage, context: CIContext, smooth: Bool = false) -> Fingerprint? {
    let extent = image.extent
    guard extent.width > 0, extent.height > 0, !extent.isInfinite else { return nil }
    var frame = image.transformed(
      by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)
    ).transformed(by: CGAffineTransform(scaleX: 512 / extent.width, y: 512 / extent.height))
    // Suppress sensor noise at text edges without discarding local text detail.
    if smooth { frame = frame.clampedToExtent().applyingGaussianBlur(sigma: 0.65).cropped(to: frame.extent) }
    var pixels = [UInt8](repeating: 0, count: 512 * 512)
    context.render(
      frame, toBitmap: &pixels, rowBytes: 512,
      bounds: CGRect(x: 0, y: 0, width: 512, height: 512),
      format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
    return Fingerprint(pixels: pixels, aspect: Double(extent.width / extent.height))
  }
  private static let alignmentContext = CIContext(options: [.cacheIntermediates: false])
  static func pageDuplicate(_ print: Fingerprint, of recent: [Fingerprint]) -> Bool {
    if duplicate(print, of: recent, tileLimit: 64, exposureLimit: 96, aspectTolerance: 0.03, totalLimit: 5242) { return true }
    guard print.pixels.count == 512 * 512 else { return false }
    func image(_ value: Fingerprint) -> CIImage {
      CIImage(bitmapData: Data(value.pixels), bytesPerRow: 512, size: CGSize(width: 512, height: 512),
              format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
    }
    let floating = image(print)
    let region = CGRect(x: 20, y: 20, width: 472, height: 472)
    return recent.contains { other in
      guard other.pixels.count == print.pixels.count, abs(print.aspect - other.aspect) < 0.03 else { return false }
      let reference = image(other)
      guard let fixed = fingerprint(reference.cropped(to: region), context: alignmentContext, smooth: true) else { return false }
      let request = VNHomographicImageRegistrationRequest(targetedCIImage: floating, options: [:])
      do { try VNImageRequestHandler(ciImage: reference, options: [:]).perform([request]) }
      catch { return false }
      guard let matrix = request.results?.first?.warpTransform else { return false }
      let corners: [SIMD3<Float>] = [.init(0, 512, 1), .init(512, 512, 1), .init(512, 0, 1), .init(0, 0, 1)]
      var mapped: [CIVector] = []
      for corner in corners {
        let point = matrix * corner
        guard abs(point.z) > 0.001 else { return false }
        let x = point.x / point.z, y = point.y / point.z
        // Allow small crop/position changes, not a large warp between different pages.
        guard x.isFinite, y.isFinite, abs(x - corner.x) < 16, abs(y - corner.y) < 16 else { return false }
        mapped.append(CIVector(x: CGFloat(x), y: CGFloat(y)))
      }
      let aligned = floating.applyingFilter("CIPerspectiveTransform", parameters: [
        "inputTopLeft": mapped[0], "inputTopRight": mapped[1],
        "inputBottomRight": mapped[2], "inputBottomLeft": mapped[3]])
      guard let candidate = fingerprint(aligned.cropped(to: region), context: alignmentContext, smooth: true) else { return false }
      // Paper flex and interpolation can alter a local text edge. After bounded alignment,
      // at least 98% of paper pixels must still match within the noise tolerance.
      return duplicate(candidate, of: [fixed], tileLimit: 4096, exposureLimit: 96, totalLimit: 5242, tileSize: 64, localExposure: true)
    }
  }
  static func duplicate(_ print: Fingerprint, of recent: [Fingerprint], tileLimit: Int = 20,
                        exposureLimit: Double = 12, aspectTolerance: Double = 0.01,
                        totalLimit: Int = 262144, tileSize: Int = 32, localExposure: Bool = false) -> Bool {
    recent.contains { other in
      guard print.pixels.count == 512 * 512, other.pixels.count == print.pixels.count,
        abs(print.aspect - other.aspect) < aspectTolerance else { return false }
      // Allow a small uniform exposure change, but require detail to match in every tile.
      let offset = zip(print.pixels, other.pixels).reduce(0.0) {
        $0 + Double($1.0) - Double($1.1)
      } / Double(print.pixels.count)
      guard abs(offset) <= exposureLimit else { return false }
      var totalChanged = 0
      for by in stride(from: 0, to: 512, by: tileSize) {
        for bx in stride(from: 0, to: 512, by: tileSize) {
          var tileOffset = offset
          if localExposure {
            var sum = 0.0
            for y in by..<by + tileSize {
              for x in bx..<bx + tileSize {
                let i = y * 512 + x
                sum += Double(print.pixels[i]) - Double(other.pixels[i])
              }
            }
            tileOffset = sum / Double(tileSize * tileSize)
            guard abs(tileOffset - offset) <= 32 else { return false }
          }
          var changed = 0
          for y in by..<by + tileSize {
            for x in bx..<bx + tileSize {
              let i = y * 512 + x
              if abs(Double(print.pixels[i]) - Double(other.pixels[i]) - tileOffset) > 18 {
                changed += 1
              }
            }
          }
          totalChanged += changed
          if changed > tileLimit || totalChanged > totalLimit { return false }
        }
      }
      return true
    }
  }
  static func hasHands(_ image: CIImage, context: CIContext) throws -> Bool {
    let frame = reduced(image)
    // Overhead cameras see hands from every side; normalize orientation for the model.
    for orientation in [CGImagePropertyOrientation.up, .left, .right, .down] {
      let r = VNDetectHumanHandPoseRequest()
      r.maximumHandCount = 2
      try VNImageRequestHandler(ciImage: frame, orientation: orientation, options: [:]).perform([r])
      if !(r.results ?? []).isEmpty { return true }
    }
    // Inspect overlapping regions: clipped hands can be too small in the full view.
    for y in [0.0, 0.4] {
      let region = CGRect(
        x: image.extent.minX, y: image.extent.minY + image.extent.height * y,
        width: image.extent.width, height: image.extent.height * 0.6)
      let crop = image.cropped(to: region).transformed(
        by: CGAffineTransform(translationX: -region.minX, y: -region.minY))
      let check = VNDetectHumanHandPoseRequest()
      check.maximumHandCount = 2
      try VNImageRequestHandler(ciImage: reduced(crop), options: [:]).perform([check])
      if !(check.results ?? []).isEmpty { return true }
    }
    return false
  }
  static func motion(_ a: [UInt8], _ b: [UInt8]) -> Bool {
    guard a.count == b.count, a.count == 64 * 48 * 4 else { return true }
    // Check small regions, so an arm is not diluted by the unchanged background.
    for by in stride(from: 0, to: 48, by: 8) {
      for bx in stride(from: 0, to: 64, by: 8) {
        var total = 0.0
        for y in by..<by + 8 {
          for x in bx..<bx + 8 {
            let i = (y * 64 + x) * 4
            total += abs(Double(a[i]) - Double(b[i]))
          }
        }
        if total / 64 > 9 { return true }
      }
    }
    return false
  }
}
