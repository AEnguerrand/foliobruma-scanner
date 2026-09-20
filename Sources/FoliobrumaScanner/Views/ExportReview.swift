import SwiftUI

struct ExportReview: View {
  @ObservedObject var model: Scanner
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(L10n.text("Export PDF")).font(.title2)
      Text(model.document.displayTitle).font(.headline)
      Label(L10n.format("Pages in document order: %ld", model.document.pages.count), systemImage: "doc.on.doc")
      Text(L10n.text("Rotations and crops are included. This PDF contains images, without searchable text."))
        .foregroundStyle(.secondary)
      if !model.rejectedScans.isEmpty {
        Label(
          L10n.format("Rejected photos excluded: %ld.", model.rejectedScans.count),
          systemImage: "exclamationmark.triangle")
        Button(L10n.text("Review rejected scans…")) {
          model.showExport = false
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { model.showRejected = true }
        }
      }
      HStack {
        Button(L10n.text("Cancel")) { model.showExport = false }.keyboardShortcut(.cancelAction)
        Spacer()
        Button(L10n.text("Choose location…"), action: model.exportPDF).buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
      }
    }.padding(24).frame(width: 460)
  }
}
