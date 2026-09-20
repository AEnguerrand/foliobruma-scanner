import AppKit
import SwiftUI

struct CaptureControls: View {
  @ObservedObject var model: Scanner
  var body: some View {
    HStack(spacing: 20) {
      Button {
        model.selected = nil
        model.autoCapture.toggle()
      } label: {
        Label(
          model.autoCapture ? "Pause auto capture" : "Start auto capture",
          systemImage: model.autoCapture ? "pause.fill" : "play.fill"
        ).fontWeight(.semibold).padding(10)
      }.buttonStyle(.borderedProminent).disabled(!model.connected || model.busy)
      Button(action: model.capture) {
        Label(model.busy ? "Working…" : "Capture", systemImage: "camera.fill").padding(10)
      }.keyboardShortcut(.space, modifiers: []).disabled(!model.connected || model.busy)
      if model.book { Toggle("Split pages", isOn: $model.split).toggleStyle(.switch) }
      Toggle("Auto crop", isOn: $model.autoCrop).toggleStyle(.switch)
      Toggle(isOn: $model.soundEnabled) {
        Image(systemName: model.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
      }.toggleStyle(.switch).help("Play success, duplicate, pre-capture warning, and rescan sounds")
        .accessibilityLabel("Capture sounds")
      if model.book && model.split {
        HStack {
          Text("Spine").foregroundColor(.secondary)
          Slider(value: $model.divider, in: 0.3...0.7).frame(width: 90)
        }
      }
    }.padding(20)
  }
}
