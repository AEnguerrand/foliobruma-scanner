import SwiftUI

struct ItemSummary: View {
  @ObservedObject var model: Scanner
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("Item details")).font(.subheadline).foregroundStyle(.secondary)
            Text(model.document.displayTitle).font(.largeTitle.weight(.semibold))
              .textSelection(.enabled)
          }
          Spacer()
          Button(L10n.text("Edit details"), action: model.showItemMetadata)
        }
        Divider()
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
        VStack(alignment: .leading, spacing: 16) {
          HStack(spacing: 16) {
            Image(systemName: "doc.on.doc").font(.system(size: 28)).foregroundStyle(.secondary)
              .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
              Text(model.document.pages.isEmpty ? L10n.text("No scans yet") : L10n.format("Pages: %ld", model.document.pages.count))
                .font(.headline)
              Text(L10n.text(model.document.pages.isEmpty ? "Add pages to this item when you are ready." : "Scans are saved on this Mac."))
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button(L10n.text("Add scans"), action: model.showCamera)
              .buttonStyle(.borderedProminent)
          }
          if !model.document.pages.isEmpty {
            Button(L10n.text("Review pages")) { model.beginReview() }
          }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        Button(action: model.showItemLabel) {
          Label(L10n.text("Create label…"), systemImage: "qrcode")
        }.buttonStyle(.borderless)
        if model.document.metadata?.batchID != nil {
          Divider()
          Text(L10n.text(model.isSheetBatch
            ? "Keep the front and back of one sheet in this item. Use Finish sheet before scanning another sheet."
            : "Keep all pages of one letter in this item. Use Next letter only when you start another letter."))
            .font(.callout).foregroundStyle(.secondary)
        }
      }.padding(40).frame(maxWidth: 840, alignment: .leading).frame(maxWidth: .infinity)
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
