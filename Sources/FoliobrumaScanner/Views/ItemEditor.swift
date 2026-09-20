import SwiftUI

struct ItemEditor: View {
  @ObservedObject var model: Scanner
  let creating: Bool
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var details = ItemMetadata()
  @State private var scanPages = false
  @State private var letterBatch = false
  @State private var failure: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(L10n.text(creating ? "New item" : "Item details")).font(.title2)
      Form {
        Section(L10n.text("Document")) {
          if creating {
            Picker(L10n.text("Start with"), selection: $scanPages) {
              Text(L10n.text("Metadata only")).tag(false)
              Text(L10n.text("Scan pages")).tag(true)
            }.pickerStyle(.segmented)
            Toggle(L10n.text("Start a letter batch"), isOn: $letterBatch)
          }
          if !details.reference.isEmpty {
            LabeledContent(L10n.text("Reference"), value: details.reference)
          }
          if letterBatch || details.batchID != nil {
            TextField(L10n.text("Batch name"), text: $details.batchName)
            Text(L10n.text("Next letter copies the batch name, location, and tags. Earlier letters do not change."))
              .font(.caption).foregroundStyle(.secondary)
          }
          TextField(L10n.text("Title (optional)"), text: $title)
          Text(L10n.text("Leave the title empty to use the automatic reference."))
            .font(.caption).foregroundStyle(.secondary)
          if !letterBatch && details.batchID == nil {
            Picker(L10n.text("Item type"), selection: $details.kind) {
              ForEach(["Document", "Folder", "Book", "Letter"], id: \.self) {
                Text(L10n.text($0)).tag($0)
              }
            }
          }
        }
        Section(L10n.text("Description")) {
          TextField(L10n.text("Author or sender"), text: $details.author)
          TextField(L10n.text("Date or period"), text: $details.period)
        }
        Section(L10n.text("Filing")) {
          TextField(L10n.text("Physical location"), text: $details.location)
          TextField(L10n.text("Tags"), text: $details.tags)
          TextField(L10n.text("Notes"), text: $details.notes, axis: .vertical).lineLimit(3...6)
        }
      }.formStyle(.grouped)
      if let failure { Text(failure).foregroundStyle(.red) }
      HStack {
        Button(L10n.text("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
        Spacer()
        Button(L10n.text(creating ? "Create item" : "Save details")) { save() }
          .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).disabled(model.busy)
      }
    }.padding(24).frame(width: 560, height: 650)
      .onAppear {
        if !creating {
          title = model.document.title
          details = model.document.metadata ?? ItemMetadata()
        }
      }
  }

  private func save() {
    do {
      if creating {
        var next = details
        if letterBatch { next.batchID = UUID().uuidString; next.kind = "Letter" }
        try model.createItem(title: title, metadata: next, scanPages: scanPages)
      } else {
        try model.saveMetadata(title: title, metadata: details)
      }
      dismiss()
    } catch { failure = error.localizedDescription }
  }
}
