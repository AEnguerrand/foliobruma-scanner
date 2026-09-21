import SwiftUI

struct CaptureControls: View {
  @ObservedObject var model: Scanner
  var body: some View {
    if !model.reviewing {
      VStack(spacing: 10) {
        if model.isSheetBatch {
          Text(model.sheetCapturePrompt).font(.headline)
          Text(L10n.text("USB button action: Finish sheet. The next sheet starts automatic capture after completion."))
            .font(.caption).foregroundStyle(.secondary)
        }
        if model.replacementID != nil {
          HStack {
            Label(
              L10n.text("Replace one page · Original files are kept"),
              systemImage: "arrow.triangle.2.circlepath")
            Button(L10n.text("Cancel replacement")) {
              model.replacementID = nil
              model.beginReview()
            }
            .disabled(model.busy)
          }.font(.callout)
        }
        HStack(spacing: 16) {
          if model.replacementID == nil {
            Button {
              model.autoCapture.toggle()
              model.status =
                model.autoCapture ? L10n.text("Waiting for a clear, still page") : L10n.text("Capture paused")
            } label: {
              Label(
                model.autoCapture ? L10n.text("Pause auto capture") : L10n.text("Start auto capture"),
                systemImage: model.autoCapture ? "pause.fill" : "play.fill")
            }.buttonStyle(.borderedProminent).controlSize(.large)
              .disabled(!model.connected || model.sheetIsFull || (model.busy && !model.autoCapture))
          }
          Button(action: model.capture) {
            Label(
              model.busy
                ? L10n.text("Working…")
                : (model.replacementID == nil ? L10n.text("Capture page") : L10n.text("Capture replacement")),
              systemImage: "camera.fill")
          }.keyboardShortcut(.space, modifiers: []).controlSize(.large)
            .disabled(!model.connected || model.busy || (model.sheetIsFull && model.replacementID == nil))
        }
      }.padding(16)
    }
  }
}

struct CaptureSettings: View {
  @ObservedObject var model: Scanner
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text(L10n.text("Scan setup")).font(.headline)
        Picker(L10n.text("Camera"), selection: $model.deviceID) {
          if model.devices.isEmpty { Text(L10n.text("No camera found")).tag("") }
          ForEach(model.devices, id: \.uniqueID) { Text($0.localizedName).tag($0.uniqueID) }
        }.onChange(of: model.deviceID) { if model.connected { model.connect() } }
        HStack {
          Button(model.connected ? L10n.text("Reconnect") : L10n.text("Connect camera"), action: model.connect)
            .disabled(model.devices.isEmpty)
          Button {
            model.refreshCameras()
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .help(L10n.text("Refresh camera list")).accessibilityLabel(L10n.text("Refresh camera list"))
        }
        if model.connected {
          Text(L10n.format("%@ · Connected", model.resolution)).font(.caption).foregroundStyle(.secondary)
        }
        Divider()
        Text(L10n.text("Document type")).font(.subheadline)
        Picker(L10n.text("Document type"), selection: $model.book) {
          Text(L10n.text("Book")).tag(true)
          Text(L10n.text("Single page")).tag(false)
        }.pickerStyle(.segmented).labelsHidden().disabled(model.isSheetBatch)
        if model.book {
          Toggle(L10n.text("Split into two pages"), isOn: $model.split).disabled(model.replacementID != nil)
        }
        Toggle(L10n.text("Auto crop"), isOn: $model.autoCrop)
        if model.book && model.split && model.replacementID == nil {
          VStack(alignment: .leading) {
            Text(L10n.format("Spine position · %ld%%", Int(model.divider * 100)))
            Slider(value: $model.divider, in: 0.3...0.7)
              .accessibilityLabel(L10n.text("Book spine position"))
              .accessibilityValue(L10n.format("%ld percent", Int(model.divider * 100)))
            Button(L10n.text("Centre spine")) { model.divider = 0.5 }
            Text(L10n.text("Drag the gold handle in the camera view to adjust the split."))
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        Button(L10n.text("Preview crop and split"), action: model.previewFraming)
          .disabled(!model.connected)
        Divider()
        Toggle(L10n.text("Capture sounds"), isOn: $model.soundEnabled)
        DisclosureGroup(L10n.text("Scanning tips")) {
          Text(L10n.text("Keep all page edges in view. Use even light. Wait for the saved signal before turning the page."))
            .font(.callout).foregroundStyle(.secondary).padding(.top, 6)
        }
      }.padding(18)
    }.background(Color(nsColor: .controlBackgroundColor)).disabled(model.busy || model.autoCapture)
  }
}
