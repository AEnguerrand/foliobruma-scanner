import SwiftUI
import AppKit

struct SessionFinishSettings: View {
  @ObservedObject var model: Scanner
  var showAutomation = true
  @State private var printers = NSPrinter.printerNames

  private func binding<T>(_ path: WritableKeyPath<SessionAutomation, T>) -> Binding<T> {
    Binding(get: { (model.document.automation ?? SessionAutomation())[keyPath: path] }, set: {
      var value = model.document.automation ?? SessionAutomation()
      value[keyPath: path] = $0
      model.setSessionAutomation(value)
    })
  }

  var body: some View {
    Section {
      if showAutomation {
        Toggle(L10n.text("Upload automatically"), isOn: binding(\.upload))
        Toggle(L10n.text("Print a label when finished"), isOn: binding(\.printLabel))
          .disabled(!model.uploadOnFinish)
      }
      Picker(L10n.text("Label printer"), selection: binding(\.printerName)) {
        Text(L10n.text("Select a label printer")).tag("")
        Text(verbatim: QL600Printer.destination).tag(QL600Printer.destination)
        ForEach(printers, id: \.self) { Text($0).tag($0) }
        if let name = model.document.automation?.printerName, !name.isEmpty, name != QL600Printer.destination, !printers.contains(name) {
          Text(name + " · " + L10n.text("Unavailable")).tag(name)
        }
      }
      Button(L10n.text("Refresh printers")) { printers = NSPrinter.printerNames }
      Text(L10n.text("One 62 × 25 mm label per finished sheet or book. Use a DK-22205 roll. Printing starts after upload, without a print dialog."))
        .font(.caption).foregroundStyle(.secondary)
      Text(L10n.text("These settings are saved with this session and copied to the next sheet or letter in this batch."))
        .font(.caption).foregroundStyle(.secondary)
    } header: { Text(L10n.text("This session")) }
    .disabled(model.busy)
  }
}
