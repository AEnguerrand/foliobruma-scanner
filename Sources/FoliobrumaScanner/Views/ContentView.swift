import SwiftUI

struct ContentView: View {
  @StateObject var model = Scanner()
  @State var rename = false
  let gold = Color(red: 1, green: 0.74, blue: 0.27)
  var body: some View {
    VStack(spacing: 0) {
      DocumentToolbar(model: model, rename: $rename)
      ScanPreview(model: model, gold: gold)
      PageStrip(model: model, gold: gold)
      CaptureControls(model: model)
      Divider()
      SessionFooter(model: model)
    }.background(Color(white: 0.1)).preferredColorScheme(.dark).tint(gold).frame(
      minWidth: 1050, minHeight: 720
    )
    .alert(
      "Foliobruma Scanner",
      isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
    ) {
      Button("OK") { model.error = nil }
    } message: {
      Text(model.error ?? "")
    }
    .sheet(isPresented: $rename) {
      VStack(spacing: 20) {
        Text("Name your document").font(.title2)
        TextField("Document name", text: $model.document.title)
        Button("Done") {
          do {
            try model.persist()
            rename = false
          } catch { model.error = error.localizedDescription }
        }.keyboardShortcut(.defaultAction)
      }.padding(30).frame(width: 380)
    }
    .onAppear {
      if model.devices.contains(where: { $0.localizedName.contains("IRIS") }) { model.connect() }
    }
  }
}
