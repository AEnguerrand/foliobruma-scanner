import ScannerCore
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
  @State private var generating = false
  @State private var printing = false
  @State private var printed = false
  @State private var printState: LabelPrintStore.State?
  @State private var confirmReprint = false
  @State private var directPrint = false
  @State private var stateReadable = false

  private var link: String { DocumentLabel.validURL(custom ? customLink : itemLink)?.absoluteString ?? (custom ? customLink : itemLink) }
  private var label: DocumentLabel { DocumentLabel(title: title, subtitle: subtitle, link: link) }
  private var ready: Bool { valid && qr != nil && renderedLink == link }
  private var valid: Bool { DocumentLabel.validURL(link) != nil }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(L10n.text("Label")).font(.title2)
      Picker(L10n.text("Label destination"), selection: $custom) {
        Text(L10n.text("Item link")).tag(false)
        Text(L10n.text("Custom link")).tag(true)
      }.pickerStyle(.segmented)
      Text(L10n.text(custom
        ? "Custom label text is not saved. Printed links are kept in this session to prevent repeat jobs."
        : "An uploaded item uses its permanent SaaS link. You can also paste an existing HTTPS link."))
        .font(.callout).foregroundStyle(.secondary)
      Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
        field("HTTPS link", text: custom ? $customLink : $itemLink)
        field("Label title", text: $title)
        field("Second line (optional)", text: $subtitle)
      }
      if !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
         let message = DocumentLabel.validationMessage(link) {
        Label(L10n.text(message), systemImage: "exclamationmark.circle")
          .font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
      }
      Group {
        if ready, let qr {
          LabelPreview(label: label, qr: qr).id(label)
            .frame(width: DocumentLabel.size.width, height: DocumentLabel.size.height)
            .scaleEffect(2.4)
            .frame(width: DocumentLabel.size.width * 2.4, height: DocumentLabel.size.height * 2.4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.text("Label preview"))
            .accessibilityValue([label.title, label.subtitle, label.printedLink]
              .filter { !$0.isEmpty }.joined(separator: ", "))
        } else if generating {
          ProgressView(L10n.text("Preparing label…"))
            .frame(maxWidth: .infinity, minHeight: 160)
        } else {
          Text(L10n.text(failure != nil ? "Label preview unavailable" : "Enter a link to preview the label."))
            .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 160)
        }
      }.frame(maxWidth: .infinity)
      Text(L10n.text("DK-22205 · 62 × 25 mm · Black on white. Long text is shortened on the label. The QR contains the full link."))
        .font(.caption).foregroundStyle(.secondary)
      DisclosureGroup(L10n.text("Print setup")) {
        Text(L10n.text("Use Print with QL-600 for direct USB printing. No driver is needed. Load a DK-22205 roll. Test one label with your phone."))
          .font(.callout).foregroundStyle(.secondary)
      }
      if let failure { Text(failure).foregroundStyle(.red) }
      if printState == .pending {
        Label(L10n.text("Print result unknown. Check the printer before sending another label."), systemImage: "exclamationmark.triangle")
          .foregroundStyle(.orange)
        Button(L10n.text("Confirm label handled")) {
          model.confirmSheetLabelHandled()
          refreshPrintState()
        }.disabled(custom || link != model.document.metadata?.webLink)
      } else if printState == .submitted {
        Label(L10n.text("Label already sent. Finish will not print it again."), systemImage: "checkmark.circle")
          .foregroundStyle(.secondary)
      }
      if printed { Text(L10n.text("QL-600 confirmed label printed")).foregroundStyle(.secondary) }
      if saved && !custom { Text(L10n.text("Item link saved")).foregroundStyle(.secondary) }
      HStack {
        Button(L10n.text("Done")) { dismiss() }.keyboardShortcut(.cancelAction)
        if !custom {
          Button(L10n.text("Save item link")) { saveLink() }.disabled(!valid || model.busy)
        }
        Spacer()
        Button(L10n.text("Save label PDF…")) { savePDF() }.disabled(!ready)
        Button(L10n.text(printState == nil ? "Print with QL-600" : "Reprint with QL-600…")) {
          requestPrint(direct: true)
        }.disabled(!ready || !stateReadable || model.busy)
        Button(L10n.text(printState == nil ? "Print…" : "Reprint…")) {
          requestPrint(direct: false)
        }.buttonStyle(.borderedProminent).disabled(!ready || !stateReadable || model.busy)
      }
    }.padding(24).frame(width: 760)
      .disabled(printing)
      .interactiveDismissDisabled(printing)
      .confirmationDialog(L10n.text("Print another copy?"), isPresented: $confirmReprint, titleVisibility: .visible) {
        Button(L10n.text("Reprint")) { printLabel(reprint: true) }
        Button(L10n.text("Cancel"), role: .cancel) {}
      } message: {
        Text(L10n.text("This label was already sent or its result is unknown. Check the sheet and printer first. Reprint sends another copy of the same label."))
      }
      .onAppear {
        itemLink = model.document.metadata?.webLink ?? ""
        title = model.document.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { title = model.document.metadata?.batchName ?? "" }
        if title.isEmpty { title = model.document.displayTitle }
        if let prefix = model.document.metadata?.namePrefix,
           !prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          title = model.document.displayTitle
        }
        subtitle = model.document.metadata?.reference ?? ""
      }
      .onChange(of: itemLink) { saved = false }
      .task(id: link) {
        qr = nil
        renderedLink = ""
        generating = false
        failure = nil
        refreshPrintState()
        guard valid else { return }
        generating = true
        let snapshot = label
        let image = await Task.detached(priority: .userInitiated) { snapshot.qrImage() }.value
        guard !Task.isCancelled else { return }
        generating = false
        qr = image
        renderedLink = snapshot.link
        if image == nil { failure = L10n.text("Could not create the QR code.") }
      }
  }

  private func refreshPrintState() {
    stateReadable = false
    do {
      printState = try LabelPrintStore.state(in: model.folder, link: link)
      stateReadable = true
    } catch { failure = L10n.text(error.localizedDescription) }
  }

  private func requestPrint(direct: Bool) {
    directPrint = direct
    refreshPrintState()
    guard stateReadable else { return }
    if printState != nil { confirmReprint = true }
    else { printLabel(reprint: false) }
  }

  private func printLabel(reprint: Bool) {
    guard ready, let qr, !model.busy else { return }
    printing = true
    model.busy = true
    printed = false
    failure = nil
    let snapshot = label
    Task { @MainActor in
      defer { printing = false; model.busy = false; refreshPrintState() }
      do {
        try await model.printTrackedLabel(snapshot, qr: qr,
          printerName: directPrint ? QL600Printer.destination : "", showPanel: !directPrint, reprint: reprint)
        printed = directPrint
      } catch { failure = L10n.text(error.localizedDescription) }
    }
  }

  private func field(_ name: String, text: Binding<String>) -> some View {
    GridRow {
      Text(L10n.text(name)).foregroundStyle(.secondary)
      TextField("", text: text).accessibilityLabel(L10n.text(name))
        .textFieldStyle(.roundedBorder)
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
    } catch { failure = L10n.text(error.localizedDescription) }
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
    } catch { failure = L10n.text(error.localizedDescription) }
  }
}

private struct LabelPreview: NSViewRepresentable {
  let label: DocumentLabel
  let qr: NSImage
  func makeNSView(context: Context) -> DocumentLabelView { DocumentLabelView(label: label, qr: qr) }
  func updateNSView(_ nsView: DocumentLabelView, context: Context) {}
}
