import SwiftUI

struct LocationLabelView: View {
  @ObservedObject var model: LocationLabelPrinter
  let close: () -> Void
  @State private var confirmReprint = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(L10n.text("Binder or box label")).font(.title2)
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if let request = model.request {
            Text(request.title).font(.headline).textSelection(.enabled)
            Text(request.link).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
          }
          if let label = model.label, let qr = model.qr {
            LocationLabelPreview(label: label, qr: qr).id(label)
              .frame(width: DocumentLabel.size.width, height: DocumentLabel.size.height)
              .scaleEffect(2.4)
              .frame(width: DocumentLabel.size.width * 2.4, height: DocumentLabel.size.height * 2.4)
              .frame(maxWidth: .infinity)
              .accessibilityLabel(L10n.text("Label preview"))
          }
          Text(L10n.text("DK-22205 · 62 × 25 mm · Black on white. Long text is shortened on the label. The QR contains the full link."))
            .font(.caption).foregroundStyle(.secondary)
          Text(L10n.text("Connect one Brother QL-600 by USB and load a DK-22205 roll. This label does not change the current scan."))
            .font(.callout)
          if model.state == .pending {
            Text(L10n.text("Print result unknown. Check the printer before sending another label."))
              .foregroundStyle(.orange)
          } else if model.state == .submitted {
            Text(L10n.text("This location label was already sent. Reprint sends another copy."))
              .foregroundStyle(.secondary)
          }
          if model.printed { Text(L10n.text("QL-600 confirmed label printed")).foregroundStyle(.secondary) }
          if let failure = model.failure {
            Text(failure).foregroundStyle(.red)
            Button(L10n.text("Try again")) { model.retryPreparation() }
          }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
      }
      Divider()
      HStack {
        Button(L10n.text("Done"), action: close).keyboardShortcut(.cancelAction)
        Spacer()
        if model.printing { ProgressView().controlSize(.small) }
        Button(L10n.text(model.state == nil ? "Print with QL-600" : "Reprint with QL-600…")) {
          if model.state != nil { confirmReprint = true }
          else { Task { await model.printLabel() } }
        }.buttonStyle(.borderedProminent)
          .disabled(model.qr == nil || model.failure != nil)
      }
    }.padding(24).frame(minWidth: 520, minHeight: 380)
      .disabled(model.printing)
      .confirmationDialog(L10n.text("Print another copy?"), isPresented: $confirmReprint, titleVisibility: .visible) {
        Button(L10n.text("Reprint")) { Task { await model.printLabel(reprint: true) } }
        Button(L10n.text("Cancel"), role: .cancel) {}
      } message: {
        Text(L10n.text("This label was already sent or its result is unknown. Check the sheet and printer first. Reprint sends another copy of the same label."))
      }
  }
}

private struct LocationLabelPreview: NSViewRepresentable {
  let label: DocumentLabel
  let qr: NSImage
  func makeNSView(context: Context) -> DocumentLabelView { DocumentLabelView(label: label, qr: qr) }
  func updateNSView(_ view: DocumentLabelView, context: Context) {}
}
