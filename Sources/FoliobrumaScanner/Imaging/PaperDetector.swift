import ScannerCore
import CoreImage
import Vision

// Segmentation complements rectangle detection for ring binders and rounded pages.
enum PaperDetector {
  // Use the same edge selection on preview and full-resolution photos.
  static func page(_ image: CIImage, context: CIContext, book: Bool) -> Quad? {
    let mask = detect(image, context: context, book: book)
    let request = VNDetectRectanglesRequest()
    request.maximumObservations = 8
    request.minimumConfidence = 0.7
    request.minimumAspectRatio = 0.25
    request.maximumAspectRatio = 1
    request.minimumSize = 0.18
    request.quadratureTolerance = 25
    let reduced = image.transformed(by: CGAffineTransform(scaleX: 1000 / image.extent.width, y: 1000 / image.extent.width))
    try? VNImageRequestHandler(ciImage: reduced, options: [:]).perform([request])
    let rectangle = request.results?.max { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }
      .map { Quad(tl: $0.topLeft, tr: $0.topRight, br: $0.bottomRight, bl: $0.bottomLeft) }
    guard let mask else { return rectangle }
    guard let rectangle else { return mask }
    // Do not replace a paper mask with an inner text rectangle or an inward trapezoid.
    let tolerance: CGFloat = 0.01
    let covers = rectangle.bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(mask.bounds)
    return covers && rectangle.area >= mask.area * 0.97 ? rectangle : mask
  }

  static func crop(_ image: CIImage, to q: Quad) -> CIImage {
    func v(_ p: CGPoint) -> CIVector {
      CIVector(x: image.extent.minX + p.x * image.extent.width,
               y: image.extent.minY + p.y * image.extent.height)
    }
    return image.applyingFilter("CIPerspectiveCorrection", parameters: [
      "inputTopLeft": v(q.tl), "inputTopRight": v(q.tr),
      "inputBottomRight": v(q.br), "inputBottomLeft": v(q.bl)])
  }

  static func detect(_ image: CIImage, context: CIContext, book: Bool) -> Quad? {
    let w = 256
    let h = max(1, Int(256 * image.extent.height / image.extent.width))
    let small = image.transformed(
      by: CGAffineTransform(
        scaleX: Double(w) / image.extent.width, y: Double(h) / image.extent.height))
    var rgba = [UInt8](repeating: 0, count: w * h * 4)
    context.render(
      small, toBitmap: &rgba, rowBytes: w * 4, bounds: CGRect(x: 0, y: 0, width: w, height: h),
      format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
    var gray = [Int](repeating: 0, count: w * h)
    var hist = [Int](repeating: 0, count: 256)
    for i in 0..<w * h {
      gray[i] = (Int(rgba[i * 4]) * 3 + Int(rgba[i * 4 + 1]) * 6 + Int(rgba[i * 4 + 2])) / 10
      hist[gray[i]] += 1
    }
    let total = Double(w * h)
    let sum = hist.enumerated().reduce(0.0) { $0 + Double($1.offset * $1.element) }
    var sumB = 0.0
    var weight = 0.0
    var best = 0.0
    var threshold = 140
    for t in 0..<256 {
      weight += Double(hist[t])
      if weight == 0 { continue }
      let other = total - weight
      if other == 0 { break }
      sumB += Double(t * hist[t])
      let delta = sumB / weight - (sum - sumB) / other
      let score = weight * other * delta * delta
      if score > best {
        best = score
        threshold = t
      }
    }
    threshold = max(95, min(200, threshold))
    var seen = [Bool](repeating: false, count: w * h)
    var components: [(count: Int, box: CGRect)] = []
    for start in 0..<w * h where !seen[start] && gray[start] > threshold {
      var todo = [start]
      var head = 0
      var minX = w
      var maxX = 0
      var minY = h
      var maxY = 0
      seen[start] = true
      while head < todo.count {
        let p = todo[head]
        head += 1
        let x = p % w
        let y = p / w
        minX = min(minX, x)
        maxX = max(maxX, x)
        minY = min(minY, y)
        maxY = max(maxY, y)
        for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
        where nx >= 0 && nx < w && ny >= 0 && ny < h {
          let n = ny * w + nx
          if !seen[n] && gray[n] > threshold {
            seen[n] = true
            todo.append(n)
          }
        }
      }
      if Double(todo.count) > total * 0.035 {
        components.append(
          (todo.count, CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)))
      }
    }
    components.sort { $0.count > $1.count }
    guard let first = components.first else { return nil }
    var box = first.box
    if book, components.count > 1 {
      let b = components[1].box
      let overlap = max(0, min(box.maxY, b.maxY) - max(box.minY, b.minY))
      let gap = max(0, max(box.minX, b.minX) - min(box.maxX, b.maxX))
      if overlap > min(box.height, b.height) * 0.5 && gap < Double(w) * 0.15 { box = box.union(b) }
    }
    guard box.width > Double(w) * 0.2, box.height > Double(h) * 0.25,
      box.width * box.height < Double(w * h) * 0.98
    else { return nil }
    let l = max(0, (box.minX - 1) / Double(w))
    let r = min(1, (box.maxX + 1) / Double(w))
    let b = max(0, 1 - (box.maxY + 1) / Double(h))
    let t = min(1, 1 - (box.minY - 1) / Double(h))
    return Quad(
      tl: CGPoint(x: l, y: t), tr: CGPoint(x: r, y: t), br: CGPoint(x: r, y: b),
      bl: CGPoint(x: l, y: b))
  }
}
