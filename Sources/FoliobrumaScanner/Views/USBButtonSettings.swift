import SwiftUI

struct USBButtonSettings: View {
  @ObservedObject var button = USBButton.shared

  var body: some View {
    Section(L10n.text("USB button")) {
      Picker(L10n.text("Device"), selection: Binding(
        get: { button.binding.deviceID }, set: { button.select($0) })) {
        Text(L10n.text("None")).tag("")
        if !button.binding.deviceID.isEmpty && !button.connected {
          Text(L10n.text("Saved device · Disconnected or ambiguous")).tag(button.binding.deviceID)
        }
        ForEach(button.devices) { Text(verbatim: $0.name).tag($0.id) }
      }
      Button(L10n.text("Refresh devices")) { button.refresh() }
      Picker(L10n.text("Action"), selection: $button.binding.action) {
        ForEach(USBButtonAction.allCases, id: \.self) { action in
          Text(L10n.text(action.title)).tag(action)
        }
      }
      Text(L10n.format("Signals received: %ld", button.receivedCount)).monospacedDigit()
      HStack {
        Button(L10n.text(button.learning ? "Cancel" : "Learn button")) {
          if button.learning { button.cancelLearning() } else { button.learn() }
        }.disabled(!button.connected)
        Text(L10n.format("Test presses: %ld", button.testCount)).monospacedDigit()
      }
      if !button.status.isEmpty { Text(button.status).font(.callout) }
      Toggle(L10n.text("Enable button action"), isOn: $button.binding.enabled)
        .disabled(button.binding.signal == nil || !button.connected || button.learning)
      Text(L10n.text("Use Capture page for scanning. Use Next letter within a letter batch. New item opens the item form."))
        .font(.caption).foregroundStyle(.secondary)
      Text(L10n.text("Actions are off in Settings. Close Settings and select the document window to use the button."))
        .font(.caption).foregroundStyle(.secondary)
      Text(L10n.text("Supports USB HID button and vendor controls with a repeatable signal. Keyboards and mice are not listed."))
        .font(.caption).foregroundStyle(.secondary)
    }
    .onAppear { button.start(); button.settingsVisible = true }
    .onDisappear { button.cancelLearning(); button.settingsVisible = false }
  }
}

// Route an input to only the active document window, including when several are open.
struct USBButtonWindow: NSViewRepresentable {
  var onWindow: (NSWindow?) -> Void
  func makeNSView(context: Context) -> WindowView {
    let view = WindowView()
    view.onWindow = onWindow
    return view
  }
  func updateNSView(_ nsView: WindowView, context: Context) {}
  final class WindowView: NSView {
    var onWindow: ((NSWindow?) -> Void)?
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      let current = window
      DispatchQueue.main.async { [weak self] in self?.onWindow?(current) }
    }
  }
}
