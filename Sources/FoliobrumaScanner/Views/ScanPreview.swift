import AppKit
import SwiftUI

struct ScanPreview: View {
  @ObservedObject var model: Scanner
  let gold: Color
  var body: some View {
    GeometryReader { g in
      ZStack {
        Color.black
        if let id = model.selected, let page = model.document.pages.first(where: { $0.id == id }),
          let image = model.image(page)
        {
          Image(nsImage: image).resizable().scaledToFit().rotationEffect(
            .degrees(Double(page.rotation))
          ).padding(25)
          VStack {
            Spacer()
            HStack {
              Button("Rotate") { model.rotate(page) }
              Button("Remove") { model.remove(page) }
              Button("Back to camera") { model.selected = nil }
            }.padding().background(.ultraThinMaterial).cornerRadius(10).padding()
          }
        } else {
          CameraView(session: model.session)
          if model.connected, model.autoCrop, let q = model.quad {
            let ratio = dimensionsRatio(model.resolution)
            let w = min(g.size.width, g.size.height * ratio)
            let h = w / ratio
            let ox = (g.size.width - w) / 2
            let oy = (g.size.height - h) / 2
            Path { p in
              let a = q.points.map { CGPoint(x: ox + $0.x * w, y: oy + (1 - $0.y) * h) }
              p.move(to: a[0])
              for v in a.dropFirst() { p.addLine(to: v) }
              p.closeSubpath()
              if model.book && model.split {
                let t = model.divider
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
          }
          if !model.connected {
            VStack(spacing: 20) {
              Image(systemName: "camera").font(.system(size: 48)).foregroundColor(gold)
              Text("Your archive starts here").font(.title2)
              Text("Connect your scanner and place a page under the camera.").foregroundColor(
                .secondary)
              Button("Connect scanner", action: model.connect).buttonStyle(.borderedProminent)
            }
          }
        }
        if let reason = model.qualityWarning {
          VStack(spacing: 12) {
            Label("Rescan needed", systemImage: "exclamationmark.triangle.fill").font(.title.bold())
            Text(reason).font(.headline)
            Text("This photo is kept separately and is not in your PDF.").font(.callout)
            Button("Keep this scan anyway", action: model.keepRejected).disabled(model.busy)
          }.foregroundColor(.white).padding(24).background(
            Color(red: 0.48, green: 0.10, blue: 0.08).opacity(0.96)
          ).cornerRadius(16)
        }
        if let warning = model.preflightWarning, model.qualityWarning == nil {
          VStack {
            Spacer()
            Label(warning, systemImage: "hand.raised.fill").font(.headline).foregroundColor(.black)
              .padding(14).background(gold.opacity(0.96)).cornerRadius(10).padding(.bottom, 18)
          }.allowsHitTesting(false)
        }
        if model.duplicateWarning && model.qualityWarning == nil && model.preflightWarning == nil {
          VStack(spacing: 12) {
            Label("Already scanned", systemImage: "doc.on.doc.fill").font(.title.bold())
            Text("Turn the page. No extra copy was saved.").font(.headline)
          }.foregroundColor(.black).padding(24).background(gold.opacity(0.96)).cornerRadius(16)
            .allowsHitTesting(false)
        }
        if model.captureSaved {
          Rectangle().stroke(Color.green, lineWidth: 8).allowsHitTesting(false)
          VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 60))
            Text("Saved — turn the page").font(.title.bold())
          }.foregroundColor(.white).padding(28).background(
            Color(red: 0.08, green: 0.32, blue: 0.18).opacity(0.96)
          ).cornerRadius(18).allowsHitTesting(false)
        }
        VStack {
          Text(model.status).font(.callout).padding(10).background(Color.black.opacity(0.8))
            .cornerRadius(8).padding(.top, 16)
          Spacer()
        }.allowsHitTesting(false)
      }
    }.frame(minHeight: 280)
  }
  func dimensionsRatio(_ text: String) -> Double {
    let nums = text.components(separatedBy: " × ").compactMap(Double.init)
    return nums.count == 2 && nums[1] > 0 ? nums[0] / nums[1] : 16 / 9
  }
}
