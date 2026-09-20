import AppKit
import SwiftUI

struct ScanPreview: View {
  @ObservedObject var model: Scanner
  let gold: Color
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color.black
        CameraView(session: model.session)
        cropOverlay(in: geometry.size)
        connectionPrompt
        captureFeedback
        statusOverlay
      }.coordinateSpace(name: "cameraPreview")
    }.frame(minHeight: 280)
  }

  // Keep the view builders small enough for the CI compiler to check each one.
  @ViewBuilder
  private func cropOverlay(in size: CGSize) -> some View {
    if model.connected, model.autoCrop, let q = model.quad {
      let ratio = CGFloat(dimensionsRatio(model.resolution))
      let w = min(size.width, size.height * ratio)
      let h = w / ratio
      let ox = (size.width - w) / 2
      let oy = (size.height - h) / 2
      Path { p in
        let a = q.points.map { CGPoint(x: ox + $0.x * w, y: oy + (1 - $0.y) * h) }
        p.move(to: a[0])
        for v in a.dropFirst() { p.addLine(to: v) }
        p.closeSubpath()
        if model.book && model.split && model.replacementID == nil {
          let t = CGFloat(model.divider)
          p.move(
            to: CGPoint(
              x: ox + (q.tl.x + (q.tr.x - q.tl.x) * t) * w,
              y: oy + (1 - (q.tl.y + (q.tr.y - q.tl.y) * t)) * h))
          p.addLine(
            to: CGPoint(
              x: ox + (q.bl.x + (q.br.x - q.bl.x) * t) * w,
              y: oy + (1 - (q.bl.y + (q.br.y - q.bl.y) * t)) * h))
        }
      }.stroke(gold, lineWidth: 2).allowsHitTesting(false)
      if model.book && model.split && model.replacementID == nil {
        let middleX =
          (q.tl.x + q.bl.x) / 2 + ((q.tr.x + q.br.x - q.tl.x - q.bl.x) / 2) * CGFloat(model.divider)
        let middleY = (q.tl.y + q.bl.y + q.tr.y + q.br.y) / 4
        Image(systemName: "arrow.left.and.right.circle.fill").font(.title).foregroundStyle(
          gold
        )
        .position(x: ox + middleX * w, y: oy + (1 - middleY) * h)
        .gesture(
          DragGesture(coordinateSpace: .named("cameraPreview")).onChanged { value in
            guard !model.busy, !model.autoCapture else { return }
            let left = (q.tl.x + q.bl.x) / 2
            let span = (q.tr.x + q.br.x) / 2 - left
            if span > 0 {
              model.divider = Double(min(0.7, max(0.3, ((value.location.x - ox) / w - left) / span)))
            }
          }
        )
        .accessibilityLabel(
          L10n.text("Spine handle. Use the Spine position slider for keyboard adjustment."))
      }
    }
  }

  @ViewBuilder
  private var connectionPrompt: some View {
    if !model.connected {
      VStack(spacing: 20) {
        BrandIcon().frame(width: 96, height: 96)
          .accessibilityHidden(true)
        Text(
          model.document.pages.isEmpty ? L10n.text("Scan your first page") : L10n.text("Add pages to this document")
        ).font(.title2)
        Text(L10n.text("Select a camera in Scan setup, then connect it.")).foregroundColor(
          .secondary)
        Button(L10n.text("Connect camera"), action: model.connect).buttonStyle(.borderedProminent)
          .disabled(model.devices.isEmpty || model.busy)
      }
    }
  }

  @ViewBuilder
  private var captureFeedback: some View {
    if let warning = model.preflightWarning, model.qualityWarning == nil {
      VStack {
        Spacer()
        Label(warning, systemImage: "hand.raised.fill").font(.headline).foregroundColor(.black)
          .padding(14).background(gold.opacity(0.96)).cornerRadius(10).padding(.bottom, 18)
      }.allowsHitTesting(false)
    }
    if model.duplicateWarning && model.qualityWarning == nil && model.preflightWarning == nil {
      VStack(spacing: 12) {
        Label(L10n.text("Already scanned"), systemImage: "doc.on.doc.fill").font(.title.bold())
        Text(L10n.text("Turn the page. No extra copy was saved.")).font(.headline)
      }.foregroundColor(.black).padding(24).background(gold.opacity(0.96)).cornerRadius(16)
        .allowsHitTesting(false)
    }
    if model.captureSaved {
      Rectangle().stroke(Color.green, lineWidth: 8).allowsHitTesting(false)
      VStack(spacing: 12) {
        Image(systemName: "checkmark.circle.fill").font(.system(size: 60))
        Text(L10n.text("Saved — turn the page")).font(.title.bold())
      }.foregroundColor(.white).padding(28).background(
        Color(red: 0.08, green: 0.32, blue: 0.18).opacity(0.96)
      ).cornerRadius(18).allowsHitTesting(false)
    }
  }

  private var statusOverlay: some View {
    VStack {
      Text(model.status).font(.callout).padding(10).background(Color.black.opacity(0.8))
        .cornerRadius(8).padding(.top, 16)
      Spacer()
    }.allowsHitTesting(false)
  }

  func dimensionsRatio(_ text: String) -> Double {
    let nums = text.components(separatedBy: " × ").compactMap(Double.init)
    return nums.count == 2 && nums[1] > 0 ? nums[0] / nums[1] : 16 / 9
  }
}
