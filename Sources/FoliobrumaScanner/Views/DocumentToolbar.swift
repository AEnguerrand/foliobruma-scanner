import SwiftUI

struct DocumentToolbar: View {
  @ObservedObject var model: Scanner
  @Binding var rename: Bool
  @State private var showUpload = false
  @ObservedObject private var account = CloudAccount.shared
  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 16) {
        Button(action: model.browseSessions) {
          Label(L10n.text("Documents"), systemImage: "sidebar.left")
        }
        .keyboardShortcut("o").disabled(model.busy)
        .buttonStyle(.borderless)
        Divider().frame(height: 24)
        VStack(alignment: .leading, spacing: 4) {
          Menu(model.document.displayTitle) {
            Button(L10n.text("Rename document…")) {
              model.autoCapture = false
              rename = true
            }
            Button(L10n.text("New item…"), action: model.prepareNewItem).keyboardShortcut("n")
            Button(L10n.text("Edit details…"), action: model.showItemMetadata)
            Button(L10n.text("Create label…"), action: model.showItemLabel)
            Button(L10n.text("Clear upload record…"), action: model.clearCloudUpload)
            Group {
              Button(L10n.text("Confirm label handled"), action: model.confirmSheetLabelHandled)
            }
            Button(L10n.text("Open session folder…"), action: model.openSession)
          }.menuStyle(.borderlessButton).font(.headline).disabled(model.busy)
          Text(L10n.format(model.uploadOnFinish ? "Pages: %ld · Upload on finish" : "Pages: %ld · Auto upload off", model.document.pages.count))
            .font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: 300, alignment: .leading)
        Spacer(minLength: 16)
        SettingsLink { Image(systemName: "gearshape") }
          .buttonStyle(.borderless)
          .help(L10n.text("Settings"))
          .accessibilityLabel(L10n.text("Settings"))
        if account.api.baseURL != CloudAPI.origin {
          Text("DEV · " + (account.api.baseURL.host ?? ""))
            .font(.caption).foregroundStyle(.orange)
            .help(account.api.baseURL.absoluteString)
        }
        FoliobrumaConnectionButton(model: model)
      }.padding(.horizontal, 20).padding(.vertical, 14)
      Divider()
      HStack(spacing: 12) {
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
        }.pickerStyle(.segmented).labelsHidden().frame(width: 240).disabled(model.busy)
        Spacer(minLength: 16)
        if model.document.metadata?.batchID != nil && !model.isSheetBatch {
          Button(L10n.text("Next letter"), action: model.nextLetter).disabled(model.busy)
            .help(L10n.text("Start another letter with the same batch details."))
        }
        Button(action: model.prepareExport) {
          Label(L10n.text("Export PDF"), systemImage: "square.and.arrow.up")
        }
        .keyboardShortcut("e").disabled(model.document.pages.isEmpty || model.busy)
        Button {
          model.autoCapture = false
          showUpload = true
        } label: {
          Label(L10n.text("Upload to Foliobruma"), systemImage: "icloud.and.arrow.up")
        }
        .disabled(model.busy || model.document.pages.isEmpty)
        .help(L10n.text("Upload this item without turning on automatic upload."))
        Button(L10n.text(model.isSheetBatch ? "Finish sheet" : "Finish item")) {
          if model.isSheetBatch { model.finishSheet() } else { model.finishItem() }
        }
          .buttonStyle(.borderedProminent)
          .disabled(model.busy || model.document.pages.isEmpty)
      }.padding(.horizontal, 20).padding(.vertical, 10)
    }.background(Color(nsColor: .controlBackgroundColor))
      .sheet(isPresented: $showUpload) { ManualUploadView(model: model) }
      .task { await account.restore() }
  }
}
