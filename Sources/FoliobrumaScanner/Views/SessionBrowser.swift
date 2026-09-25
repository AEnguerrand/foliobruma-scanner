import SwiftUI

struct SessionBrowser: View {
  enum NextAction { case openFolder, newItem }
  @ObservedObject var model: Scanner
  @Binding var nextAction: NextAction?
  @State private var search = ""
  @State private var currentBatch = false
  @State private var needsReview = false
  @State private var selection: URL?
  @State private var sortOrder = [KeyPathComparator(\SavedSession.modified, order: .reverse)]
  var body: some View {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    let matchingSessions = model.sessions.filter {
      (!currentBatch || $0.batchID == model.document.metadata?.batchID)
        && (!needsReview || $0.needsReview)
        && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
        || ($0.reference ?? "").localizedCaseInsensitiveContains(query)
        || ($0.batchName ?? "").localizedCaseInsensitiveContains(query))
    }.sorted(using: sortOrder)
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text(L10n.text("Documents on this Mac")).font(.title2)
        Spacer()
        Button(L10n.text("Done")) { model.showSessions = false }.keyboardShortcut(.cancelAction)
      }
      HStack {
        TextField(L10n.text("Find a document"), text: $search)
          .accessibilityLabel(L10n.text("Find a document"))
        if !search.isEmpty {
          Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
            .buttonStyle(.plain).help(L10n.text("Clear search"))
            .accessibilityLabel(L10n.text("Clear search"))
        }
      }
      HStack {
        if model.document.metadata?.batchID != nil {
          Toggle(L10n.text("Current batch"), isOn: $currentBatch)
        }
        Toggle(L10n.text("Needs review"), isOn: $needsReview)
        Spacer()
        Text(L10n.format("%ld documents", matchingSessions.count)).foregroundStyle(.secondary)
      }.toggleStyle(.checkbox)
      Group {
        if model.loadingSessions {
          ProgressView(L10n.text("Loading documents…"))
        } else if model.sessions.isEmpty {
          ContentUnavailableView(
            L10n.text("No saved documents"), systemImage: "books.vertical",
            description: Text(L10n.text("Create a document, or open a saved session folder.")))
        } else if matchingSessions.isEmpty {
          ContentUnavailableView(L10n.text("No matching documents"), systemImage: "magnifyingglass",
            description: Text(L10n.text("Try another title, reference, or batch name.")))
        } else {
          Table(matchingSessions, selection: $selection, sortOrder: $sortOrder) {
            TableColumn(L10n.text("Document"), value: \.title) { item in
              Text(item.title).lineLimit(1)
            }.width(min: 160, ideal: 230)
            TableColumn(L10n.text("Reference"), value: \.referenceLabel) { Text($0.reference ?? "") }
              .width(min: 80, ideal: 100)
            TableColumn(L10n.text("Pages"), value: \.pageCount) { Text(String($0.pageCount)).monospacedDigit() }
              .width(50)
            TableColumn(L10n.text("Status"), value: \.reviewOrder) { item in
              if item.needsReview {
                Label(L10n.text("Needs review"), systemImage: "exclamationmark.triangle")
              } else if item.folder.resolvingSymlinksInPath() == model.folder.resolvingSymlinksInPath() {
                Text(L10n.text("Current"))
              } else { Text(L10n.text("Saved")) }
            }.width(min: 90, ideal: 110)
            TableColumn(L10n.text("Modified"), value: \.modified) { Text($0.modified, style: .date) }
              .width(min: 80, ideal: 100)
          }
          .contextMenu(forSelectionType: URL.self) { ids in
            if let folder = ids.first {
              Button(L10n.text("Open")) { model.openSession(at: folder) }
            }
          } primaryAction: { ids in
            if let folder = ids.first { model.openSession(at: folder) }
          }
        }
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
      HStack {
        Button(L10n.text("Open session folder…")) {
          nextAction = .openFolder
          model.showSessions = false
        }
        Spacer()
        Button(L10n.text("New item…")) {
          nextAction = .newItem
          model.showSessions = false
        }
        Button(L10n.text("Open")) {
          if let selection { model.openSession(at: selection) }
        }.keyboardShortcut(.defaultAction).disabled(selection == nil)
          .buttonStyle(.borderedProminent)
      }
    }.padding(24).frame(width: 840, height: 560)
      .onAppear { currentBatch = model.document.metadata?.batchID != nil }
      .onChange(of: search) { selection = nil }
      .onChange(of: currentBatch) { selection = nil }
      .onChange(of: needsReview) { selection = nil }
  }
}
