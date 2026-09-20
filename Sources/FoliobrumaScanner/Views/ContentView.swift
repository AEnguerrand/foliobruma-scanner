import SwiftUI

struct ContentView: View {
  @StateObject var model = Scanner()
  @State private var rename = false
  @State private var draftTitle = ""
  let gold = Color(red: 1, green: 0.74, blue: 0.27)
  var body: some View {
    VStack(spacing: 0) {
      DocumentToolbar(model: model, rename: $rename)
      Divider()
      HStack(spacing: 0) {
        if model.reviewing { PageStrip(model: model, gold: gold).frame(width: 190) }
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
      Divider()
      SessionFooter(model: model)
    }.background(Color(white: 0.10)).preferredColorScheme(.dark).tint(gold)
      .frame(minWidth: 900, minHeight: 640)
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
      .sheet(isPresented: $model.showSessions) { SessionBrowser(model: model) }
      .sheet(isPresented: $model.showRejected) { RejectedReview(model: model) }
      .sheet(isPresented: $model.showExport) { ExportReview(model: model) }
      .sheet(isPresented: $model.showCrop) { CropEditor(model: model) }
      .sheet(isPresented: $model.showFraming) { FramingPreview(model: model) }
      .onAppear {
        if !model.document.pages.isEmpty { model.beginReview() }
      }
  }
}
