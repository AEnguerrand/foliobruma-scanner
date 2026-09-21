import AVFoundation
import AppKit
import Combine
import CoreImage
import Vision

// Shared observable state and session setup.
// Related operations are in the Scanner extensions.
final class Scanner: NSObject, ObservableObject {
  @Published var devices: [AVCaptureDevice] = []
  @Published var deviceID = ""
  @Published var connected = false
  @Published var status = L10n.text("Connect your scanner to begin")
  @Published var error: String? {
    didSet {
      if error != nil {
        captureSaved = false
        if soundEnabled && tracksActiveSession { NSSound(named: "Basso")?.play() }
      }
    }
  }
  @Published var book = true
  @Published var split = true
  @Published var autoCrop = true
  @Published var autoCapture = false {
    didSet {
      duplicateFeedback.reset()
      duplicateWarning = false
      updatePreflight(nil)
      let enabled = autoCapture
      queue.async {
        self.autoEnabled = enabled
        self.gate.reset()
        self.heldFrame = nil
      }
    }
  }
  @Published var soundEnabled = true
  @Published var preflightWarning: String?
  var preflightFeedback = PreflightFeedbackGate()
  @Published var duplicateWarning = false
  var duplicateFeedback = DuplicateFeedbackGate()
  @Published var captureSaved = false
  @Published var qualityWarning: String?
  @Published var rejectedURL: URL?
  var feedbackID = UUID()
  @Published var busy = false
  @Published var quad: Quad?
  @Published var selected: String?
  @Published var document = ScanDocument()
  @Published var folder: URL
  @Published var resolution = ""
  @Published var divider = 0.5
  @Published var lastPDF: URL?
  @Published var pdfIsCurrent = false
  @Published var sessionSaved = false
  @Published var exportProgress: Double?
  @Published var reviewing = false
  @Published var showNewItem = false
  @Published var showMetadata = false
  @Published var showLabel = false
  @Published var metadataWorkspace = false
  @Published var showSessions = false
  @Published var showRejected = false
  @Published var showExport = false
  @Published var showCrop = false
  @Published var showSheetGroups = false
  var batchPrintInfo: NSPrintInfo?
  var printBatchID: String?
  @Published var showFraming = false
  @Published var framingImages: [NSImage] = []
  @Published var sessions: [SavedSession] = []
  @Published var loadingSessions = false
  @Published var replacementID: String?
  var keptRejection: String?
  var captureReplacementID: String?
  var pendingReview = false
  let session = AVCaptureSession()
  let queue = DispatchQueue(label: "foliobruma.camera")
  let context = CIContext(options: [.cacheIntermediates: false])
  let photoOutput = AVCapturePhotoOutput()
  let videoOutput = AVCaptureVideoDataOutput()
  var input: AVCaptureDeviceInput?
  var latest: CIImage?
  var lastTick = 0.0
  var previous: [UInt8]?
  var autoEnabled = false
  var captureInFlight = false
  var heldFrame: [UInt8]?
  var heldReason = ""
  var heldPreflightWarning: String?
  var gate = AutoCaptureGate()
  var recentPrints: [CaptureCheck.Fingerprint] = []
  var recentPreviewPrints: [CaptureCheck.Fingerprint] = []
  var capturePreviewPrint: CaptureCheck.Fingerprint?

  var captureOptions: (quad: Quad?, split: Bool, divider: Double, automatic: Bool)?
  @Published var deleting: (page: ScanPage, index: Int)?
  let tracksActiveSession: Bool
  var root: URL
  init(storageRoot: URL? = nil) {
    let base =
      storageRoot
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Sovenelia Scanner", isDirectory: true)
    root = base
    tracksActiveSession = storageRoot == nil
    let saved = storageRoot == nil ? UserDefaults.standard.string(forKey: "activeSession") : nil
    folder =
      saved.map { URL(fileURLWithPath: $0) }
      ?? base.appendingPathComponent("Sessions/" + UUID().uuidString, isDirectory: true)
    super.init()
    do {
      try prepareFolder()
      try restore()
      if document.metadata?.sheetBatch == true { book = false; split = false }
    } catch { self.error = error.localizedDescription }
    if storageRoot == nil {
      devices =
        AVCaptureDevice.DiscoverySession(
          deviceTypes: [.external, .builtInWideAngleCamera], mediaType: .video,
          position: .unspecified
        ).devices
    }
    loadLegacyRejections()
    seedRecentPages()
    deviceID =
      devices.first(where: { $0.localizedName.localizedCaseInsensitiveContains("IRIS") })?.uniqueID
      ?? devices.first?.uniqueID ?? ""
  }
}
