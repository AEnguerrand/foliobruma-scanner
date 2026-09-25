import ScannerCore
import SwiftUI

struct ItemEditor: View {
  @ObservedObject var model: Scanner
  let creating: Bool
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var namePrefix = ""
  @State private var details = ItemMetadata()
  private enum Workflow: String, CaseIterable {
    case document = "One document"
    case sheets = "Batch of sheets"
    case letters = "Batch of letters"
    case record = "Details only"
  }
  @State private var workflow = Workflow.document
  @State private var showDetails = false
  private var sheetBatch: Bool { workflow == .sheets }
  private var letterBatch: Bool { workflow == .letters }
  @State private var failure: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(L10n.text(creating ? "New item" : "Item details")).font(.title2)
      Form {
        Section(L10n.text("Document")) {
          if creating {
            Picker(L10n.text("Workflow"), selection: $workflow) {
              ForEach(Workflow.allCases, id: \.self) { Text(L10n.text($0.rawValue)).tag($0) }
            }
            if sheetBatch {
              Text(L10n.text("Scan all sides of one sheet, then choose Finish sheet. Each sheet gets one reference."))
                .font(.caption).foregroundStyle(.secondary)
            }
          }
          if !details.reference.isEmpty {
            LabeledContent(L10n.text("Reference"), value: details.reference)
          }
          if letterBatch || sheetBatch || details.batchID != nil {
            TextField(L10n.text("Batch name"), text: $details.batchName)
            TextField(L10n.text("Name prefix (optional)"), text: $namePrefix)
            Text(L10n.text("Names use this prefix and a unique reference unless you enter a title."))
              .font(.caption).foregroundStyle(.secondary)
            LabeledContent(L10n.text("Name preview"), value: namePreview)
            if !creating {
              Text(L10n.text(sheetBatch || details.sheetBatch == true
                ? "Finish sheet copies the batch name, location, and tags to the next sheet."
                : "Next letter copies the batch name, location, and tags. Earlier letters do not change."))
                .font(.caption).foregroundStyle(.secondary)
            }
          }
          if !creating || (!letterBatch && !sheetBatch) {
            TextField(L10n.text("Title (optional)"), text: $title)
            Text(L10n.text("Leave the title empty to use the automatic reference."))
              .font(.caption).foregroundStyle(.secondary)
          }
          if !letterBatch && !sheetBatch && details.batchID == nil {
            Picker(L10n.text("Item type"), selection: $details.kind) {
              ForEach(["Document", "Folder", "Book", "Letter"], id: \.self) {
                Text(L10n.text($0)).tag($0)
              }
            }
          }
        }
        DisclosureGroup(L10n.text("Optional details"), isExpanded: $showDetails) {
          if creating && (letterBatch || sheetBatch) {
            TextField(L10n.text("Title (optional)"), text: $title)
          }
          TextField(L10n.text("Author or sender"), text: $details.author)
          TextField(L10n.text("Date or period"), text: $details.period)
          TextField(L10n.text("Physical location"), text: $details.location)
          TextField(L10n.text("Tags"), text: $details.tags)
          TextField(L10n.text("Notes"), text: $details.notes, axis: .vertical).lineLimit(3...6)
        }
      }.formStyle(.grouped)
      if let failure { Text(failure).foregroundStyle(.red) }
      HStack {
        Button(L10n.text("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
        Spacer()
        Button(L10n.text(creating ? (sheetBatch || letterBatch ? "Start batch" : (workflow == .record ? "Create item" : "Start scanning")) : "Save details")) { save() }
          .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).disabled(model.busy)
      }
    }.padding(24).frame(width: 560, height: creating && !showDetails ? (sheetBatch || letterBatch ? 520 : 420) : 650)
      .onAppear {
        if !creating {
          showDetails = true
          title = model.document.title
          details = model.document.metadata ?? ItemMetadata()
          namePrefix = details.namePrefix ?? ""
        }
      }
  }

  private var namePreview: String {
    var preview = details
    preview.namePrefix = namePrefix
    if preview.reference.isEmpty { preview.reference = "LET-0001" }
    return ScanDocument(title: title, metadata: preview).displayTitle
  }

  private func save() {
    do {
      let prefix = namePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
      details.namePrefix = prefix.isEmpty || (creating && !letterBatch && !sheetBatch) ? nil : prefix
      if creating {
        var next = details
        if letterBatch { next.batchID = UUID().uuidString; next.kind = "Letter" }
        if sheetBatch { next.batchID = UUID().uuidString; next.kind = "Sheet"; next.sheetBatch = true }
        try model.createItem(title: title, metadata: next, scanPages: workflow != .record)
      } else {
        try model.saveMetadata(title: title, metadata: details)
      }
      dismiss()
    } catch { failure = error.localizedDescription }
  }
}
