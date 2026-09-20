import AppKit
import SwiftUI

struct DocumentToolbar: View {
  @ObservedObject var model: Scanner
  @Binding var rename: Bool
  var body: some View {
    HStack(spacing: 22) {
      Label("Foliobruma Scanner", systemImage: "camera").font(.headline)
      Spacer()
      Menu(model.document.title) {
        Button("Rename document…") { rename = true }
        Button("New document", action: model.newDocument)
        Button("Open saved session…", action: model.openSession)
      }.frame(maxWidth: 210)
      Picker("Mode", selection: $model.book) {
        Label("Book", systemImage: "book").tag(true)
        Label("Letters", systemImage: "envelope").tag(false)
      }.pickerStyle(.segmented).frame(width: 200)
      Picker("Camera", selection: $model.deviceID) {
        ForEach(model.devices, id: \.uniqueID) { Text($0.localizedName).tag($0.uniqueID) }
      }.labelsHidden().frame(width: 220).onChange(of: model.deviceID) {
        if model.connected { model.connect() }
      }
      Button(action: model.exportPDF) { Label("Save PDF", systemImage: "doc") }.disabled(
        model.document.pages.isEmpty || model.busy)
    }.padding(18).background(Color(white: 0.13))
  }
}
