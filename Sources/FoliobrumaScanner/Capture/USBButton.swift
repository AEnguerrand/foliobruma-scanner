import AppKit
import Combine
import IOKit.hid

// One selected USB control. Reports and preferences stay on this Mac.
enum USBButtonAction: String, Codable, CaseIterable {
  case capture, autoCapture, nextDocument, newItem, nextLetter, finishSheet, review, export

  var title: String {
    switch self {
    case .capture: return "Capture page"
    case .autoCapture: return "Start or pause auto capture"
    case .nextDocument: return "Next document"
    case .newItem: return "New item…"
    case .nextLetter: return "Next letter"
    case .finishSheet: return "Finish sheet"
    case .review: return "Review pages"
    case .export: return "Export PDF"
    }
  }
}

struct USBButtonSignal: Codable, Equatable {
  var page: UInt32
  var usage: UInt32
  var bytes: Data
}

struct USBButtonBinding: Codable {
  var deviceID = ""
  var signal: USBButtonSignal?
  var action: USBButtonAction = .capture
  var enabled = false
}

// A held button can send repeated reports. Require a quiet interval before another action.
struct USBButtonGate {
  var lastMatch: TimeInterval?
  mutating func accept(at now: TimeInterval) -> Bool {
    defer { lastMatch = now }
    return lastMatch.map { now - $0 >= 0.6 } ?? true
  }
}

struct USBButtonDevice: Identifiable {
  let id: String
  let name: String
  let device: IOHIDDevice
}

final class USBButton: ObservableObject {
  static let shared = USBButton()
  let actions = PassthroughSubject<USBButtonAction, Never>()
  @Published var binding: USBButtonBinding { didSet { save() } }
  @Published private(set) var devices: [USBButtonDevice] = []
  @Published private(set) var learning = false
  @Published private(set) var testCount = 0
  @Published private(set) var receivedCount = 0
  @Published private(set) var status = ""
  weak var settingsWindow: NSWindow?
  var settingsVisible: Bool { settingsWindow?.isVisible == true }
  private let defaults: UserDefaults
  private var manager: IOHIDManager?
  private var gate = USBButtonGate()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    binding = defaults.data(forKey: "usbButtonBinding").flatMap {
      try? JSONDecoder().decode(USBButtonBinding.self, from: $0)
    } ?? USBButtonBinding()
  }

  var connected: Bool { devices.filter { $0.id == binding.deviceID }.count == 1 }

  func start() {
    guard manager == nil else { return }
    let next = IOHIDManagerCreate(kCFAllocatorDefault, 0)
    manager = next
    // Do not monitor keyboards or mice. Support vendor controls and HID button devices.
    IOHIDManagerSetDeviceMatching(next, [kIOHIDTransportKey: "USB"] as CFDictionary)
    let context = Unmanaged.passUnretained(self).toOpaque()
    IOHIDManagerRegisterDeviceMatchingCallback(next, { context, _, _, _ in
      guard let context else { return }
      Unmanaged<USBButton>.fromOpaque(context).takeUnretainedValue().refresh()
    }, context)
    IOHIDManagerRegisterDeviceRemovalCallback(next, { context, _, _, _ in
      guard let context else { return }
      let owner = Unmanaged<USBButton>.fromOpaque(context).takeUnretainedValue()
      owner.cancelLearning()
      owner.refresh()
    }, context)
    IOHIDManagerRegisterInputValueCallback(next, { context, result, _, value in
      guard result == 0, let context else { return }
      Unmanaged<USBButton>.fromOpaque(context).takeUnretainedValue().receive(value)
    }, context)
    IOHIDManagerScheduleWithRunLoop(next, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
    let result = IOHIDManagerOpen(next, 0)
    if result != 0 {
      status = L10n.text("USB access failed. Check Input Monitoring in System Settings, then reopen the app.")
    }
    refresh()
  }

  func refresh() {
    guard let manager else { return }
    let found = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
    devices = found.compactMap { device in
      func number(_ key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0
      }
      let page = number(kIOHIDPrimaryUsagePageKey)
      guard (page == 9 || page >= 0xff00), number("Built-In") == 0,
        number(kIOHIDVendorIDKey) != 0 else { return nil }
      let vendor = number(kIOHIDVendorIDKey), product = number(kIOHIDProductIDKey)
      let serial = IOHIDDeviceGetProperty(device, kIOHIDSerialNumberKey as CFString) as? String
      let identity = serial.flatMap { $0.isEmpty ? nil : $0 } ?? "port-\(number(kIOHIDLocationIDKey))"
      let id = "\(vendor):\(product):\(identity):\(page):\(number(kIOHIDPrimaryUsageKey))"
      let code = String(format: "%04x:%04x", vendor, product)
      let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String
      let label = name ?? (vendor == 11866 && product == 8213 ? "IRIScan button" : L10n.text("USB button"))
      return USBButtonDevice(id: id, name: "\(label) · \(code) · \(identity)", device: device)
    }.sorted { $0.name < $1.name }
  }

  func select(_ id: String) {
    cancelLearning()
    binding = USBButtonBinding(deviceID: id)
    gate = USBButtonGate()
    testCount = 0
    receivedCount = 0
    status = L10n.text("Click Learn button, then press the physical button.")
  }

  func learn() {
    guard connected else { return }
    binding.enabled = false
    binding.signal = nil
    gate = USBButtonGate()
    testCount = 0
    learning = true
    status = L10n.text("Press the button once. Do not hold it.")
  }

  func cancelLearning() {
    learning = false
  }

  private func receive(_ value: IOHIDValue) {
    guard connected,
      let selected = devices.first(where: { $0.id == binding.deviceID }) else { return }
    let element = IOHIDValueGetElement(value)
    guard IOHIDElementGetDevice(element) == selected.device else { return }
    let length = IOHIDValueGetLength(value)
    guard length > 0, length <= 4096 else { return }
    let signal = USBButtonSignal(page: IOHIDElementGetUsagePage(element),
      usage: IOHIDElementGetUsage(element),
      bytes: Data(bytes: IOHIDValueGetBytePtr(value), count: length))
    handle(signal, at: ProcessInfo.processInfo.systemUptime)
  }

  // Also used by regression tests without opening USB devices.
  func handle(_ signal: USBButtonSignal, at now: TimeInterval) {
    receivedCount += 1
    // A Settings scene can retain its SwiftUI view after the window closes.
    if learning && !settingsVisible { cancelLearning() }
    if learning {
      binding.signal = signal
      cancelLearning()
      gate.lastMatch = now
      testCount = 1
      status = L10n.text("Button learned. Press it again to test, then enable the action.")
      return
    }
    guard signal == binding.signal, gate.accept(at: now) else { return }
    testCount += 1
    if binding.enabled && !settingsVisible { actions.send(binding.action) }
  }

  private func save() {
    if let data = try? JSONEncoder().encode(binding) {
      defaults.set(data, forKey: "usbButtonBinding")
    }
  }
}
