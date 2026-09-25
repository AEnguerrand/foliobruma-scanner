import SwiftUI

struct USBButtonSettings: View {
  @ObservedObject var button = USBButton.shared

  private var state: String {
    if !button.connected { return "Select a connected button" }
    if button.learning { return "Press the physical button once" }
    if button.binding.signal == nil { return "Button setup needed" }
    return button.binding.enabled ? "Button action enabled" : "Button action off"
  }

  var body: some View {
    Group {
      Section {
        HStack(spacing: 10) {
          Image(systemName: button.binding.enabled && button.connected ? "checkmark.circle.fill" : "button.programmable")
            .foregroundStyle(button.binding.enabled && button.connected ? Color.green : Color.secondary)
            .font(.title2).accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 3) {
            Text(L10n.text(state)).font(.headline)
            Text(L10n.text("Actions pause while Settings is open."))
              .font(.caption).foregroundStyle(.secondary)
          }
        }.padding(.vertical, 4)
      }
      Section(L10n.text("Device")) {
        HStack {
          Picker(L10n.text("USB button"), selection: Binding(
            get: { button.binding.deviceID }, set: { button.select($0) })) {
            Text(L10n.text("None")).tag("")
            if !button.binding.deviceID.isEmpty && !button.connected {
              Text(L10n.text("Saved device · Disconnected or ambiguous")).tag(button.binding.deviceID)
            }
            ForEach(button.devices) { device in
              Text(verbatim: deviceName(device)).tag(device.id)
            }
          }
          Button { button.refresh() } label: { Image(systemName: "arrow.clockwise") }
            .help(L10n.text("Refresh devices")).accessibilityLabel(L10n.text("Refresh devices"))
        }
        HStack {
          Text(L10n.text(button.binding.signal == nil ? "Learn the button signal" : "Button signal saved"))
            .foregroundStyle(.secondary)
          Spacer()
          Button(L10n.text(button.learning ? "Cancel" : button.binding.signal == nil ? "Learn button" : "Learn again")) {
            if button.learning { button.cancelLearning() } else { button.learn() }
          }.disabled(!button.connected)
        }
        if !button.status.isEmpty {
          Text(button.status).font(.callout).foregroundStyle(.secondary)
        }
      }
      Section {
        Picker(L10n.text("Action"), selection: $button.binding.action) {
          ForEach(USBButtonAction.allCases, id: \.self) { action in
            Text(L10n.text(action.title)).tag(action)
          }
        }
        Toggle(L10n.text("Enable button action"), isOn: $button.binding.enabled)
          .disabled(button.binding.signal == nil || !button.connected || button.learning)
      } header: {
        Text(L10n.text("Button action"))
      } footer: {
        Text(L10n.text("Close Settings and select the document window to use the button."))
      }
      Section {
        HStack {
          Text(L10n.text("Test presses"))
          Spacer()
          Text(button.testCount, format: .number).monospacedDigit()
        }
        DisclosureGroup(L10n.text("Diagnostics")) {
          Text(L10n.format("Signals received: %ld", button.receivedCount)).monospacedDigit()
          if let device = button.devices.first(where: { $0.id == button.binding.deviceID }) {
            Text(verbatim: device.name).font(.caption).textSelection(.enabled)
          }
          Text(L10n.text("Supports USB HID button and vendor controls with a repeatable signal. Keyboards and mice are not listed."))
            .font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .onDisappear { button.cancelLearning() }
  }

  private func deviceName(_ device: USBButtonDevice) -> String {
    let name = device.name.components(separatedBy: " · ").first ?? device.name
    let matches = button.devices.filter { $0.name.components(separatedBy: " · ").first == name }
    return matches.count > 1 ? device.name : name
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
