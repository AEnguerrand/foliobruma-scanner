import SwiftUI
import AVFoundation

struct ContentView: View {
  @StateObject var model = Scanner()
  @State private var usbWindow: NSWindow?
  @State private var rename = false
  @State private var draftTitle = ""
  @State private var browserNextAction: SessionBrowser.NextAction?
  @State private var reviewRejectedAfterExport = false
  let gold = Color(red: 1, green: 0.74, blue: 0.27)
  var body: some View {
    VStack(spacing: 0) {
      DocumentToolbar(model: model, rename: $rename)
      Divider()
      if model.metadataWorkspace {
        ItemSummary(model: model)
      } else {
      HStack(spacing: 0) {
        if model.reviewing { PageStrip(model: model).frame(width: 190) }
        VStack(spacing: 0) {
          if model.reviewing {
            PageReview(model: model)
          } else {
            ScanPreview(model: model, gold: gold)
          }
          CaptureControls(model: model)
        }
        if !model.reviewing { CaptureSettings(model: model).frame(width: 290) }
      }
      }
      Divider()
      SessionFooter(model: model)
    }.background(Color(nsColor: .windowBackgroundColor))
      .frame(minWidth: 900, minHeight: 640)
      .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.didStopRunningNotification, object: model.session)
        .receive(on: DispatchQueue.main)) { _ in
          model.connected = false
          model.autoCapture = false
        }
      .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.runtimeErrorNotification, object: model.session)
        .receive(on: DispatchQueue.main)) { _ in
          model.connected = false
          model.autoCapture = false
        }
      .alert(
        "Scanner",
        isPresented: Binding(
          get: { model.error != nil },
          set: { if !$0 { model.error = nil } })
      ) {
        Button(L10n.text("OK")) { model.error = nil }
      } message: {
        Text(model.error ?? "")
      }
      .sheet(isPresented: $rename) {
        VStack(alignment: .leading, spacing: 20) {
          Text(L10n.text("Name your document")).font(.title2)
          TextField(L10n.text("Document name"), text: $draftTitle)
          if let error = model.error { Text(error).foregroundStyle(.red).font(.callout) }
          HStack {
            Button(L10n.text("Cancel")) { rename = false }.keyboardShortcut(.cancelAction)
            Spacer()
            Button(L10n.text("Save name")) {
              var next = model.document
              next.title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
              do {
                try model.commit(next)
                rename = false
              } catch { model.error = error.localizedDescription }
            }.keyboardShortcut(.defaultAction)
              .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }.padding(24).frame(width: 380)
          .onAppear { draftTitle = model.document.title }
      }
      .sheet(isPresented: $model.showNewItem) { ItemEditor(model: model, creating: true) }
      .sheet(isPresented: $model.showMetadata) { ItemEditor(model: model, creating: false) }
      .sheet(isPresented: $model.showLabel) { LabelEditor(model: model) }
      .sheet(isPresented: $model.showSessions, onDismiss: {
        let action = browserNextAction
        browserNextAction = nil
        switch action {
        case .openFolder: model.openSession()
        case .newItem: model.prepareNewItem()
        case nil: break
        }
      }) { SessionBrowser(model: model, nextAction: $browserNextAction) }
      .sheet(isPresented: $model.showRejected) { RejectedReview(model: model) }
      .sheet(isPresented: $model.showExport, onDismiss: {
        if reviewRejectedAfterExport {
          reviewRejectedAfterExport = false
          model.showRejected = true
        }
      }) { ExportReview(model: model, reviewRejectedAfterDismiss: $reviewRejectedAfterExport) }
      .sheet(isPresented: $model.showCrop) { CropEditor(model: model) }
      .sheet(isPresented: $model.showSheetGroups) { SheetGroupEditor(model: model) }
      .sheet(isPresented: $model.showFraming) { FramingPreview(model: model) }
      .background(USBButtonWindow { usbWindow = $0 })
      .onReceive(USBButton.shared.actions) { action in
        guard NSApp.isActive, let window = usbWindow, NSApp.keyWindow === window,
          window.attachedSheet == nil, NSApp.modalWindow == nil, !rename else { return }
        model.performUSBAction(action)
      }
      .onAppear {
        USBButton.shared.start()
        if model.document.metadata != nil && model.document.pages.isEmpty {
          model.showCatalog()
        } else if !model.document.pages.isEmpty { model.beginReview() }
      }
  }
}
