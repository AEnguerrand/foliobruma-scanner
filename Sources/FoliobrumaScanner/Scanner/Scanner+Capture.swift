import AVFoundation
import AppKit
import CoreImage

extension Scanner: AVCapturePhotoCaptureDelegate {
  func capture() { capture(automatic: false) }
  func capture(automatic: Bool) {
    guard connected, !busy, !reviewing, !showRejected, !showFraming, !showCrop, !showExport,
      !showSessions, !showNewItem, !showMetadata, !showLabel, !metadataWorkspace, !automatic || autoCapture
    else {
      if automatic {
        queue.async {
          self.captureInFlight = false
          self.gate.reset()
        }
      }
      return
    }
    if autoCrop && quad == nil {
      if automatic {
        queue.async {
          self.captureInFlight = false
          self.gate.reset()
        }
      }
      status = L10n.text("No page edges found. Turn off Auto crop to capture the full frame.")
      return
    }
    updatePreflight(nil)
    busy = true
    selected = nil
    captureSaved = false
    duplicateWarning = false
    qualityWarning = nil
    rejectedURL = nil
    status = L10n.text("Capturing… Hold still")
    captureReplacementID = replacementID
    keptRejection = nil
    captureOptions = (
      autoCrop ? quad : nil, replacementID == nil && book && split, divider, automatic
    )
    queue.async {
      self.captureInFlight = true
      self.capturePreviewPrint = self.latest.flatMap {
        CaptureCheck.fingerprint($0, context: self.context)
      }
      self.gate.captured(at: Date.timeIntervalSinceReferenceDate)
      if self.session.outputs.contains(self.photoOutput),
        !self.photoOutput.availablePhotoCodecTypes.isEmpty
      {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.maxPhotoDimensions =
          self.input!.device.activeFormat.supportedMaxPhotoDimensions.first
          ?? self.photoOutput.maxPhotoDimensions
        self.photoOutput.capturePhoto(with: settings, delegate: self)
      } else if let image = self.latest {
        self.process(image, originalData: nil)
      } else {
        self.captureInFlight = false
        DispatchQueue.main.async {
          self.busy = false
          self.error = L10n.text("The camera has not delivered an image yet.")
        }
      }
    }
  }
  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    if let data = photo.fileDataRepresentation(), let image = CIImage(data: data) {
      queue.async { self.process(image, originalData: data) }
    } else {
      queue.async {
        if let image = self.latest {
          self.process(image, originalData: nil)
        } else {
          self.captureInFlight = false
          DispatchQueue.main.async {
            self.busy = false
            self.error = error?.localizedDescription ?? L10n.text("Capture failed")
          }
        }
      }
    }
  }
}
