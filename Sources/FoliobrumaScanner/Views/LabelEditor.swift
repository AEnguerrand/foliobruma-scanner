import SwiftUI
import UniformTypeIdentifiers

struct LabelEditor: View {
  @ObservedObject var model: Scanner
  @Environment(\.dismiss) private var dismiss
  @State private var custom = false
  @State private var itemLink = ""
  @State private var customLink = ""
  @State private var title = ""
  @State private var subtitle = ""
  @State private var failure: String?
  @State private var saved = false
  @State private var qr: NSImage?
  @State private var renderedLink = ""

  private var link: String { custom ? customLink : itemLink }
  private var label: DocumentLabel { DocumentLabel(title: title, subtitle: subtitle, link: link) }
  private var ready: Bool { valid && qr != nil && renderedLink == link }
  private var valid: Bool { DocumentLabel.validURL(link) != nil }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(L10n.text("Create label")).font(.title2)
      Picker(L10n.text("Label destination"), selection: $custom) {
        Text(L10n.text("Item link")).tag(false)
        Text(L10n.text("Custom link")).tag(true)
      }.pickerStyle(.segmented)
      Text(L10n.text(custom
        ? "Custom labels are not saved with this item."
        : "Paste the existing permanent link from foliobruma.com. This app does not upload or publish items."))
        .font(.callout).foregroundStyle(.secondary)
      TextField("https://foliobruma.com/d/…", text: custom ? $customLink : $itemLink)
        .accessibilityLabel(L10n.text("HTTPS link"))
      TextField(L10n.text("Label title"), text: $title)
      TextField(L10n.text("Second line (optional)"), text: $subtitle)
      Group {
        if ready, let qr {
          LabelPreview(label: label, qr: qr).id(label)
            .frame(width: DocumentLabel.size.width, height: DocumentLabel.size.height)
            .scaleEffect(2.4)
            .frame(width: DocumentLabel.size.width * 2.4, height: DocumentLabel.size.height * 2.4)
            .accessibilityLabel(L10n.text("Label preview"))
        } else if valid {
          ProgressView().frame(maxWidth: .infinity, minHeight: 160)
        } else {
          Text(L10n.text("Enter an HTTPS link of 100 bytes or fewer to preview the QR code."))
            .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 160)
        }
      }.frame(maxWidth: .infinity)
      Text(L10n.text("DK-22205 · 62 × 25 mm · Black on white. Long text is shortened on the label. The QR contains the full link."))
        .font(.caption).foregroundStyle(.secondary)
      Text(L10n.text("Select the QL-600 and 62 × 25 mm paper in the print dialog. Use 100% scale. Test one label with your phone."))
        .font(.caption).foregroundStyle(.secondary)
      if let failure { Text(failure).foregroundStyle(.red) }
      if saved { Text(L10n.text("Item link saved")).foregroundStyle(.secondary) }
      HStack {
        Button(L10n.text("Done")) { dismiss() }.keyboardShortcut(.cancelAction)
        if !custom {
          Button(L10n.text("Save item link")) { saveLink() }.disabled(!valid || model.busy)
        }
        Spacer()
        Button(L10n.text("Save label PDF…")) { savePDF() }.disabled(!ready)
        Button(L10n.text("Print…")) {
          if ready, let qr { DocumentLabelView(label: label, qr: qr).printLabel() }
        }.buttonStyle(.borderedProminent).disabled(!ready)
      }
    }.padding(24).frame(width: 610)
      .onAppear {
        itemLink = model.document.metadata?.webLink ?? ""
        title = model.document.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { title = model.document.metadata?.batchName ?? "" }
        if title.isEmpty { title = model.document.displayTitle }
        subtitle = model.document.metadata?.reference ?? ""
      }
      .onChange(of: itemLink) { saved = false }
      .task(id: link) {
        qr = nil
        renderedLink = ""
        guard valid else { return }
        let snapshot = label
        let image = await Task.detached(priority: .userInitiated) { snapshot.qrImage() }.value
        guard !Task.isCancelled else { return }
        qr = image
        renderedLink = snapshot.link
        if image == nil { failure = L10n.text("Could not create the QR code.") }
      }
  }

  private func saveLink() {
    guard let url = DocumentLabel.validURL(itemLink) else { return }
    do {
      var details = model.document.metadata ?? ItemMetadata()
      details.webLink = url.absoluteString
      try model.saveMetadata(title: model.document.title, metadata: details)
      saved = true
      failure = nil
    } catch { failure = error.localizedDescription }
  }

  private func savePDF() {
    guard ready, let qr else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.pdf]
    panel.nameFieldStringValue = "label.pdf"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    let view = DocumentLabelView(label: label, qr: qr)
    do {
      try view.dataWithPDF(inside: view.bounds).write(to: url, options: .atomic)
      failure = nil
    } catch { failure = error.localizedDescription }
  }
}

private struct LabelPreview: NSViewRepresentable {
  let label: DocumentLabel
  let qr: NSImage
  func makeNSView(context: Context) -> DocumentLabelView { DocumentLabelView(label: label, qr: qr) }
  func updateNSView(_ nsView: DocumentLabelView, context: Context) {}
}
