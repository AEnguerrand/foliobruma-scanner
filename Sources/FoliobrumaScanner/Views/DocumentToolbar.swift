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
        Menu(model.document.displayTitle) {
          Button(L10n.text("Rename document…")) {
            model.autoCapture = false
            rename = true
          }
          Button(L10n.text("New item…"), action: model.prepareNewItem).keyboardShortcut("n")
          Button(L10n.text("Edit details…"), action: model.showItemMetadata)
          Button(L10n.text("Create label…"), action: model.showItemLabel)
          Button(L10n.text("Open session folder…"), action: model.openSession)
        }.font(.headline).disabled(model.busy)
        Text(L10n.format("Pages: %ld · Local only", model.document.pages.count)).font(.caption).foregroundStyle(
          .secondary)
      }.frame(maxWidth: 240, alignment: .leading)
      Spacer()
      if model.document.metadata?.batchID != nil {
        Button(L10n.text("Next letter"), action: model.nextLetter).disabled(model.busy)
      }
      Picker(
        L10n.text("Workspace"),
        selection: Binding(
          get: { model.metadataWorkspace ? "metadata" : (model.reviewing ? "review" : "scan") },
          set: {
            switch $0 {
            case "metadata": model.showCatalog()
            case "review": model.beginReview()
            default: model.showCamera()
            }
          })
      ) {
        Text(L10n.text("Details")).tag("metadata")
        Text(L10n.text("Scan")).tag("scan")
        Text(L10n.text("Review")).tag("review")
      }.pickerStyle(.segmented).labelsHidden().frame(minWidth: 240).disabled(model.busy)
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
