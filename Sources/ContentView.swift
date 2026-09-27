import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?

    @State private var text: String
    @State private var reloadError: String?
    @State private var watcher: FileWatcher?

    init(document: MarkdownDocument, fileURL: URL?) {
        self.document = document
        self.fileURL = fileURL
        _text = State(initialValue: document.text)
    }

    var body: some View {
        MarkdownWebView(
            bodyHTML: MarkdownRenderer.html(from: text),
            title: fileURL?.lastPathComponent ?? "Untitled",
            baseDirectory: fileURL?.deletingLastPathComponent()
        )
        .frame(minWidth: 480, minHeight: 360)
        .toolbar {
            Button { reload(reportingErrors: true) } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .help("Reload from disk (⌘R)")
            .disabled(fileURL == nil)
        }
        .focusedSceneValue(\.reloadDocument, fileURL == nil ? nil : ReloadAction { reload(reportingErrors: true) })
        .onChange(of: document.text) { _, newValue in text = newValue }
        .task(id: fileURL) {
            // Auto-refresh whenever the file changes on disk.
            watcher = fileURL.map { url in FileWatcher(url: url) { reload(reportingErrors: false) } }
        }
        .onDisappear { watcher = nil }
        .alert("Couldn’t Reload", isPresented: .constant(reloadError != nil), presenting: reloadError) { _ in
            Button("OK") { reloadError = nil }
        } message: { Text($0) }
    }

    /// Re-reads the file from disk, e.g. after it was changed in another editor.
    private func reload(reportingErrors: Bool) {
        guard let fileURL else { return }
        do {
            let newText = String(decoding: try Data(contentsOf: fileURL), as: UTF8.self)
            if newText != text { text = newText }
        } catch {
            if reportingErrors { reloadError = error.localizedDescription }
        }
    }
}
