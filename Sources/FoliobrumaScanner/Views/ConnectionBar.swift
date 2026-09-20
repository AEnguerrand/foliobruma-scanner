import SwiftUI
import AVFoundation

struct ConnectionBar: View {
  @ObservedObject var model: Scanner
  @ObservedObject private var account = CloudAccount.shared
  @State private var showCamera = false
  @State private var showAccount = false

  var body: some View {
    HStack(spacing: 16) {
      Button { showCamera.toggle() } label: {
        Label(L10n.text(model.connected ? "Camera connected" : "Camera not connected"),
              systemImage: model.connected ? "video.fill" : "video.slash")
          .foregroundStyle(model.connected ? .green : .secondary)
      }.popover(isPresented: $showCamera) {
        VStack(alignment: .leading, spacing: 14) {
          Text(L10n.text("Camera connection")).font(.headline)
          Picker(L10n.text("Camera"), selection: $model.deviceID) {
            if model.devices.isEmpty { Text(L10n.text("No camera found")).tag("") }
            ForEach(model.devices, id: \.uniqueID) { Text($0.localizedName).tag($0.uniqueID) }
          }
          if model.connected { Text(model.resolution).foregroundStyle(.secondary) }
          HStack {
            Button(L10n.text("Refresh camera list"), action: model.refreshCameras)
            Button(L10n.text("Connect camera")) { model.connect(); showCamera = false }
              .disabled(model.devices.isEmpty)
          }
        }.padding(20).frame(width: 380).disabled(model.busy)
      }
      Divider().frame(height: 16)
      Button { showAccount.toggle() } label: {
        Label(L10n.text(account.user == nil ? "SaaS · Signed out" : "SaaS · Signed in"),
              systemImage: account.user == nil ? "person.crop.circle.badge.questionmark" : "person.crop.circle.badge.checkmark")
      }.help(account.user?.email ?? L10n.text("Connect to Foliobruma"))
        .popover(isPresented: $showAccount) {
          Form { CloudSettings() }.formStyle(.grouped).frame(width: 480, height: 500)
        }
      if account.working { ProgressView().controlSize(.small) }
      if account.user != nil {
        Text(account.organisations.first { $0.id == account.organisationID }?.name ?? L10n.text("Select an archive"))
          .lineLimit(1).truncationMode(.middle).frame(maxWidth: 180, alignment: .leading)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      Label(L10n.text(account.automatic ? "Upload on finish" : "Upload off"),
            systemImage: "arrow.up.doc")
      Label(L10n.text(account.printLabel ? "Labels on" : "Labels off"), systemImage: "printer")
    }.font(.caption).buttonStyle(.plain).padding(.horizontal, 16).padding(.vertical, 9)
      .background(Color(white: 0.13))
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
  }
}
