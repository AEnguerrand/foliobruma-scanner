import ScannerCore
import SwiftUI

struct SheetGroupEditor: View {
  @ObservedObject var model: Scanner
  @Environment(\.dismiss) private var dismiss
  @State private var store = SheetGroupStore(groups: [], snapshot: nil)
  @State private var records: [SheetRecord] = []
  @State private var group = SheetGroup(title: "", sheets: [])
  @State private var search = ""
  @State private var loading = true
  @State private var saving = false
  @State private var failure: String?
  @State private var previewID: String?
  @State private var side = 0

  private var currentID: String { model.folder.lastPathComponent }
  private var existing: Bool { store.groups.contains { $0.id == group.id } }
  private var preview: SheetRecord? { records.first { $0.id == previewID } }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(L10n.text("Group sheets")).font(.title2)
      Text(L10n.text("Link sheets into a letter or document. Labels and scans stay unchanged. Groups are saved on this Mac only."))
        .foregroundStyle(.secondary)
      if loading {
        ProgressView(L10n.text("Loading documents…")).frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        HStack {
          Menu(L10n.text("Choose group")) {
            Button(L10n.text("New group")) { group = SheetGroup(title: "", sheets: []) }
            ForEach(store.groups) { item in
              Button(item.title) { group = item }
            }
          }
          TextField(L10n.text("Group name"), text: $group.title)
        }
        HSplitView {
          VStack(alignment: .leading) {
            TextField(L10n.text("Find a document"), text: $search)
            List {
              ForEach(matchingRecords) { record in
                HStack {
                  Button { toggle(record.id) } label: {
                    Image(systemName: group.sheets.contains(record.id) ? "checkmark.circle.fill" : "circle")
                  }.buttonStyle(.borderless)
                    .accessibilityLabel(L10n.text("Select sheet") + " " + record.document.displayTitle)
                    .disabled(inOtherGroup(record.id))
                  Button { previewID = record.id; side = 0 } label: {
                    VStack(alignment: .leading) {
                      Text(record.document.displayTitle)
                      Text([record.document.metadata?.reference ?? "", record.document.metadata?.batchName ?? ""]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                      if inOtherGroup(record.id) {
                        Text(L10n.text("In another group")).font(.caption).foregroundStyle(.secondary)
                      }
                    }
                  }.buttonStyle(.plain)
                }
              }
            }
          }.frame(minWidth: 200, idealWidth: 240)
          VStack(alignment: .leading) {
            Text(L10n.text("Reading order")).font(.headline)
            List {
              ForEach(Array(group.sheets.enumerated()), id: \.element) { index, id in
                HStack {
                  Button { previewID = id; side = 0 } label: {
                    Text("\(index + 1). " + title(id)).lineLimit(2)
                  }.buttonStyle(.plain)
                  Spacer()
                  Button { group.sheets.swapAt(index, index - 1) } label: { Image(systemName: "arrow.up") }
                    .disabled(index == 0).help(L10n.text("Move earlier"))
                  Button { group.sheets.swapAt(index, index + 1) } label: { Image(systemName: "arrow.down") }
                    .disabled(index == group.sheets.count - 1).help(L10n.text("Move later"))
                  Button { group.sheets.remove(at: index) } label: { Image(systemName: "minus.circle") }
                    .help(L10n.text("Unlink sheet"))
                }.buttonStyle(.borderless)
              }
            }
            Text(L10n.text("Unlinking keeps the sheet and its scans. An empty group is removed when you save."))
              .font(.caption).foregroundStyle(.secondary)
          }.frame(minWidth: 240, idealWidth: 280)
          VStack {
            if let preview, !preview.document.pages.isEmpty {
              Picker(L10n.text("Side"), selection: $side) {
                Text(L10n.text("Front")).tag(0)
                if preview.document.pages.count > 1 { Text(L10n.text("Back")).tag(1) }
              }.pickerStyle(.segmented)
              let page = preview.document.pages[min(side, preview.document.pages.count - 1)]
              ZoomImage(url: preview.folder.appendingPathComponent(page.file), rotation: page.rotation)
            } else {
              Text(L10n.text("Select a sheet to view its scans."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
          }.frame(minWidth: 280, idealWidth: 340)
        }
      }
      if let failure { Text(failure).foregroundStyle(.red).textSelection(.enabled) }
      HStack {
        Button(L10n.text("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
        Spacer()
        Button(L10n.text("Save group")) { save() }
          .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
          .disabled(loading || saving || (!existing && group.sheets.isEmpty)
            || (!group.sheets.isEmpty && group.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
      }
    }.padding(24).frame(width: 960, height: 640).disabled(saving)
      .task {
        let root = model.root
        do {
          let result = try await Task.detached(priority: .userInitiated) {
            (try SheetGroupStore.load(in: root), try SheetRecord.load(in: root))
          }.value
          guard !Task.isCancelled else { return }
          store = result.0
          records = result.1
          group = store.groups.first { $0.sheets.contains(currentID) }
            ?? SheetGroup(title: "", sheets: records.contains { $0.id == currentID } ? [currentID] : [])
          previewID = currentID
          loading = false
        } catch { failure = error.localizedDescription }
      }
  }

  private var matchingRecords: [SheetRecord] {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    return records.filter { query.isEmpty || $0.document.displayTitle.localizedCaseInsensitiveContains(query)
      || ($0.document.metadata?.reference ?? "").localizedCaseInsensitiveContains(query)
      || ($0.document.metadata?.batchName ?? "").localizedCaseInsensitiveContains(query) }
  }
  private func title(_ id: String) -> String {
    records.first { $0.id == id }?.document.displayTitle ?? L10n.text("Sheet unavailable") + " · " + id
  }
  private func inOtherGroup(_ id: String) -> Bool {
    store.groups.contains { $0.id != group.id && $0.sheets.contains(id) }
  }
  private func toggle(_ id: String) {
    if let index = group.sheets.firstIndex(of: id) { group.sheets.remove(at: index) }
    else { group.sheets.append(id) }
  }
  private func save() {
    saving = true
    failure = nil
    let root = model.root
    let selected = group
    let original = store
    Task { @MainActor in
      do {
        store = try await Task.detached(priority: .userInitiated) {
          var updated = original
          try updated.save(selected, in: root)
          return updated
        }.value
        dismiss()
      } catch { failure = error.localizedDescription }
      saving = false
    }
  }
}
