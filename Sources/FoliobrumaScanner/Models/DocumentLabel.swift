import AppKit
import CoreImage

struct DocumentLabel: Hashable {
  let title: String
  let subtitle: String
  let link: String
  static let size = NSSize(width: 62 * 72 / 25.4, height: 25 * 72 / 25.4)

  // A short HTTPS address keeps the code readable at this fixed label size.
  // No network request is made. New uploads use permanent SaaS label URLs.
  static func validURL(_ text: String) -> URL? {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let isPrivatePDF = value.range(of: #"^https://foliobruma\.com/api/organisations/[a-f0-9-]{36}/documents/[a-f0-9-]{36}$"#, options: .regularExpression) != nil
    let limit = isPrivatePDF ? 180 : 100
    guard value.utf8.count <= limit,
      !value.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) }),
      let parts = URLComponents(string: value), parts.scheme?.lowercased() == "https",
      let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
      let url = parts.url, url.absoluteString.utf8.count <= limit
    else { return nil }
    return url
  }

  static func validationMessage(_ text: String) -> String? {
    guard validURL(text) == nil else { return nil }
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.isEmpty { return "Enter a link to preview the label." }
    let parts = URLComponents(string: value)
    if value.utf8.count > 100 || (parts?.url?.absoluteString.utf8.count ?? 0) > 100 {
      return "This link is too long for the label. Use a shorter link."
    }
    if parts?.scheme?.lowercased() != "https" { return "Use a link that starts with https://." }
    return "Enter a complete link without spaces or sign-in details."
  }

  func qrImage() -> NSImage? {
    guard let url = Self.validURL(link),
      let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(Data(url.absoluteString.utf8), forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    guard let code = filter.outputImage else { return nil }
    // Core Image includes a narrow border. Add four full modules on every edge.
    let bounds = code.extent.insetBy(dx: -4, dy: -4)
    let white = CIImage(color: .white).cropped(to: bounds)
    let padded = code.composited(over: white).cropped(to: bounds)
    let scaled = padded.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
    guard let bitmap = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
    return NSImage(cgImage: bitmap, size: NSSize(width: bounds.width, height: bounds.height))
  }

  var permanentCode: String? {
    guard let url = Self.validURL(link), url.host == "foliobruma.com", url.path.hasPrefix("/d/") else { return nil }
    let code = String(url.path.dropFirst(3))
    return code.range(of: "^[A-Za-z0-9_-]{16}$", options: .regularExpression) != nil ? code : nil
  }

  var printedLink: String {
    guard let url = Self.validURL(link) else { return "" }
    return String(url.absoluteString.dropFirst("https://".count))
  }
}

// The preview, PDF, and print operation use exactly the same drawing.
final class DocumentLabelView: NSView {
  let label: DocumentLabel
  let qr: NSImage
  private(set) var completedPrintInfo: NSPrintInfo?
  private let printImage: NSImage?
  override var isFlipped: Bool { true }

  init(label: DocumentLabel, qr: NSImage) {
    self.label = label
    self.qr = qr
    if let bitmap = try? QL600Printer.bitmap(label), let cg = bitmap.cgImage {
      self.printImage = NSImage(cgImage: cg, size: NSSize(width: 696, height: 225))
    } else { self.printImage = nil }
    super.init(frame: NSRect(origin: .zero, size: DocumentLabel.size))
  }
  required init?(coder: NSCoder) { nil }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.white.setFill()
    bounds.fill()
    NSGraphicsContext.current?.imageInterpolation = .none
    let mm = 72.0 / 25.4
    printImage?.draw(in: NSRect(x: 1.5 * mm, y: 3 * mm, width: 59 * mm, height: 19 * mm),
      from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
  }

  static func labelPrintInfo() -> NSPrintInfo {
    let info = NSPrintInfo(dictionary: [:])
    if let name = NSPrinter.printerNames.first(where: { $0.localizedCaseInsensitiveContains("QL-600") }),
       let printer = NSPrinter(name: name) { info.printer = printer }
    info.paperSize = DocumentLabel.size
    info.topMargin = 0
    info.bottomMargin = 0
    info.leftMargin = 0
    info.rightMargin = 0
    info.horizontalPagination = .clip
    info.verticalPagination = .clip
    info.isHorizontallyCentered = true
    info.isVerticallyCentered = true
    info.scalingFactor = 1
    return info
  }

  @discardableResult
  func printLabel(info: NSPrintInfo? = nil, showPanel: Bool = true) -> Bool {
    let operation = NSPrintOperation(view: self, printInfo: info ?? Self.labelPrintInfo())
    operation.showsPrintPanel = showPanel
    operation.showsProgressPanel = true
    let submitted = operation.run()
    if submitted { completedPrintInfo = operation.printInfo.copy() as? NSPrintInfo }
    return submitted
  }
}
