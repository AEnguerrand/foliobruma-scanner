import SwiftUI

struct ItemSummary: View {
  @ObservedObject var model: Scanner
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Label(L10n.text("Item details"), systemImage: "tray.full").font(.title2)
        Text(model.document.displayTitle).font(.largeTitle).textSelection(.enabled)
        if let details = model.document.metadata {
          Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
            row("Reference", details.reference)
            row("Batch name", details.batchName)
            row("Item type", L10n.text(details.kind))
            row("Author or sender", details.author)
            row("Date or period", details.period)
            row("Physical location", details.location)
            row("Tags", details.tags)
            row("Notes", details.notes)
          }.textSelection(.enabled)
        }
        Label(L10n.format("Pages: %ld · Local only", model.document.pages.count), systemImage: "internaldrive")
          .foregroundStyle(.secondary)
        HStack {
          Button(L10n.text("Edit details"), action: model.showItemMetadata)
          Button(L10n.text("Add scans"), action: model.showCamera)
          Button(L10n.text("Create label…"), action: model.showItemLabel)
        }
        if model.document.metadata?.batchID != nil {
          Divider()
          Text(L10n.text("Keep all pages of one letter in this item. Use Next letter only when you start another letter."))
          Button(L10n.text("Next letter"), action: model.nextLetter).buttonStyle(.borderedProminent)
        }
      }.padding(32).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
    }.disabled(model.busy)
  }

  @ViewBuilder private func row(_ label: String, _ value: String) -> some View {
    if !value.isEmpty {
      GridRow {
        Text(L10n.text(label)).foregroundStyle(.secondary)
        Text(value).frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}
