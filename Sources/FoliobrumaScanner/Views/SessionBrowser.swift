import SwiftUI

struct SessionBrowser: View {
  @ObservedObject var model: Scanner
  @State private var search = ""
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text(L10n.text("Documents on this Mac")).font(.title2)
        Spacer()
        Button(L10n.text("Done")) { model.showSessions = false }.keyboardShortcut(.cancelAction)
      }
      TextField(L10n.text("Find a document"), text: $search)
      if model.loadingSessions {
        ProgressView(L10n.text("Loading documents…"))
      } else if model.sessions.isEmpty {
        ContentUnavailableView(
          L10n.text("No saved documents"), systemImage: "books.vertical",
          description: Text(L10n.text("Create a document, or open a saved session folder.")))
      } else {
        List(
          model.sessions.filter {
            search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)
              || ($0.reference ?? "").localizedCaseInsensitiveContains(search)
              || ($0.batchName ?? "").localizedCaseInsensitiveContains(search)
          }
        ) { item in
          Button {
            model.openSession(at: item.folder)
          } label: {
            HStack {
              Image(systemName: "doc.text").font(.title2)
              VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.headline)
                if let reference = item.reference {
                  Text([item.batchName ?? "", reference].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
                }
                Text(
                  L10n.format("Pages: %ld · %@", item.pageCount, item.modified.formatted(date: .abbreviated, time: .shortened))
                )
                .font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              if item.folder.resolvingSymlinksInPath().path
                == model.folder.resolvingSymlinksInPath().path
              {
                Text(L10n.text("Current")).foregroundStyle(.secondary)
              }
            }.padding(.vertical, 8).contentShape(Rectangle())
          }.buttonStyle(.plain)
        }
      }
      HStack {
        Button(L10n.text("Open session folder…"), action: model.openSession)
        Spacer()
        Button(L10n.text("New item…")) {
          model.showSessions = false
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { model.prepareNewItem() }
        }
        .buttonStyle(.borderedProminent)
      }
    }.padding(24).frame(width: 600, height: 480)
  }
}
