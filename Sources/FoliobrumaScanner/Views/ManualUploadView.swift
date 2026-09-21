import SwiftUI

struct ManualUploadView: View {
  @ObservedObject var model: Scanner
  @ObservedObject private var account = CloudAccount.shared
  @State private var printLabel = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Text(L10n.text("Upload to Foliobruma")).font(.title2.weight(.semibold))
        Text(model.document.displayTitle).font(.headline).lineLimit(2)
        Text(L10n.format("Upload %ld pages as one PDF. Automatic upload stays unchanged.", model.document.pages.count))
          .font(.callout).foregroundStyle(.secondary)
      }.padding(20)
      Divider()
      Form {
        CloudSettings()
        SessionFinishSettings(model: model, showAutomation: false)
        Section {
          Toggle(L10n.text("Print a label after upload"), isOn: $printLabel)
            .disabled(account.working)
        }
      }.formStyle(.grouped)
      Divider()
      HStack {
        Button(L10n.text("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
        Spacer()
        Button(L10n.text("Upload now")) {
          model.finishItem(uploadRequested: true, printRequested: printLabel)
          dismiss()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!account.ready || account.working || model.busy || model.document.pages.isEmpty)
      }.padding(20)
    }.frame(width: 480, height: 720)
      .onAppear { printLabel = model.printOnFinish }
  }
}
