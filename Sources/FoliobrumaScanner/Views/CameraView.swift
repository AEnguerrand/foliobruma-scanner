import AVFoundation
import AppKit
import SwiftUI

struct CameraView: NSViewRepresentable {
  let session: AVCaptureSession
  func makeNSView(context: Context) -> NSView {
    let view = PreviewView()
    view.layer = AVCaptureVideoPreviewLayer(session: session)
    view.wantsLayer = true
    (view.layer as? AVCaptureVideoPreviewLayer)?.videoGravity = .resizeAspect
    return view
  }
  func updateNSView(_ nsView: NSView, context: Context) {}
}
private final class PreviewView: NSView {
  override func layout() {
    super.layout()
    layer?.frame = bounds
  }
}
