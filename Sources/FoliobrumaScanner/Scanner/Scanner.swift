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
  @Published var status = "Connect your scanner to begin"
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
  var recentPrints: [VNFeaturePrintObservation] = []

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
    } catch { self.error = error.localizedDescription }
    if storageRoot == nil {
      devices =
        AVCaptureDevice.DiscoverySession(
          deviceTypes: [.external, .builtInWideAngleCamera], mediaType: .video,
          position: .unspecified
        ).devices
    }
    seedRecentPages()
    deviceID =
      devices.first(where: { $0.localizedName.localizedCaseInsensitiveContains("IRIS") })?.uniqueID
      ?? devices.first?.uniqueID ?? ""
  }
}
