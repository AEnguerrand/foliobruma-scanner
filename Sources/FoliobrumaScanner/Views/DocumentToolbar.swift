import SwiftUI

struct DocumentToolbar: View {
  @ObservedObject var model: Scanner
  @Binding var rename: Bool
  var body: some View {
    HStack(spacing: 16) {
      BrandIcon().frame(width: 34, height: 34)
        .accessibilityHidden(true)
      Button(action: model.browseSessions) { Label(L10n.text("Documents"), systemImage: "books.vertical") }
        .keyboardShortcut("o").disabled(model.busy)
      VStack(alignment: .leading, spacing: 3) {
        Menu(model.document.title) {
          Button(L10n.text("Rename document…")) {
            model.autoCapture = false
            rename = true
          }
          Button(L10n.text("New document"), action: model.newDocument).keyboardShortcut("n")
          Button(L10n.text("Open session folder…"), action: model.openSession)
        }.font(.headline).disabled(model.busy)
        Text(L10n.format("Pages: %ld · Local only", model.document.pages.count)).font(.caption).foregroundStyle(
          .secondary)
      }.frame(maxWidth: 240, alignment: .leading)
      Spacer()
      Picker(
        L10n.text("Workspace"),
        selection: Binding(
          get: { model.reviewing },
          set: {
            if $0 { model.beginReview() } else { model.showCamera() }
          })
      ) {
        Text(L10n.text("Scan")).tag(false)
        Text(L10n.text("Review")).tag(true)
      }.pickerStyle(.segmented).labelsHidden().frame(minWidth: 210).disabled(model.busy)
      Button(action: model.prepareExport) {
        Label(L10n.text("Export PDF"), systemImage: "square.and.arrow.up")
      }
      .keyboardShortcut("e").disabled(model.document.pages.isEmpty || model.busy)
      SettingsLink {
        Image(systemName: "gearshape")
      }
      .help(L10n.text("Settings"))
      .accessibilityLabel(L10n.text("Settings"))
    }.padding(16).background(Color(white: 0.14))
  }
}
