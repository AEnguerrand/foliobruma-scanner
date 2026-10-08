import SwiftUI
import ScannerCore

@MainActor final class LabelHandoffDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private let model = LocationLabelPrinter()
  private var controller: NSWindowController?

  func application(_ application: NSApplication, open urls: [URL]) {
    guard urls.count == 1, let url = urls.first,
      let request = LocationLabelRequest(url: url) else {
      let alert = NSAlert()
      alert.messageText = L10n.text("Cannot open this label")
      alert.informativeText = L10n.text("Open a binder or box label from the Foliobruma website.")
      alert.runModal()
      return
    }
    if !model.printing { model.prepare(request) }
    if controller == nil {
      let content = LocationLabelView(model: model) { [weak self] in self?.controller?.window?.performClose(nil) }
      let window = NSWindow(contentViewController: NSHostingController(rootView: content))
      window.title = L10n.text("Binder or box label")
      window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
      window.setContentSize(NSSize(width: 640, height: 500))
      window.minSize = NSSize(width: 560, height: 430)
      window.isReleasedWhenClosed = false
      window.delegate = self
      window.center()
      controller = NSWindowController(window: window)
    }
    controller?.showWindow(nil)
    controller?.window?.makeKeyAndOrderFront(nil)
    application.activate(ignoringOtherApps: true)
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool { !model.printing }
}
