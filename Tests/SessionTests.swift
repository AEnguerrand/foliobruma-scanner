import ScannerCore
import Foundation
import CoreImage
import AppKit
import PDFKit
import Vision

private final class USBTestSettingsWindow: NSWindow {
 var visibleForTest = true
 override var isVisible: Bool { visibleForTest }
}

@main struct SessionTests {
 static func readData(_ url: URL) -> Data { try! Data(contentsOf: url) }
 static func waitForWork(_ scanner: Scanner) {
  let deadline = Date().addingTimeInterval(10)
  while scanner.busy && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
  precondition(!scanner.busy, "Background operation timed out")
 }
 static func testUSBButton() throws {
  let suite = "foliobruma-usb-test-" + UUID().uuidString
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let button = USBButton(defaults: defaults)
  let press = USBButtonSignal(page: 65280, usage: 2, bytes: Data(0..<64))
  let release = USBButtonSignal(page: 65280, usage: 2, bytes: Data([0]))
  button.binding = USBButtonBinding(deviceID: "test", signal: press, action: .nextDocument, enabled: true)
  var actions: [USBButtonAction] = []
  let subscription = button.actions.sink { actions.append($0) }
  defer { subscription.cancel() }
  button.handle(release, at: 0)
  precondition(actions.isEmpty && button.receivedCount == 1)
  button.handle(press, at: 1)
  button.handle(press, at: 1.1)
  button.handle(press, at: 1.5)
  button.handle(press, at: 2)
  precondition(actions == [.nextDocument], "Held reports must not repeat actions")
  button.handle(press, at: 3)
  precondition(actions.count == 2)
  _ = NSApplication.shared
  let settings = USBTestSettingsWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
  button.settingsWindow = settings
  button.handle(press, at: 4)
  precondition(actions.count == 2 && button.testCount == 3, "Settings tests must not run actions")
  settings.visibleForTest = false
  button.handle(press, at: 5)
  precondition(actions.count == 3, "A retained but closed Settings window must not block the button")
  settings.visibleForTest = true
  button.handle(press, at: 6)
  precondition(actions.count == 3, "Reopened Settings must block actions again")
  button.settingsWindow = nil
  button.handle(press, at: 7)
  precondition(actions.count == 4, "A released Settings window must not block the button")
  button.binding.enabled = false
  button.handle(press, at: 8)
  precondition(actions.count == 4)
  let restored = USBButton(defaults: defaults)
  precondition(restored.binding.signal == press && restored.binding.action == .nextDocument)
  precondition(!restored.binding.enabled)
  restored.select("another-device")
  precondition(restored.binding.signal == nil && !restored.binding.enabled)
  restored.handle(press, at: 1)
  precondition(restored.receivedCount == 1 && restored.testCount == 0, "Unlearned input must be visible without running an action")

  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let scanner = Scanner(storageRoot: root)
  let originalFolder = scanner.folder
  scanner.performUSBAction(.nextDocument)
  precondition(scanner.folder == originalFolder, "Do not create repeated empty documents")
  scanner.busy = true
  scanner.performUSBAction(.newItem)
  precondition(!scanner.showNewItem)
  scanner.busy = false
  scanner.showExport = true
  scanner.performUSBAction(.newItem)
  precondition(!scanner.showNewItem)
  scanner.showExport = false
  scanner.performUSBAction(.autoCapture)
  precondition(!scanner.autoCapture, "Disconnected camera must not start auto capture")
  scanner.connected = true
  scanner.performUSBAction(.autoCapture)
  precondition(scanner.autoCapture)
  scanner.performUSBAction(.autoCapture)
  precondition(!scanner.autoCapture)
  scanner.reviewing = true
  scanner.performUSBAction(.capture)
  precondition(!scanner.busy)
  scanner.performUSBAction(.autoCapture)
  precondition(!scanner.autoCapture)
  scanner.reviewing = false
  try scanner.commit(ScanDocument(pages: [ScanPage(file: "Pages/test.jpg", original: "Originals/test.jpg")]))
  scanner.performUSBAction(.nextDocument)
  precondition(scanner.folder != originalFolder && scanner.document.pages.isEmpty)
  let old = try JSONDecoder().decode(ScanDocument.self,
    from: Data(contentsOf: originalFolder.appendingPathComponent("session.json")))
  precondition(old.pages.count == 1, "Next document must keep the saved session")
  scanner.performUSBAction(.newItem)
  precondition(scanner.showNewItem)
  print("PASS: USB report matching, repeat suppression, disabled and test modes, preferences, action guards, next document preservation")
 }
 static func testLocalization() throws {
  let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources")
  func table(_ language: String, _ name: String = "Localizable") throws -> [String: String] {
    let data = try Data(contentsOf: resources.appendingPathComponent("\(language).lproj/\(name).strings"))
    return try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: String]
  }
  let english = try table("en")
  let french = try table("fr")
  precondition(Set(english.keys) == Set(french.keys), "Both languages need the same keys")
  let placeholders = try NSRegularExpression(pattern: "%(?:ld|@|%)")
  func tokens(_ value: String) -> [String] {
    placeholders.matches(in: value, range: NSRange(value.startIndex..., in: value)).map {
      String(value[Range($0.range, in: value)!])
    }.sorted()
  }
  for (key, value) in english {
    precondition(!french[key]!.isEmpty, "A translation must not be empty")
    precondition(tokens(value) == tokens(french[key]!), "Format mismatch: \(key)")
  }
  let en = Bundle(url: resources.appendingPathComponent("en.lproj"))!
  let fr = Bundle(url: resources.appendingPathComponent("fr.lproj"))!
  precondition(L10n.text("Capture page", bundle: en) == "Capture page")
  precondition(L10n.text("Capture page", bundle: fr) == "Capturer la page")
  precondition(L10n.text("Unknown legacy reason", bundle: fr) == "Unknown legacy reason")
  precondition(L10n.text("Too dark · Add light and rescan", bundle: fr).hasPrefix("Image trop sombre"))
  let progress = String(format: L10n.text("Page %ld of %ld", bundle: fr), 2, 12)
  precondition(progress == "Page 2 sur 12")
  let percent = String(format: L10n.text("Spine position · %ld%%", bundle: fr), 50)
  precondition(percent == "Position de la reliure · 50 %")
  for language in ["en", "fr"] {
    let permission = try table(language, "InfoPlist")
    precondition(permission["NSCameraUsageDescription"]?.isEmpty == false)
  }
  precondition(Bundle.preferredLocalizations(from: ["en", "fr"], forPreferences: ["fr-CA", "en"]).first == "fr")
  precondition(Bundle.preferredLocalizations(from: ["en", "fr"], forPreferences: ["de"]).first == "en")
  let suite = "foliobruma-localization-test-" + UUID().uuidString
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  for language in ["fr", "en"] {
    L10n.setLanguage(language, defaults: defaults)
    precondition(defaults.string(forKey: "appLanguage") == language)
    precondition(defaults.stringArray(forKey: "AppleLanguages") == [language])
  }
  L10n.setLanguage("system", defaults: defaults)
  precondition(defaults.persistentDomain(forName: suite)?["AppleLanguages"] == nil)
  L10n.setLanguage("unsupported", defaults: defaults)
  precondition(defaults.string(forKey: "appLanguage") == "system")
  let saved = Data(#"{"title":"Mon livre","pages":[]}"#.utf8)
  let decoded = try JSONDecoder().decode(ScanDocument.self, from: saved)
  precondition(decoded.title == "Mon livre")
  print("PASS: English and French resources; formats; fallback; language preference; saved names")
 }
 static func testDuplicateDetail() {
  precondition(CaptureCheck.preferPreview(photo: CGSize(width: 1920, height: 1080), preview: CGSize(width: 4160, height: 3120)), "Do not crop a 4:3 camera view into a 16:9 still")
  precondition(!CaptureCheck.preferPreview(photo: CGSize(width: 4160, height: 3120), preview: CGSize(width: 1920, height: 1440)), "Keep a higher resolution photo when framing agrees")
  let context = CIContext(options: [.cacheIntermediates: false])
  let bounds = CGRect(x: 0, y: 0, width: 1024, height: 1024)
  let paper = CIImage(color: CIColor(red: 0.9, green: 0.9, blue: 0.9)).cropped(to: bounds)
  func page(_ variant: Int) -> CIImage {
    var image = paper
    // Two columns with the same layout, but different word lengths on the right.
    for column in 0..<2 {
      for row in 0..<30 {
        for word in 0..<5 {
          let width = 30 + ((row * 7 + word * 11 + (column == 1 ? variant * 17 : 0)) % 35)
          let rect = CGRect(x: 60 + column * 490 + word * 80, y: 80 + row * 28,
                            width: width, height: 7)
          image = CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.1))
            .cropped(to: rect).composited(over: image)
        }
      }
    }
    return image
  }
  let first = page(0)
  let saved = CaptureCheck.fingerprint(first, context: context)!
  precondition(CaptureCheck.duplicate(saved, of: [saved]), "An unchanged page must match")
  let next = CaptureCheck.fingerprint(page(1), context: context)!
  precondition(!CaptureCheck.pageDuplicate(next, of: [saved]), "Paper matching must preserve changed text in a spread")
  precondition(!CaptureCheck.duplicate(next, of: [saved]),
               "Different text in one side of a spread must not be a duplicate")
  let smaller = first.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
  precondition(CaptureCheck.duplicate(CaptureCheck.fingerprint(smaller, context: context)!, of: [saved]),
               "Preview and photo sizes must match when their detail is unchanged")
  let translated = first.transformed(by: CGAffineTransform(translationX: 40, y: 60))
  precondition(CaptureCheck.duplicate(CaptureCheck.fingerprint(translated, context: context)!, of: [saved]),
               "Image extent origins must not change a fingerprint")
  let noisy = CaptureCheck.Fingerprint(pixels: saved.pixels.enumerated().map {
    UInt8(clamping: Int($0.element) + 6 + ($0.offset % 3) - 1)
  }, aspect: saved.aspect)
  precondition(CaptureCheck.duplicate(noisy, of: [saved]), "Small exposure changes and noise must pass")
  let blank = CaptureCheck.fingerprint(paper, context: context)!
  precondition(!CaptureCheck.duplicate(blank, of: [saved]), "Blank paper must differ from text")
  precondition(!CaptureCheck.duplicate(saved, of: []), "An empty history must not block capture")
  precondition(CaptureCheck.duplicate(saved, of: [next, blank, saved]), "Check all recent captures")
  let brighter = CaptureCheck.Fingerprint(pixels: saved.pixels.map { UInt8(clamping: Int($0) + 24) }, aspect: saved.aspect)
  precondition(CaptureCheck.pageDuplicate(brighter, of: [saved]), "Lighting alone must not count as a page turn")
  let desk = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))
  let onDesk = first.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.75))
    .transformed(by: CGAffineTransform(translationX: 600, y: 140)).composited(over: desk)
  let backgroundChange = CIImage(color: CIColor(red: 0.6, green: 0.3, blue: 0.2))
    .cropped(to: CGRect(x: 1400, y: 200, width: 450, height: 600)).composited(over: onDesk)
  let paperPrint = CaptureCheck.pageFingerprint(onDesk, context: context, book: false)!
  let changedDeskPrint = CaptureCheck.pageFingerprint(backgroundChange, context: context, book: false)!
  precondition(CaptureCheck.pageDuplicate(changedDeskPrint, of: [paperPrint]), "Background movement must not count as a page turn")
  let changedText = page(1).transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.75))
    .transformed(by: CGAffineTransform(translationX: 600, y: 140)).composited(over: desk)
  precondition(!CaptureCheck.pageDuplicate(CaptureCheck.pageFingerprint(changedText, context: context, book: false)!, of: [paperPrint]), "Smoothed paper matching must keep changed text distinct")
  var noisyPixels = [UInt8](repeating: 0, count: 1024 * 1024)
  context.render(first, toBitmap: &noisyPixels, rowBytes: 1024, bounds: bounds,
                 format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
  let cleanImage = CIImage(bitmapData: Data(noisyPixels), bytesPerRow: 1024, size: bounds.size,
                          format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
  let smoothSaved = CaptureCheck.fingerprint(cleanImage, context: context, smooth: true)!
  let shadedPixels = noisyPixels.enumerated().map { UInt8(clamping: Int($0.element) - 10 - ($0.offset / 1024) / 32) }
  let shadedImage = CIImage(bitmapData: Data(shadedPixels), bytesPerRow: 1024, size: bounds.size,
                           format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
  precondition(CaptureCheck.pageDuplicate(CaptureCheck.fingerprint(shadedImage, context: context, smooth: true)!, of: [smoothSaved]), "Uneven light on unchanged paper must not create a duplicate")

  for i in noisyPixels.indices { noisyPixels[i] = UInt8(clamping: Int(noisyPixels[i]) + (i * 17 % 41) - 20) }
  let noisyImage = CIImage(bitmapData: Data(noisyPixels), bytesPerRow: 1024, size: bounds.size,
                          format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
  precondition(CaptureCheck.pageDuplicate(CaptureCheck.fingerprint(noisyImage, context: context, smooth: true)!, of: [smoothSaved]), "Sensor noise must not create a second paper capture")
  let shifted = first.transformed(by: CGAffineTransform(a: 1.006, b: 0.002, c: -0.003, d: 0.997, tx: 3, ty: -2))
    .composited(over: paper).cropped(to: bounds)
  precondition(CaptureCheck.pageDuplicate(CaptureCheck.fingerprint(shifted, context: context, smooth: true)!,
    of: [CaptureCheck.fingerprint(first, context: context, smooth: true)!]), "Small page alignment changes must not create duplicates")
  let q = PaperDetector.page(onDesk, context: context, book: false)!.padded()
  precondition(q.bounds.contains(CGRect(x: 600.0/1920, y: 140.0/1080, width: 512.0/1920, height: 768.0/1080)), "Auto crop must keep the outer paper edges")
  let tallFrame = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1440))
  let tallPhoto = first.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.75))
    .transformed(by: CGAffineTransform(translationX: 600, y: 320)).composited(over: tallFrame)
  let photoQuad = PaperDetector.page(tallPhoto, context: context, book: false)!.padded()
  precondition(photoQuad.bounds.contains(CGRect(x: 600.0/1920, y: 320.0/1440, width: 512.0/1920, height: 768.0/1440)), "Photo framing needs its own crop coordinates")
  print("PASS: duplicate image detail; changed text in a spread; preview size; exposure and noise")
 }
 static func testPageMerge() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("merge-test-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let scanner = Scanner(storageRoot: root)
  let context = CIContext()
  let bounds = CGRect(x: 0, y: 0, width: 80, height: 40)
  let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: bounds)
  let green = CIImage(color: CIColor(red: 0, green: 1, blue: 0))
    .cropped(to: CGRect(x: 40, y: 0, width: 40, height: 40)).composited(over: red)
  let blue = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: bounds)
  var pages: [ScanPage] = []
  for (i, image) in [green, blue, red].enumerated() {
   let file = "Pages/test-\(i).png"
   let original = "Originals/test-\(i).png"
   let data = context.pngRepresentation(of: image, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())!
   try data.write(to: scanner.folder.appendingPathComponent(file))
   try data.write(to: scanner.folder.appendingPathComponent(original))
   pages.append(ScanPage(file: file, original: original, rotation: i == 0 ? 90 : 0))
  }
  var document = ScanDocument(); document.pages = pages
  try scanner.commit(document)
  let sourceBytes = pages.map { readData(scanner.folder.appendingPathComponent($0.file)) }
  scanner.beginReview(pages[2].id)
  precondition(!scanner.canMergeWithNextPage)
  scanner.mergeWithNextPage()
  precondition(scanner.document.pages.count == 3)
  scanner.beginReview(pages[0].id)
  scanner.busy = true
  scanner.mergeWithNextPage()
  precondition(scanner.document.pages.count == 3)
  scanner.busy = false
  scanner.pdfIsCurrent = true
  scanner.mergeWithNextPage(); waitForWork(scanner)
  precondition(scanner.error == nil)
  precondition(scanner.document.pages.count == 2 && scanner.document.pages[1].id == pages[2].id)
  let merged = scanner.document.pages[0]
  precondition(scanner.selected == merged.id && merged.rotation == 0 && !scanner.pdfIsCurrent)
  precondition(merged.mergedSources?.map(\.id) == Array(pages.prefix(2)).map(\.id))
  let output = CIImage(contentsOf: scanner.folder.appendingPathComponent(merged.file))!
  precondition(output.extent.width == 200 && output.extent.height == 80)
  func pixel(_ x: Int, _ y: Int) -> [UInt8] {
   var result = [UInt8](repeating: 0, count: 4)
   context.render(output, toBitmap: &result, rowBytes: 4,
     bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .RGBA8,
     colorSpace: CGColorSpaceCreateDeviceRGB())
   return result
  }
  precondition(pixel(10, 60)[0] > 240, "Clockwise rotation must put red at the top")
  precondition(pixel(10, 20)[1] > 240, "Clockwise rotation must put green at the bottom")
  precondition(pixel(100, 40)[2] > 240, "The second page must be on the right")
  for (i, page) in pages.enumerated() {
   precondition(readData(scanner.folder.appendingPathComponent(page.file)) == sourceBytes[i])
   precondition(readData(scanner.folder.appendingPathComponent(page.original)) == sourceBytes[i])
  }
  try scanner.restore()
  precondition(scanner.document.pages[0].mergedSources?.count == 2)
  let pdfURL = root.appendingPathComponent("merged.pdf")
  scanner.writePDF(to: pdfURL); waitForWork(scanner)
  let pdf = PDFDocument(url: pdfURL)!
  precondition(pdf.pageCount == 2)
  let pdfBounds = pdf.page(at: 0)!.bounds(for: .mediaBox)
  precondition(abs(pdfBounds.width / pdfBounds.height - 2.5) < 0.01)
  scanner.cropSelectedPage(to: CGRect(x: 0, y: 0, width: 0.5, height: 1))
  waitForWork(scanner)
  precondition(scanner.error == nil && scanner.document.pages[0].original == merged.file)
  let crop = CIImage(contentsOf: scanner.folder.appendingPathComponent(scanner.document.pages[0].file))!
  precondition(crop.extent.width == 100 && crop.extent.height == 80)

  // An image failure must leave both the saved manifest and the document unchanged.
  try scanner.commit(document)
  scanner.beginReview(pages[0].id)
  let manifestURL = scanner.folder.appendingPathComponent("session.json")
  let manifest = readData(manifestURL)
  try FileManager.default.removeItem(at: scanner.folder.appendingPathComponent(pages[1].file))
  scanner.mergeWithNextPage(); waitForWork(scanner)
  precondition(scanner.error != nil && scanner.document.pages.map(\.id) == pages.map(\.id))
  precondition(readData(manifestURL) == manifest)
  try sourceBytes[1].write(to: scanner.folder.appendingPathComponent(pages[1].file))

  // Fail the manifest write after the merged image has been written.
  try FileManager.default.removeItem(at: manifestURL)
  try FileManager.default.createDirectory(at: manifestURL, withIntermediateDirectories: false)
  scanner.mergeWithNextPage(); waitForWork(scanner)
  precondition(scanner.error != nil && scanner.document.pages.map(\.id) == pages.map(\.id))
  precondition(scanner.selected == pages[0].id)
  print("PASS: page merge order, rotation, pixels, source preservation, reload, PDF, crop, and failed-write recovery")
 }
 static func testCatalogAndLabels() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("catalog-test-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let scanner = Scanner(storageRoot: root)
  let legacy = try JSONDecoder().decode(ScanDocument.self, from: Data(#"{"title":"Old book","pages":[]}"#.utf8))
  precondition(legacy.metadata == nil && legacy.displayTitle == "Old book")
  let batch = ItemMetadata(batchID: UUID().uuidString, batchName: "Family letters", kind: "Letter",
    author: "Synthetic sender", period: "1932", location: "Box 3", tags: "Family", notes: "Test only",
    webLink: "https://foliobruma.com/d/test")
  scanner.book = true; scanner.split = true
  try scanner.createItem(title: "", metadata: batch, scanPages: false)
  precondition(scanner.document.displayTitle == "LET-0001")
  precondition(scanner.document.pages.isEmpty && scanner.sessionSaved && scanner.metadataWorkspace)
  precondition(!scanner.connected && !scanner.book && !scanner.split)
  let firstFolder = scanner.folder
  let pages = [ScanPage(file: "Pages/one.jpg", original: "Originals/one.jpg"),
               ScanPage(file: "Pages/two.jpg", original: "Originals/two.jpg")]
  try scanner.applyCapture(pages, replacing: nil, resolving: nil)
  precondition(scanner.document.metadata?.reference == "LET-0001" && scanner.document.pages.count == 2,
    "Additional pages must stay in the same letter")
  let firstBytes = readData(firstFolder.appendingPathComponent("session.json"))
  scanner.autoCapture = true
  scanner.nextLetter()
  precondition(scanner.error == nil && !scanner.autoCapture && scanner.metadataWorkspace)
  precondition(scanner.document.metadata?.reference == "LET-0002" && scanner.document.pages.isEmpty)
  let next = scanner.document.metadata!
  precondition(next.batchID == batch.batchID && next.batchName == batch.batchName)
  precondition(next.location == batch.location && next.tags == batch.tags)
  precondition(next.author.isEmpty && next.period.isEmpty && next.notes.isEmpty && next.webLink.isEmpty)
  let savedFirst = try JSONDecoder().decode(ScanDocument.self, from: readData(firstFolder.appendingPathComponent("session.json")))
  let originalFirst = try JSONDecoder().decode(ScanDocument.self, from: firstBytes)
  precondition(savedFirst.metadata == originalFirst.metadata && savedFirst.pages.map(\.id) == pages.map(\.id))
  let secondFolder = scanner.folder
  var edited = next
  edited.reference = "DO-NOT-CHANGE"; edited.batchID = "DO-NOT-CHANGE"
  edited.location = "Box 4"
  scanner.pdfIsCurrent = true
  try scanner.saveMetadata(title: "A title", metadata: edited)
  precondition(scanner.document.metadata?.reference == "LET-0002")
  precondition(scanner.document.metadata?.batchID == batch.batchID && scanner.pdfIsCurrent)
  try scanner.restore()
  precondition(scanner.document.title == "A title" && scanner.document.metadata?.location == "Box 4")
  scanner.busy = true; scanner.nextLetter(); scanner.busy = false
  precondition(scanner.folder == secondFolder)
  scanner.showCamera(); scanner.nextLetter()
  precondition(!scanner.metadataWorkspace && !scanner.reviewing && !scanner.autoCapture)
  precondition(scanner.document.metadata?.reference == "LET-0003")
  scanner.openSession(at: firstFolder)
  scanner.nextLetter()
  precondition(scanner.document.metadata?.reference == "LET-0004", "Reopening an older letter must not reuse a reference")
  scanner.browseSessions()
  let deadline = Date().addingTimeInterval(5)
  while scanner.loadingSessions && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
  precondition(scanner.sessions.contains { $0.reference == "LET-0002" && $0.batchName == batch.batchName })
  scanner.showSessions = false
  let lastFolder = scanner.folder
  let manifest = readData(lastFolder.appendingPathComponent("session.json"))
  let blocker = root.appendingPathComponent("blocker")
  try Data("blocked".utf8).write(to: blocker)
  scanner.root = blocker
  scanner.nextLetter()
  precondition(scanner.error != nil && scanner.folder == lastFolder)
  precondition(readData(lastFolder.appendingPathComponent("session.json")) == manifest)
  scanner.root = root; scanner.error = nil
  scanner.folder = blocker
  do { try scanner.createItem(title: "", metadata: batch, scanPages: false); preconditionFailure("Expected failed save") }
  catch { precondition(scanner.document.metadata?.reference == "LET-0004") }
  scanner.folder = lastFolder
  scanner.nextLetter()
  precondition(scanner.document.metadata?.reference == "LET-0006", "Failed writes can leave gaps")
  try FileManager.default.removeItem(at: root.appendingPathComponent("item-reference.json"))
  scanner.nextLetter()
  precondition(scanner.document.metadata?.reference == "LET-0007", "Recover counter from saved sessions")
  try Data("invalid".utf8).write(to: root.appendingPathComponent("item-reference.json"))
  scanner.nextLetter()
  precondition(scanner.error != nil && scanner.document.metadata?.reference == "LET-0007",
    "A broken counter must stop creation instead of reusing a reference")

  for bad in ["", "http://foliobruma.com/d/test", "javascript:alert(1)", "file:///tmp/a", "https://",
              "https://user:secret@foliobruma.com/d/test", "https://foliobruma.com/a b",
              "https://foliobruma.com/" + String(repeating: "a", count: 100)] {
    precondition(DocumentLabel.validURL(bad) == nil)
  }
  let link = "https://foliobruma.com/d/7K2M9"
  let label = DocumentLabel(title: "Family letters", subtitle: "LET-0042", link: link)
  let qr = label.qrImage()!
  var qrRect = CGRect(origin: .zero, size: qr.size)
  let image = qr.cgImage(forProposedRect: &qrRect, context: nil, hints: nil)!
  let request = VNDetectBarcodesRequest()
  request.symbologies = [.qr]
  try VNImageRequestHandler(cgImage: image).perform([request])
  precondition(request.results?.first?.payloadStringValue == link, "Generated QR must decode to the exact URL")
  let view = DocumentLabelView(label: label, qr: label.qrImage()!)
  let data = view.dataWithPDF(inside: view.bounds)
  let pdf = PDFDocument(data: data)!
  precondition(pdf.pageCount == 1)
  let page = pdf.page(at: 0)!
  let bounds = page.bounds(for: .mediaBox)
  precondition(abs(bounds.width - DocumentLabel.size.width) < 0.1 && abs(bounds.height - DocumentLabel.size.height) < 0.1)
  // Read the QR from the whole exported page at the printer's standard resolution.
  let preview = page.thumbnail(of: NSSize(width: bounds.width * 300 / 72, height: bounds.height * 300 / 72), for: .mediaBox)
  var previewRect = CGRect(origin: .zero, size: preview.size)
  let rendered = preview.cgImage(forProposedRect: &previewRect, context: nil, hints: nil)!
  let printed = VNDetectBarcodesRequest(); printed.symbologies = [.qr]
  try VNImageRequestHandler(cgImage: rendered).perform([printed])
  precondition(printed.results?.first?.payloadStringValue == link, "QR must survive the PDF layout")
  print("PASS: metadata-only records; batch inheritance; multi-page letters; reference recovery; failed writes; HTTPS validation; QR decoding; 62 x 25 mm PDF")
 }
 static func testReviewNavigation() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let scanner = Scanner(storageRoot: root)
  let pages = (1...3).map { ScanPage(file: "Pages/\($0).jpg", original: "Originals/\($0).jpg") }
  try scanner.commit(ScanDocument(pages: pages))
  scanner.beginReview(pages[1].id)
  for invalid in ["", "word", "1.5", "0", "-1", "4", String(Int.min), String(Int.max)] {
    precondition(scanner.pageIndex(for: invalid) == nil)
    scanner.goToPage(invalid)
    precondition(scanner.selected == pages[1].id, "Invalid input must keep the current page")
  }
  scanner.goToPage(" 3 ")
  precondition(scanner.selected == pages[2].id)
  scanner.busy = true
  scanner.goToPage("1")
  precondition(scanner.selected == pages[2].id, "Do not change pages during a save")
  scanner.busy = false
  scanner.remove(pages[2])
  precondition(scanner.selected == pages[1].id, "Removing the last page selects the preceding page")
  scanner.undo()
  precondition(scanner.selected == pages[2].id && scanner.document.pages.map(\.id) == pages.map(\.id))
  scanner.beginReview(pages[1].id)
  scanner.remove(pages[1])
  precondition(scanner.selected == pages[2].id, "Removing the current page selects its successor")
  scanner.undo()
  precondition(scanner.selected == pages[1].id)
  scanner.remove(pages[0])
  precondition(scanner.selected == pages[1].id, "Removing a different page preserves the selection")
  scanner.undo()
  let savedFolder = scanner.folder
  let blocker = root.appendingPathComponent("blocked")
  try Data().write(to: blocker)
  scanner.folder = blocker
  let selected = scanner.selected
  scanner.remove(pages[0])
  precondition(scanner.selected == selected && scanner.document.pages.count == 3,
    "A failed save must not change the selection or pages")
  scanner.folder = savedFolder
  scanner.beginReview(pages[0].id)
  for page in pages { scanner.remove(page) }
  precondition(scanner.selected == nil && scanner.document.pages.isEmpty)
  scanner.goToPage("1")
  precondition(scanner.selected == nil)
  scanner.undo()
  precondition(scanner.selected == pages[2].id && scanner.document.pages.count == 1)
  precondition(DocumentLabel.validationMessage("https://example.com") == nil)
  precondition(DocumentLabel.validationMessage("http://example.com") == "Use a link that starts with https://.")
  precondition(DocumentLabel.validationMessage("") == "Enter a link to preview the label.")
  precondition(DocumentLabel.validationMessage("https://example.com/" + String(repeating: "a", count: 100))
    == "This link is too long for the label. Use a shorter link.")
  precondition(DocumentLabel.validationMessage("https://user:password@example.com")
    == "Enter a complete link without spaces or sign-in details.")
  print("PASS: page input boundaries; adjacent selection; undo selection; failed-save selection; label validation feedback")
 }
 static func testSharedGeometryCompatibility() throws {
  // The old Mac model used synthesized CoreGraphics Codable conformance.
  struct LegacyQuad: Codable { var tl: CGPoint; var tr: CGPoint; var br: CGPoint; var bl: CGPoint }
  let legacy = LegacyQuad(tl: CGPoint(x: 0.1, y: 0.9), tr: CGPoint(x: 0.8, y: 0.85),
                          br: CGPoint(x: 0.9, y: 0.1), bl: CGPoint(x: 0.2, y: 0.05))
  let data = try JSONEncoder().encode(legacy)
  let shared = try JSONDecoder().decode(Quad.self, from: data)
  let encoded = try JSONEncoder().encode(shared)
  let originalJSON = try JSONSerialization.jsonObject(with: data) as! NSDictionary
  let sharedJSON = try JSONSerialization.jsonObject(with: encoded) as! NSDictionary
  precondition(originalJSON == sharedJSON, "Shared coordinates must preserve the Mac session format")
  let restored = try JSONDecoder().decode(LegacyQuad.self, from: encoded)
  precondition(restored.tl == legacy.tl && restored.tr == legacy.tr
    && restored.br == legacy.br && restored.bl == legacy.bl)
  precondition(shared.bounds == CGRect(x: 0.1, y: 0.05, width: 0.8, height: 0.85))
  precondition(ScanDocument().title == L10n.text("Untitled document"))
  let sharedError: Error = CloudFailure(message: "The page to replace is no longer available.")
  precondition(sharedError.localizedDescription == L10n.text("The page to replace is no longer available."),
    "Shared failures must retain the Mac localization adapter")
  print("PASS: shared geometry reads and writes the original Mac coordinate format; localized title")
 }
 static func main() throws {
  try testSharedGeometryCompatibility()
  try testSheetBatches()
  try testSheetGroups()
  try testSheetLabelRetry()
  try testQL600Labels()
  try PermanentLabelTests.run()
  try CloudUploadTests.run()
  try testReviewNavigation()
  try testCatalogAndLabels()
  try testPageMerge()
  testDuplicateDetail()
  try testLocalization()
  try testUSBButton()
  let root=FileManager.default.temporaryDirectory.appendingPathComponent("sovenelia-test-"+UUID().uuidString)
  defer {try? FileManager.default.removeItem(at:root)}
  let scanner=Scanner(storageRoot:root)
  precondition(scanner.error == nil)
  let pages=(1...3).map{ScanPage(file:"Pages/\($0).jpg",original:"Originals/\($0).jpg")}
  var doc=ScanDocument();doc.pages=pages;try scanner.commit(doc)
  scanner.remove(pages[1]);precondition(scanner.document.pages.map(\.id)==[pages[0].id,pages[2].id])
  scanner.undo();precondition(scanner.document.pages.map(\.id)==pages.map(\.id),"Undo must restore original order")
  scanner.rotate(pages[0]);precondition(scanner.document.pages[0].rotation==90)
  try scanner.restore();precondition(scanner.document.pages[0].rotation==90,"Rotation must survive reload")
  let goodFolder=scanner.folder
  let manifest=try Data(contentsOf:goodFolder.appendingPathComponent("session.json"))
  let blocker=root.appendingPathComponent("not-a-folder")
  try Data("blocked".utf8).write(to:blocker)
  scanner.folder=blocker
  let before=scanner.document
  scanner.remove(pages[1]);precondition(scanner.document.pages.map(\.id)==before.pages.map(\.id))
  scanner.rotate(scanner.document.pages[0]);precondition(scanner.document.pages[0].rotation==before.pages[0].rotation)
  scanner.folder=goodFolder
  let after=try Data(contentsOf:goodFolder.appendingPathComponent("session.json"));precondition(after==manifest)
  scanner.error=nil
  scanner.remove(pages[0]);scanner.newDocument()
  precondition(scanner.deleting==nil,"Undo must not leak between documents")
  precondition(scanner.document.pages.isEmpty)
  precondition(FileManager.default.fileExists(atPath:goodFolder.appendingPathComponent("session.json").path))
  let second=scanner.folder
  scanner.root=blocker;scanner.newDocument()
  precondition(scanner.folder==second,"A failed new document must preserve the active folder")
  let black=CIImage(color:CIColor(red:0,green:0,blue:0)).cropped(to:CGRect(x:0,y:0,width:640,height:480))
  precondition(PaperDetector.detect(black,context:scanner.context,book:true)==nil)
  let sheet=CIImage(color:CIColor(red:1,green:1,blue:1)).cropped(to:CGRect(x:80,y:260,width:220,height:160)).composited(over:black)
  let corners=PaperDetector.detect(sheet,context:scanner.context,book:false)!
  precondition(abs(corners.tl.y-420.0/480)<0.02,"Detector must convert bitmap rows to bottom-left image coordinates")
  precondition(abs(corners.bl.y-260.0/480)<0.02,"Crop must preserve the sheet bottom edge")
  let brown=CIImage(color:CIColor(red:0.65,green:0.45,blue:0.42)).cropped(to:CGRect(x:0,y:0,width:640,height:480))
  let brownHasHands=try CaptureCheck.hasHands(brown,context:scanner.context)
  precondition(!brownHasHands,"Brown material alone must not be classified as a hand")
  var preflight=PreflightFeedbackGate()
  precondition(!preflight.observe("Hand",at:0))
  precondition(!preflight.observe("Hand",at:1),"Brief page-turn movement must not beep")
  precondition(preflight.observe("Hand",at:1.6),"Persistent obstruction must warn")
  precondition(!preflight.observe("Hand",at:8),"Persistent obstruction must not repeat its tone")
  precondition(!preflight.observe(nil,at:9))
  precondition(!preflight.observe("Hand",at:10))
  precondition(preflight.observe("Hand",at:12),"A later obstruction can warn again")
  var duplicateFeedback=DuplicateFeedbackGate()
  precondition(duplicateFeedback.notify(),"First duplicate must give feedback")
  for _ in 0..<20 {precondition(!duplicateFeedback.notify(),"Same duplicate must not repeat its tone")}
  duplicateFeedback.reset()
  precondition(duplicateFeedback.notify(),"A new saved page must allow the next duplicate alert")
  var gate=AutoCaptureGate()
  precondition(!gate.ready(at:0,moving:false,blocked:false,duplicate:false,hasPage:true))
  precondition(!gate.ready(at:0.5,moving:false,blocked:false,duplicate:false,hasPage:true))
  precondition(!gate.ready(at:0.9,moving:false,blocked:true,duplicate:false,hasPage:true),"A stationary hand must block capture")
  precondition(!gate.ready(at:1,moving:false,blocked:false,duplicate:false,hasPage:true))
  precondition(gate.ready(at:1.9,moving:false,blocked:false,duplicate:false,hasPage:true))
  gate.captured(at:1.9)
  precondition(!gate.ready(at:3.2,moving:false,blocked:false,duplicate:true,hasPage:true),"Same page must not rearm after cooldown")
  precondition(!gate.ready(at:4,moving:false,blocked:false,duplicate:false,hasPage:true))
  precondition(gate.ready(at:4.9,moving:false,blocked:false,duplicate:false,hasPage:true),"A clear changed page can capture")
  precondition(PageQuality.measure(black,context:scanner.context).reason?.contains("dark")==true)
  let white=CIImage(color:CIColor(red:1,green:1,blue:1)).cropped(to:black.extent)
  precondition(PageQuality.measure(white,context:scanner.context).reason==nil,"Blank white paper must not be labelled blurred")
  precondition(PageQuality(sharpness:5,contrast:100,whiteLevel:220).reason?.contains("blurred")==true)
  precondition(!PageQuality.touchesFrame(corners))
  var clipped=corners;clipped.tl.x=0
  precondition(PageQuality.touchesFrame(clipped))
  // Exercise the real reject and override flow in an isolated session.
  scanner.error=nil;scanner.busy=true
  scanner.process(black,originalData:nil)
  let deadline=Date().addingTimeInterval(5)
  while scanner.busy && Date()<deadline {RunLoop.main.run(until:Date().addingTimeInterval(0.01))}
  precondition(!scanner.busy && scanner.qualityWarning != nil)
  precondition(scanner.document.pages.isEmpty,"Rejected scans must stay out of the PDF manifest")
  precondition(scanner.rejectedURL.map{FileManager.default.fileExists(atPath:$0.path)}==true)
  scanner.keepRejected()
  let keepDeadline=Date().addingTimeInterval(5)
  while scanner.busy && Date()<keepDeadline {RunLoop.main.run(until:Date().addingTimeInterval(0.01))}
  precondition(scanner.document.pages.count==1,"Keep anyway must save the rejected photo")
  precondition(scanner.qualityWarning==nil)
  // New workflow operations must preserve order and recover after failed writes.
  let workflow = Scanner(storageRoot: root.appendingPathComponent("workflow"))
  var reviewDoc = ScanDocument(); reviewDoc.pages = pages
  try workflow.commit(reviewDoc)
  workflow.autoCapture = true
  workflow.beginReview(pages[1].id)
  precondition(!workflow.autoCapture && workflow.reviewing && workflow.selected == pages[1].id)
  workflow.connected = true
  workflow.capture(automatic: true)
  precondition(!workflow.busy && workflow.selected == pages[1].id, "A queued automatic capture must not interrupt review")
  workflow.movePage(-1)
  precondition(workflow.document.pages.map(\.id) == [pages[1].id, pages[0].id, pages[2].id])
  workflow.navigatePage(1)
  precondition(workflow.selected == pages[0].id)
  workflow.replaceSelectedPage()
  precondition(workflow.replacementID == pages[0].id && !workflow.autoCapture && !workflow.reviewing)
  let replacement = ScanPage(file: "Pages/replacement.jpg", original: "Originals/replacement.jpg")
  try workflow.applyCapture([replacement], replacing: pages[0].id, resolving: nil)
  precondition(workflow.document.pages[1].id == pages[0].id && workflow.document.pages[1].file == replacement.file)
  let replacementManifest = try Data(contentsOf: workflow.folder.appendingPathComponent("session.json"))
  do {
    try workflow.applyCapture([replacement, replacement], replacing: pages[0].id, resolving: nil)
    preconditionFailure("A split must not replace a single page")
  } catch {}
  precondition(readData(workflow.folder.appendingPathComponent("session.json")) == replacementManifest)
  workflow.pdfIsCurrent = true
  workflow.rotate(workflow.document.pages[0])
  precondition(!workflow.pdfIsCurrent, "Page edits must mark the PDF as old")
  let validFolder = workflow.folder
  workflow.folder = blocker
  let beforeFailure = workflow.document.pages.map(\.file)
  do {
    try workflow.applyCapture([replacement], replacing: pages[2].id, resolving: nil)
    preconditionFailure("Replacement must report a failed save")
  } catch {}
  precondition(workflow.document.pages.map(\.file) == beforeFailure)
  workflow.folder = validFolder; workflow.error = nil
  let old = try JSONDecoder().decode(ScanDocument.self, from: Data("{\"title\":\"Old session\",\"pages\":[]}".utf8))
  precondition(old.title == "Old session" && old.rejected == nil, "Old session files must still decode")

  // Reject metadata must survive reload, and keeping it must resolve the entry.
  let rejectedScanner = Scanner(storageRoot: root.appendingPathComponent("rejected-workflow"))
  rejectedScanner.captureOptions = (Quad.full, false, 0.4, false)
  rejectedScanner.busy = true
  rejectedScanner.process(black, originalData: nil)
  waitForWork(rejectedScanner)
  precondition(rejectedScanner.rejectedScans.count == 1 && !rejectedScanner.autoCapture)
  let rejection = rejectedScanner.rejectedScans[0]
  try rejectedScanner.restore()
  precondition(rejectedScanner.rejectedScans[0].divider == 0.4)
  rejectedScanner.reviewRejected(rejection)
  rejectedScanner.keepRejected(); waitForWork(rejectedScanner)
  precondition(rejectedScanner.document.pages.count == 1 && rejectedScanner.rejectedScans.isEmpty)
  precondition(FileManager.default.fileExists(atPath: rejectedScanner.folder.appendingPathComponent(rejection.file).path))
  rejectedScanner.loadLegacyRejections()
  precondition(rejectedScanner.rejectedScans.isEmpty, "Kept photos must not reappear during recovery")
  let cropPage = rejectedScanner.document.pages[0]
  let originalURL = rejectedScanner.folder.appendingPathComponent(cropPage.original)
  let originalBytes = try Data(contentsOf: originalURL)
  rejectedScanner.showRejected = false
  rejectedScanner.beginReview(cropPage.id)
  rejectedScanner.cropSelectedPage(to: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
  waitForWork(rejectedScanner)
  precondition(rejectedScanner.error == nil)
  precondition(rejectedScanner.document.pages[0].id == cropPage.id && rejectedScanner.document.pages[0].file != cropPage.file)
  let cropped = CIImage(contentsOf: rejectedScanner.folder.appendingPathComponent(rejectedScanner.document.pages[0].file))!
  precondition(cropped.extent.width == 320 && cropped.extent.height == 240)
  precondition(readData(originalURL) == originalBytes, "Crop must preserve the original")
  precondition(FileManager.default.fileExists(atPath: rejectedScanner.folder.appendingPathComponent(cropPage.file).path))
  let cropManifest = try Data(contentsOf: rejectedScanner.folder.appendingPathComponent("session.json"))
  rejectedScanner.cropSelectedPage(to: CGRect(x: -0.1, y: 0, width: 1, height: 1))
  precondition(!rejectedScanner.busy)
  precondition(readData(rejectedScanner.folder.appendingPathComponent("session.json")) == cropManifest)
  rejectedScanner.openSession(at: blocker)
  precondition(rejectedScanner.document.pages[0].id == cropPage.id, "Invalid session open must preserve the document")
  rejectedScanner.error = nil
  rejectedScanner.browseSessions()
  let listDeadline = Date().addingTimeInterval(5)
  while rejectedScanner.loadingSessions && Date() < listDeadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
  precondition(rejectedScanner.sessions.contains { $0.folder.resolvingSymlinksInPath().path == rejectedScanner.folder.resolvingSymlinksInPath().path && $0.pageCount == 1 }, "Session listing: \(rejectedScanner.sessions.map { ($0.folder.path, $0.pageCount) }) active: \(rejectedScanner.folder.path)")
  rejectedScanner.showSessions = false
  let exportURL = root.appendingPathComponent("test.pdf")
  rejectedScanner.rotate(rejectedScanner.document.pages[0])
  rejectedScanner.writePDF(to: exportURL); waitForWork(rejectedScanner)
  precondition(rejectedScanner.error == nil && rejectedScanner.pdfIsCurrent)
  let pdf = PDFDocument(url: exportURL)!
  precondition(pdf.pageCount == 1 && pdf.page(at: 0)?.rotation == 90)
  let pdfBytes = try Data(contentsOf: exportURL)
  var missingDoc = rejectedScanner.document
  missingDoc.pages.append(ScanPage(file: "Pages/missing.jpg", original: "Originals/missing.jpg"))
  try rejectedScanner.commit(missingDoc)
  rejectedScanner.writePDF(to: exportURL); waitForWork(rejectedScanner)
  precondition(rejectedScanner.error != nil && !rejectedScanner.pdfIsCurrent)
  precondition(readData(exportURL) == pdfBytes, "Failed export must keep the previous PDF")
  print("PASS: PDF page count and rotation; failed export preserves prior PDF; resolved rejection recovery")
  print("PASS: review capture exclusion; page navigation and order; replacement identity and rollback; old session decoding; rejected-photo recovery; non-destructive crop; document browser")
  let still=[UInt8](repeating:128,count:64*48*4)
  var arm=still
  for y in 8..<16 {for x in 8..<16 {arm[(y*64+x)*4]=200}}
  precondition(CaptureCheck.motion(arm,still),"Small local movement must not be diluted by the background")
  precondition(!CaptureCheck.motion(still,still))
  print("PASS: undo order; persisted rotation; failed-write rollback; session isolation; new-document failure recovery; blank-frame rejection; asymmetric crop coordinates; hand and duplicate capture gates; local motion")
 }
}
